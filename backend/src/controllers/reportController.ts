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

/**
 * Get comprehensive Tenant Billing, Subscription Validity, and Payment Details
 */
export const getTenantBillingReport = async (req: Request, res: Response) => {
  try {
    const [orgs, allPlans] = await Promise.all([
      prisma.organization.findMany({
        include: {
          users: { select: { id: true, name: true, email: true, phone: true, role: true } },
          subscriptionCredit: true,
          _count: { select: { members: true, plans: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.appSubscriptionPlan.findMany(),
    ]);

    const planMap = new Map(allPlans.map((p) => [p.id, p]));

    const now = Date.now();
    let totalPlatformRevenue = 0;
    let totalCreditsPurchased = 0;
    let activeSubscriptionsCount = 0;
    let expiringSoonCount = 0;

    const tenants = orgs.map((org) => {
      const admin = org.users.find((u) => u.role === 'ORG_ADMIN') || org.users[0];
      const sub = org.subscriptionCredit;
      const plan = org.selectedAppPlanId
        ? planMap.get(org.selectedAppPlanId)
        : allPlans.find((p) => p.name.toLowerCase() === (sub?.subscriptionName || '').toLowerCase());

      const planName = sub?.subscriptionName || plan?.name || '2 Days Free Trial';
      const planPrice = plan?.price || (planName.toLowerCase().includes('trial') ? 0 : 500);
      const isFreeTrial = plan?.isFreeTrial ?? planName.toLowerCase().includes('trial');

      let expiresAt = sub?.expiresAt ? new Date(sub.expiresAt) : new Date(now + 2 * 86400000);
      const diffMs = expiresAt.getTime() - now;
      const daysRemaining = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

      let validityStatus: 'ACTIVE' | 'EXPIRING_SOON' | 'EXPIRED' = 'ACTIVE';
      if (daysRemaining <= 0) {
        validityStatus = 'EXPIRED';
      } else if (daysRemaining <= 5) {
        validityStatus = 'EXPIRING_SOON';
        expiringSoonCount++;
      } else {
        validityStatus = 'ACTIVE';
        if (!isFreeTrial) activeSubscriptionsCount++;
      }

      const purchasedCredits = sub?.purchasedCredits || 0;
      const usedCredits = sub?.usedCredits || 0;
      const availableCredits = Math.max(0, purchasedCredits - usedCredits);
      totalCreditsPurchased += purchasedCredits;

      // Estimate payments made by tenant
      const subscriptionPaid = isFreeTrial ? 0 : planPrice;
      const extraCredits = Math.max(0, purchasedCredits - (isFreeTrial ? 50 : 100));
      const creditsPaid = Math.round(extraCredits * 0.99);
      const totalPaid = subscriptionPaid + creditsPaid;
      totalPlatformRevenue += totalPaid;

      return {
        id: org.id,
        name: org.name,
        type: org.type,
        adminName: admin?.name || 'Admin',
        adminEmail: admin?.email || '-',
        adminPhone: admin?.phone || '-',
        planName,
        planPrice,
        isFreeTrial,
        durationMonths: plan?.durationMonths || 1,
        expiresAt: expiresAt.toISOString(),
        daysRemaining: Math.max(0, daysRemaining),
        validityStatus,
        purchasedCredits,
        usedCredits,
        availableCredits,
        subscriptionPaid,
        creditsPaid,
        totalPaid,
        membersCount: org._count?.members || 0,
        createdAt: org.createdAt,
      };
    });

    res.status(200).json({
      success: true,
      stats: {
        totalPlatformRevenue,
        activeSubscriptionsCount,
        totalCreditsPurchased,
        expiringSoonCount,
        totalTenants: orgs.length,
      },
      tenants,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

/**
 * Admin adjust tenant subscription validity and credits
 */
export const adminAdjustTenantSubscription = async (req: Request, res: Response) => {
  try {
    const { organizationId, extendDays = 0, addCredits = 0, planName } = req.body;
    if (!organizationId) {
      return res.status(400).json({ success: false, error: 'organizationId is required' });
    }

    const org = await prisma.organization.findUnique({
      where: { id: organizationId },
      include: { subscriptionCredit: true },
    });
    if (!org) return res.status(404).json({ success: false, error: 'Tenant not found' });

    let currentExpires = org.subscriptionCredit?.expiresAt ? new Date(org.subscriptionCredit.expiresAt) : new Date();
    if (currentExpires.getTime() < Date.now()) {
      currentExpires = new Date();
    }
    const newExpires = new Date(currentExpires.getTime() + Number(extendDays) * 86400000);

    const updateData: any = {};
    if (Number(extendDays) > 0) updateData.expiresAt = newExpires;
    if (Number(addCredits) !== 0) updateData.purchasedCredits = { increment: Number(addCredits) };
    if (planName) updateData.subscriptionName = planName;

    const updated = await prisma.subscriptionCredit.upsert({
      where: { organizationId },
      update: updateData,
      create: {
        organizationId,
        planType: 'CREDIT',
        subscriptionName: planName || 'Pro Plan',
        purchasedCredits: Number(addCredits) || 100,
        expiresAt: newExpires,
      },
    });

    res.status(200).json({ success: true, message: 'Tenant subscription adjusted successfully', data: updated });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

