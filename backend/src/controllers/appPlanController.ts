import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export const getAppPlans = async (req: Request, res: Response) => {
  try {
    const { includeDisabled } = req.query;
    const whereCondition = includeDisabled === 'true' ? {} : { isActive: true };

    const plans = await prisma.appSubscriptionPlan.findMany({
      where: whereCondition,
      orderBy: { sortOrder: 'asc' },
    });

    res.json({ success: true, data: plans });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
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

    const plan = await prisma.appSubscriptionPlan.create({
      data: {
        name,
        price: Number(price),
        tag: tag || null,
        description: description || '',
        durationMonths: Number(durationMonths) || 1,
        whatsappCredits: Math.max(0, parseInt(String(whatsappCredits), 10)),
        isFreeTrial: Boolean(isFreeTrial),
        isActive: isActive !== undefined ? Boolean(isActive) : true,
        sortOrder: sortOrder !== undefined ? Number(sortOrder) : 0,
      },
    });

    res.status(201).json({ success: true, data: plan });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

export const updateAppPlan = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { name, price, tag, description, durationMonths, whatsappCredits, isFreeTrial, isActive, sortOrder } = req.body;

    const plan = await prisma.appSubscriptionPlan.update({
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

    res.json({ success: true, data: plan });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

export const toggleAppPlanStatus = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const existing = await prisma.appSubscriptionPlan.findUnique({ where: { id } });

    if (!existing) {
      return res.status(404).json({ success: false, error: 'Plan not found' });
    }

    const updated = await prisma.appSubscriptionPlan.update({
      where: { id },
      data: { isActive: !existing.isActive },
    });

    res.json({ success: true, data: updated });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

export const deleteAppPlan = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    await prisma.appSubscriptionPlan.delete({ where: { id } });
    res.json({ success: true, message: 'Plan deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};
