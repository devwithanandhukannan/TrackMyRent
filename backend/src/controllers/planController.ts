import { Request, Response } from 'express';
import { prisma } from '../index';

export const createPlan = async (req: Request, res: Response) => {
  try {
    const { organizationId, name, price, durationDays = 30, durationType = 'DAYS_30', frequencyMonths = 1, collectionDayType = 'FIRST_DAY_OF_MONTH', customDayNumber, description } = req.body;

    const plan = await prisma.plan.create({
      data: {
        organizationId,
        name,
        price,
        durationDays,
        durationType,
        frequencyMonths,
        collectionDayType,
        customDayNumber,
        description,
      },
    });

    res.status(201).json({ message: 'Plan created successfully', plan });
  } catch (error) {
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
        capacity,
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

    const plans = await prisma.plan.findMany({
      where: organizationId ? { organizationId: String(organizationId) } : {},
      include: {
        groups: true,
        members: {
          include: {
            paymentSchedules: true,
          },
        },
      },
    });

    const formattedPlans = plans.map((p) => {
      let collected = 0;
      let pending = 0;
      let paidMembersCount = 0;
      let pendingMembersCount = 0;
      let frozenMembersCount = 0;

      p.members.forEach((m) => {
        const latest = m.paymentSchedules[0];
        if (latest) {
          if (latest.status === 'PAID') {
            collected += latest.amount;
            paidMembersCount++;
          } else if (latest.status === 'UNPAID') {
            pending += latest.amount;
            pendingMembersCount++;
          } else if (latest.status === 'FROZEN') {
            frozenMembersCount++;
          }
        }
      });

      return {
        id: p.id,
        name: p.name,
        price: p.price,
        durationDays: p.durationDays,
        totalMembers: p.members.length,
        groupsCount: p.groups.length,
        collected,
        pending,
        paidMembersCount,
        pendingMembersCount,
        frozenMembersCount,
      };
    });

    res.status(200).json({ count: formattedPlans.length, plans: formattedPlans });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};
