import { Request, Response } from 'express';
import { prisma } from '../index';

export const createPlan = async (req: Request, res: Response) => {
  try {
    const {
      organizationId,
      name,
      price,
      durationDays = 30,
      durationType = 'DAYS_30',
      frequencyMonths = 1,
      collectionDayType = 'FIRST_DAY_OF_MONTH',
      customDayNumber,
      description,
    } = req.body;

    if (!name || price === undefined) {
      return res.status(400).json({ error: 'Plan name and price are required' });
    }

    let targetOrgId = organizationId;
    if (targetOrgId) {
      const existingOrg = await prisma.organization.findUnique({ where: { id: targetOrgId } });
      if (!existingOrg) {
        const firstOrg = await prisma.organization.findFirst();
        if (firstOrg) targetOrgId = firstOrg.id;
      }
    } else {
      const firstOrg = await prisma.organization.findFirst();
      if (firstOrg) targetOrgId = firstOrg.id;
    }

    if (!targetOrgId) {
      const newOrg = await prisma.organization.create({
        data: { name: 'RentTrack Facility', type: 'GYM' },
      });
      targetOrgId = newOrg.id;
    }

    const plan = await prisma.plan.create({
      data: {
        organizationId: targetOrgId,
        name,
        price: Number(price),
        durationDays: Number(durationDays),
        durationType,
        frequencyMonths: Number(frequencyMonths),
        collectionDayType,
        customDayNumber: customDayNumber ? Number(customDayNumber) : null,
        description: description || null,
      },
    });

    res.status(201).json({ message: 'Plan created successfully', plan });
  } catch (error) {
    console.error('Error creating plan:', error);
    res.status(500).json({ error: (error as Error).message });
  }
};

