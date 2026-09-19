import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// In-memory store for subscription packages (starts empty so only admin-created packages exist)
export let inMemoryAppPlans: any[] = [];

export const getAppPlans = async (req: Request, res: Response) => {
  try {
    const { includeDisabled } = req.query;
    const whereCondition = includeDisabled === 'true' ? {} : { isActive: true };

    const plans = await prisma.appSubscriptionPlan.findMany({
      where: whereCondition,
      orderBy: { sortOrder: 'asc' },
    });

    if (plans && plans.length > 0) {
      inMemoryAppPlans = plans;
      return res.json({ success: true, data: plans });
    }

    const filtered = includeDisabled === 'true'
      ? inMemoryAppPlans
      : inMemoryAppPlans.filter((p) => p.isActive);
    return res.json({ success: true, data: filtered });
  } catch (error) {
    // Database offline fallback
    const { includeDisabled } = req.query;
    const filtered = includeDisabled === 'true'
      ? inMemoryAppPlans
      : inMemoryAppPlans.filter((p) => p.isActive);
    res.json({ success: true, data: filtered, fallback: true });
  }
};

export const createAppPlan = async (req: Request, res: Response) => {
  try {
    const { name, price, tag, description, durationMonths, whatsappCredits, isFreeTrial, isActive, sortOrder } = req.body;

    if (!name || price === undefined) {
      return res.status(400).json({ success: false, error: 'Name and price are required' });
    }

    if (whatsappCredits === undefined || whatsappCredits === null || isNaN(Number(whatsappCredits))) {
      return res.status(400).json({ success: false, error: 'WhatsApp Credits is compulsory for all subscription plans' });
    }

    let plan: any = {
      id: 'plan_' + Date.now(),
      name,
      price: Number(price),
      tag: tag || null,
      description: description || '',
      durationMonths: Number(durationMonths) || 1,
      whatsappCredits: Math.max(0, parseInt(String(whatsappCredits), 10)),
      isFreeTrial: Boolean(isFreeTrial),
      isActive: isActive !== undefined ? Boolean(isActive) : true,
      sortOrder: sortOrder !== undefined ? Number(sortOrder) : inMemoryAppPlans.length + 1,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    try {
      const dbPlan = await prisma.appSubscriptionPlan.create({
        data: {
          name: plan.name,
          price: plan.price,
          tag: plan.tag,
          description: plan.description,
          durationMonths: plan.durationMonths,
          whatsappCredits: plan.whatsappCredits,
          isFreeTrial: plan.isFreeTrial,
          isActive: plan.isActive,
          sortOrder: plan.sortOrder,
        },
      });
      plan = dbPlan;
    } catch (_) {
      // Prisma offline, proceed with inMemory plan
    }

    // Keep in-memory store updated
    inMemoryAppPlans.push(plan);

    res.status(201).json({ success: true, data: plan });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

export const updateAppPlan = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { name, price, tag, description, durationMonths, whatsappCredits, isFreeTrial, isActive, sortOrder } = req.body;

    let updatedPlan: any = null;

    try {
      updatedPlan = await prisma.appSubscriptionPlan.update({
        where: { id },
        data: {
          ...(name !== undefined && { name }),
          ...(price !== undefined && { price: Number(price) }),
          ...(tag !== undefined && { tag: tag || null }),
          ...(description !== undefined && { description }),
          ...(durationMonths !== undefined && { durationMonths: Number(durationMonths) }),
          ...(whatsappCredits !== undefined && { whatsappCredits: Math.max(0, parseInt(String(whatsappCredits), 10)) }),
          ...(isFreeTrial !== undefined && { isFreeTrial: Boolean(isFreeTrial) }),
          ...(isActive !== undefined && { isActive: Boolean(isActive) }),
          ...(sortOrder !== undefined && { sortOrder: Number(sortOrder) }),
        },
      });
    } catch (_) {}

    // Update in-memory
    const idx = inMemoryAppPlans.findIndex((p) => p.id === id);
    if (idx !== -1) {
      inMemoryAppPlans[idx] = {
        ...inMemoryAppPlans[idx],
        ...(name !== undefined && { name }),
        ...(price !== undefined && { price: Number(price) }),
        ...(tag !== undefined && { tag: tag || null }),
        ...(description !== undefined && { description }),
        ...(durationMonths !== undefined && { durationMonths: Number(durationMonths) }),
        ...(whatsappCredits !== undefined && { whatsappCredits: Math.max(0, parseInt(String(whatsappCredits), 10)) }),
        ...(isFreeTrial !== undefined && { isFreeTrial: Boolean(isFreeTrial) }),
        ...(isActive !== undefined && { isActive: Boolean(isActive) }),
        ...(sortOrder !== undefined && { sortOrder: Number(sortOrder) }),
        updatedAt: new Date().toISOString(),
      };
      if (!updatedPlan) updatedPlan = inMemoryAppPlans[idx];
    }

    if (!updatedPlan) {
      return res.status(404).json({ success: false, error: 'Plan not found' });
    }

    res.json({ success: true, data: updatedPlan });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

export const toggleAppPlanStatus = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    let toggled: any = null;

    try {
      const existing = await prisma.appSubscriptionPlan.findUnique({ where: { id } });
      if (existing) {
        toggled = await prisma.appSubscriptionPlan.update({
          where: { id },
          data: { isActive: !existing.isActive },
        });
      }
    } catch (_) {}

    const idx = inMemoryAppPlans.findIndex((p) => p.id === id);
    if (idx !== -1) {
      inMemoryAppPlans[idx].isActive = !inMemoryAppPlans[idx].isActive;
      if (!toggled) toggled = inMemoryAppPlans[idx];
    }

    if (!toggled) {
      return res.status(404).json({ success: false, error: 'Plan not found' });
    }

    res.json({ success: true, data: toggled });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

export const deleteAppPlan = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    try {
      await prisma.appSubscriptionPlan.delete({ where: { id } });
    } catch (_) {}

    inMemoryAppPlans = inMemoryAppPlans.filter((p) => p.id !== id);
    res.json({ success: true, message: 'Plan deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};
