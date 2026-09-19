import { Request, Response } from 'express';
import { prisma } from '../index';

export const getSubscriptionAndCredits = async (req: Request, res: Response) => {
  try {
    const { organizationId } = req.params;

    const subscriptionCredit = await prisma.subscriptionCredit.findUnique({
      where: { organizationId },
    });

    if (!subscriptionCredit) {
      return res.status(404).json({ error: 'Subscription credit record not found' });
    }

    const availableCredits = subscriptionCredit.purchasedCredits - subscriptionCredit.usedCredits;
    const now = new Date();
    const expiresAt = subscriptionCredit.expiresAt ? new Date(subscriptionCredit.expiresAt) : null;
    const isSubscriptionExpired = expiresAt ? now > expiresAt : false;
    const msRemaining = expiresAt ? expiresAt.getTime() - now.getTime() : 0;
    const daysRemaining = isSubscriptionExpired ? 0 : Math.max(0, Math.ceil(msRemaining / (1000 * 60 * 60 * 24)));

    res.status(200).json({
      subscription: {
        planType: subscriptionCredit.planType,
        subscriptionName: subscriptionCredit.subscriptionName,
        expiresAt: subscriptionCredit.expiresAt,
        isExpired: isSubscriptionExpired,
        daysRemaining: daysRemaining,
      },
      credits: {
        purchasedCredits: subscriptionCredit.purchasedCredits,
        usedCredits: subscriptionCredit.usedCredits,
        availableCredits: Math.max(0, availableCredits),
        creditRule: 'Unused credits roll over and accumulate when new subscription packages are added.',
      },
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

export const deductWhatsAppCredit = async (req: Request, res: Response) => {
  try {
    const { organizationId, creditsToDeduct = 1 } = req.body;

    const subCredit = await prisma.subscriptionCredit.findUnique({
      where: { organizationId },
    });

    if (!subCredit) return res.status(404).json({ error: 'Record not found' });

    const available = subCredit.purchasedCredits - subCredit.usedCredits;
    if (available < creditsToDeduct) {
      return res.status(400).json({
        error: 'Insufficient WhatsApp credits',
        availableCredits: available,
        requiredCredits: creditsToDeduct,
      });
    }

    const updated = await prisma.subscriptionCredit.update({
      where: { organizationId },
      data: {
        usedCredits: subCredit.usedCredits + creditsToDeduct,
      },
    });

    res.status(200).json({
      message: `${creditsToDeduct} credit(s) deducted`,
      remainingCredits: updated.purchasedCredits - updated.usedCredits,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

export const purchaseCredits = async (req: Request, res: Response) => {
  try {
    const { organizationId, creditsCount } = req.body;

    if (!organizationId || !creditsCount) {
      return res.status(400).json({ error: 'organizationId and creditsCount are required' });
    }

    const updated = await prisma.subscriptionCredit.update({
      where: { organizationId },
      data: {
        purchasedCredits: { increment: Number(creditsCount) },
      },
    });

    res.status(200).json({
      message: `${creditsCount} credits purchased successfully! Purchased credits NEVER expire.`,
      purchasedCredits: updated.purchasedCredits,
      availableCredits: updated.purchasedCredits - updated.usedCredits,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

export const getWhatsAppSettings = async (req: Request, res: Response) => {
  try {
    const { organizationId } = req.params;

    const org = await prisma.organization.findUnique({
      where: { id: organizationId },
      select: {
        id: true,
        name: true,
        whatsappAppId: true,
        whatsappPhoneNumberId: true,
        whatsappAccessToken: true,
        whatsappBusinessId: true,
      },
    });

    if (!org) return res.status(404).json({ error: 'Organization not found' });

    res.status(200).json({ settings: org });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

export const saveWhatsAppSettings = async (req: Request, res: Response) => {
  try {
    const { organizationId, whatsappAppId, whatsappPhoneNumberId, whatsappAccessToken, whatsappBusinessId } = req.body;

    const updated = await prisma.organization.update({
      where: { id: organizationId },
      data: {
        whatsappAppId,
        whatsappPhoneNumberId,
        whatsappAccessToken,
        whatsappBusinessId,
      },
    });

    res.status(200).json({ message: 'WhatsApp Cloud API settings saved successfully', settings: updated });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};