export const createGroup = async (req: Request, res: Response) => {
  try {
    const { planId, name, schedule, capacity } = req.body;

    if (!planId || !name) {
      return res.status(400).json({ error: 'planId and Group name are required' });
    }

    const group = await prisma.group.create({
      data: {
        planId,
        name,
        schedule,
        capacity: capacity ? Number(capacity) : null,
      },
    });

    res.status(201).json({ message: 'Group created successfully', group });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

export const listPlans = async (req: Request, res: Response) => {
  try {
    const { organizationId } = req.query;

    let targetOrgId = organizationId ? String(organizationId) : undefined;
    if (targetOrgId) {
      const existingOrg = await prisma.organization.findUnique({ where: { id: targetOrgId } });
      if (!existingOrg) {
        targetOrgId = undefined;
      }
    }

    const plans = await prisma.plan.findMany({
      where: targetOrgId ? { organizationId: targetOrgId } : {},
      include: {
        groups: true,
        members: {
          include: { paymentSchedules: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const formattedPlans = plans.map((p) => {
      let collected = 0, pending = 0, paidMembersCount = 0, pendingMembersCount = 0, frozenMembersCount = 0;

      p.members.forEach((m) => {
        const latest = m.paymentSchedules[0];
        if (latest) {
          if (latest.status === 'PAID') { collected += latest.amount; paidMembersCount++; }
          else if (latest.status === 'UNPAID') { pending += latest.amount; pendingMembersCount++; }
          else if (latest.status === 'FROZEN') { frozenMembersCount++; }
        }
      });

      return {
        id: p.id,
        name: p.name,
        price: p.price,
        durationDays: p.durationDays,
        frequencyMonths: p.frequencyMonths,
        collectionDayType: p.collectionDayType,
        description: p.description,
        totalMembers: p.members.length,
        groupsCount: p.groups.length,
        collected,
        pending,
        paidMembersCount,
        pendingMembersCount,
        frozenMembersCount,
        groups: p.groups,
      };
    });

    res.status(200).json({ count: formattedPlans.length, plans: formattedPlans });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Get Plan Detail with Members, Groups, Payments tabs data
 */
export const getPlanDetail = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const plan = await prisma.plan.findUnique({
      where: { id },
      include: {
        groups: {
          include: {
            members: {
              include: { paymentSchedules: { orderBy: { dueDate: 'desc' } } },
            },
          },
        },
        members: {
          include: {
            paymentSchedules: { orderBy: { dueDate: 'desc' } },
            group: true,
          },
        },
      },
    });

    if (!plan) return res.status(404).json({ error: 'Plan not found' });

    let totalCollected = 0, totalPending = 0, paidMembersCount = 0, pendingMembersCount = 0, frozenMembersCount = 0;

    const membersFormatted = plan.members.map((m) => {
      const latest = m.paymentSchedules[0];
      const status = latest?.status ?? 'UNPAID';
      const amount = latest?.amount ?? plan.price;

      if (status === 'PAID') { totalCollected += amount; paidMembersCount++; }
      else if (status === 'UNPAID') { totalPending += amount; pendingMembersCount++; }
      else if (status === 'FROZEN') { frozenMembersCount++; }

      return {
        id: m.id,
        fullName: m.fullName,
        phone: m.phone,
        groupName: m.group?.name ?? 'Direct',
        status,
        amount,
        expiry: latest?.dueDate ?? null,
      };
    });

    const transactions = await prisma.transaction.findMany({
      where: { member: { planId: id } },
      include: { member: { select: { fullName: true } }, paymentSchedule: true },
      orderBy: { paymentDate: 'desc' },
      take: 50,
    });

    res.status(200).json({
      plan: {
        id: plan.id,
        name: plan.name,
        price: plan.price,
        durationDays: plan.durationDays,
        frequencyMonths: plan.frequencyMonths,
        description: plan.description,
      },
      summary: {
        totalMembers: plan.members.length,
        activeMembers: plan.members.filter((m) => m.isActive).length,
        frozenMembers: frozenMembersCount,
        collected: totalCollected,
        pending: totalPending,
        paidMembersCount,
        pendingMembersCount,
      },
      members: membersFormatted,
      groups: plan.groups.map((g) => {
        let gCollected = 0, gPending = 0, gPaid = 0, gPendingCount = 0;
        g.members.forEach((m) => {
          const latest = m.paymentSchedules[0];
          if (latest?.status === 'PAID') { gCollected += latest.amount; gPaid++; }
          else if (latest?.status === 'UNPAID') { gPending += latest.amount; gPendingCount++; }
        });
        return {
          id: g.id,
          name: g.name,
          schedule: g.schedule,
          capacity: g.capacity,
          totalMembers: g.members.length,
          collected: gCollected,
          pending: gPending,
          paidCount: gPaid,
          pendingCount: gPendingCount,
        };
      }),
      payments: transactions,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Get Group Detail with Paid / Pending / All member tabs
 */
export const getGroupDetail = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const group = await prisma.group.findUnique({
      where: { id },
      include: {
        plan: true,
        members: {
          include: { paymentSchedules: { orderBy: { dueDate: 'desc' } } },
        },
      },
    });

    if (!group) return res.status(404).json({ error: 'Group not found' });

    let collected = 0, pending = 0, paid = 0, pendingCount = 0, frozen = 0;

    const membersFormatted = group.members.map((m) => {
      const latest = m.paymentSchedules[0];
      const status = latest?.status ?? 'UNPAID';
      const amount = latest?.amount ?? group.plan.price;

      if (status === 'PAID') { collected += amount; paid++; }
      else if (status === 'UNPAID') { pending += amount; pendingCount++; }
      else if (status === 'FROZEN') { frozen++; }

      return {
        id: m.id,
        fullName: m.fullName,
        phone: m.phone,
        status,
        planAmount: group.plan.price,
        paid: status === 'PAID' ? amount : 0,
        pending: status === 'UNPAID' ? amount : 0,
        scheduleId: latest?.id ?? null,
      };
    });

    res.status(200).json({
      group: {
        id: group.id,
        name: group.name,
        schedule: group.schedule,
        capacity: group.capacity,
        parentPlan: { id: group.plan.id, name: group.plan.name, price: group.plan.price },
      },
      summary: {
        totalMembers: group.members.length,
        activeMembers: group.members.filter((m) => m.isActive).length,
        frozenMembers: frozen,
        collected,
        pending,
        paidCount: paid,
        pendingCount,
      },
      members: membersFormatted,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Delete a Plan
 */
export const deletePlan = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    await prisma.plan.delete({ where: { id } });
    res.status(200).json({ message: 'Plan deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * List Custom Field Definitions for an org
 */
export const listCustomFields = async (req: Request, res: Response) => {
  try {
    const { organizationId } = req.query;
    let orgId = organizationId ? String(organizationId) : null;
    if (!orgId) {
      const firstOrg = await prisma.organization.findFirst();
      orgId = firstOrg?.id ?? null;
    }
    if (!orgId) return res.status(400).json({ error: 'No organization found' });

    const fields = await prisma.customFieldDefinition.findMany({
      where: { organizationId: orgId },
      orderBy: { createdAt: 'asc' },
    });

    res.status(200).json({ fields });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Delete a Custom Field Definition
 */
export const deleteCustomField = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    await prisma.customFieldDefinition.delete({ where: { id } });
    res.status(200).json({ message: 'Custom field deleted' });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};
