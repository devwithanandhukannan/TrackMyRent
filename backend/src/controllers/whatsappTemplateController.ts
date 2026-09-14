import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Default templates
const DEFAULT_TEMPLATES = [
  {
    templateType: 'MEMBER_WELCOME',
    messageText: 'Welcome {name} to {org_name}! Your membership plan {plan} is active starting from {join_date}.',
  },
  {
    templateType: 'TENANT_WELCOME',
    messageText: 'Hello {name}, welcome to {org_name}! Rent payment of {amount} is scheduled on {due_date}.',
  },
  {
    templateType: 'RENT_REMINDER',
    messageText: 'Hi {name}, this is a friendly reminder that rent of {amount} for {month} is due on {due_date}. Thank you!',
  },
  {
    templateType: 'RENEWAL_REMINDER',
    messageText: 'Dear {name}, your membership plan {plan} expires on {due_date}. Please renew to continue.',
  },
  {
    templateType: 'PDF_RECEIPT',
    messageText: 'Hi {name}, thanks for the payment of {amount} for {month}. Here is your payment receipt: {receipt_url}',
  },
];

export const getWhatsAppTemplates = async (req: Request, res: Response) => {
  try {
    const { organizationId } = req.query;

    let targetOrgId = organizationId as string;
    if (!targetOrgId && (req as any).user?.organizationId) {
      targetOrgId = (req as any).user.organizationId;
    }

    if (!targetOrgId) {
      const firstOrg = await prisma.organization.findFirst();
      if (!firstOrg) {
        return res.status(400).json({ error: 'No organization found' });
      }
      targetOrgId = firstOrg.id;
    }

    // Seed defaults if missing
    for (const tpl of DEFAULT_TEMPLATES) {
      const existing = await prisma.whatsAppTemplate.findFirst({
        where: { organizationId: targetOrgId, templateType: tpl.templateType },
      });
      if (!existing) {
        await prisma.whatsAppTemplate.create({
          data: {
            organizationId: targetOrgId,
            templateType: tpl.templateType,
            messageText: tpl.messageText,
          },
        });
      }
    }

    const templates = await prisma.whatsAppTemplate.findMany({
      where: { organizationId: targetOrgId },
      orderBy: { createdAt: 'asc' },
    });

    return res.json({ templates });
  } catch (error: any) {
    console.error('Error fetching WhatsApp templates:', error);
    return res.status(500).json({ error: error.message || 'Failed to fetch templates' });
  }
};

export const updateWhatsAppTemplate = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { messageText } = req.body;

    if (!messageText || typeof messageText !== 'string') {
      return res.status(400).json({ error: 'Message text is required' });
    }

    const template = await prisma.whatsAppTemplate.update({
      where: { id },
      data: { messageText: messageText.trim() },
    });

    return res.json({ template, message: 'WhatsApp template updated successfully' });
  } catch (error: any) {
    console.error('Error updating WhatsApp template:', error);
    return res.status(500).json({ error: error.message || 'Failed to update template' });
  }
};
