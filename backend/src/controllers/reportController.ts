import { Request, Response } from 'express';
import { prisma } from '../index';

export const getFinancialSummaryReport = async (req: Request, res: Response) => {
  try {
    const { organizationId } = req.query;
    const orgId = String(organizationId);

    // Calculate Collected Income (Actual Transactions or Paid Payment Schedules)
    const transactions = await prisma.transaction.findMany({
      where: { member: { organizationId: orgId } },
    });
    const totalCollectedFromTx = transactions.reduce((sum, t) => sum + t.amountPaid, 0);

    const paidSchedules = await prisma.paymentSchedule.findMany({
      where: { member: { organizationId: orgId }, status: 'PAID' },
    });
    const totalCollectedFromSchedules = paidSchedules.reduce((sum, s) => sum + s.amount, 0);

    const totalCollected = Math.max(totalCollectedFromTx, totalCollectedFromSchedules);

    // Calculate Unpaid Dues (excluding Frozen)
    const unpaidSchedules = await prisma.paymentSchedule.findMany({
      where: { member: { organizationId: orgId }, status: 'UNPAID' },
    });
    const totalPending = unpaidSchedules.reduce((sum, s) => sum + s.amount, 0);

    // Calculate Expenses
    const expenses = await prisma.expense.findMany({
      where: { organizationId: orgId },
      include: { category: true },
    });
    const totalExpenses = expenses.reduce((sum, e) => sum + e.amount, 0);

    const netProfit = totalCollected - totalExpenses;

    const totalExpected = totalCollected + totalPending;
    const collectionRate = totalExpected > 0 ? Number(((totalCollected / totalExpected) * 100).toFixed(1)) : 0;

    // Member counts
    const totalMembers = await prisma.member.count({ where: { organizationId: orgId } });
    const paidMembersCount = paidSchedules.length;
    const unpaidMembersCount = unpaidSchedules.length;

    // Plan Revenue Breakdown
    const plans = await prisma.plan.findMany({
      where: { organizationId: orgId },
      include: {
        members: {
          include: { paymentSchedules: { where: { status: 'PAID' } } },
        },
        groups: {
          include: {
            members: {
              include: { paymentSchedules: { where: { status: 'PAID' } } },
            },
          },
        },
      },
    });

    const planRevenue = plans.map((p) => {
      const revenue = p.members.reduce((sum, m) => {
        return sum + m.paymentSchedules.reduce((s, ps) => s + ps.amount, 0);
      }, 0);
      const groupRevenue = p.groups.map((g) => {
        const gRev = g.members.reduce((sum, m) => {
          return sum + m.paymentSchedules.reduce((s, ps) => s + ps.amount, 0);
        }, 0);
        return { id: g.id, name: g.name, revenue: gRev, members: g.members.length };
      });
      return {
        id: p.id,
        name: p.name,
        revenue,
        members: p.members.length,
        groups: groupRevenue,
      };
    });

    // Expense Category Breakdown
    const categoryBreakdown: Record<string, number> = {};
    expenses.forEach((e) => {
      const cat = e.category?.name ?? 'Other';
      categoryBreakdown[cat] = (categoryBreakdown[cat] ?? 0) + e.amount;
    });

    res.status(200).json({
      summary: {
        totalIncome: totalCollected,
        totalExpenses,
        netProfit,
        totalPendingDues: totalPending,
        collectionRate,
        totalMembers,
        paidMembersCount,
        unpaidMembersCount,
      },
      planRevenue,
      categoryBreakdown,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

