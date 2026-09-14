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
    });
    const totalExpenses = expenses.reduce((sum, e) => sum + e.amount, 0);

    const netProfit = totalCollected - totalExpenses;

    const totalExpected = totalCollected + totalPending;
    const collectionRate = totalExpected > 0 ? Number(((totalCollected / totalExpected) * 100).toFixed(1)) : 100;

    res.status(200).json({
      summary: {
        totalIncome: totalCollected,
        totalExpenses,
        netProfit,
        totalPendingDues: totalPending,
        collectionRate,
      },
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};
