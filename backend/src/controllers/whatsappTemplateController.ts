import { Request, Response } from 'express';
import { prisma } from '../index';

export const SEEDED_DEFAULT_TEMPLATES = [
  {
    templateId: '',
    name: 'Admin Login OTP',
    templateType: 'OTP',
    category: 'AUTHENTICATION',
    language: 'en',
    messageText: 'Your RentTrack verification code is {{1}}. This code is valid for {{2}} minutes. Please do not share this OTP with anyone. - RentTrack Secure Login',
  },
  {
    templateId: '',
    name: 'Rent / Fee Due Reminder',
    templateType: 'RENT_REMINDER',
    category: 'UTILITY',
    language: 'en',
    messageText: 'Hello {{1}}, your rent/fee payment of ₹{{2}} for {{3}} is scheduled for {{4}}. You can pay directly to our account via: {{5}} . Thank you!',
  },
  {
    templateId: '',
    name: 'Payment Receipt & Confirmation',
    templateType: 'PAYMENT_RECEIPT',
    category: 'UTILITY',
    language: 'en',
    messageText: 'Dear {{1}}, we have received your payment of ₹{{2}} for {{3}}. Receipt No: {{4}}. Download official receipt here: {{5}}',
  },
  {
    templateId: '',
    name: 'New Member Welcome',
    templateType: 'MEMBER_WELCOME',
    category: 'MARKETING',
    language: 'en',
    messageText: 'Welcome {{1}} to {{2}}! Your membership plan \'{{3}}\' is active. We are thrilled to have you onboard.',
  },
  {
    templateId: '',
    name: 'Plan Renewal Reminder',
    templateType: 'RENEWAL_REMINDER',
    category: 'UTILITY',
    language: 'en',
    messageText: 'Hi {{1}}, your membership plan \'{{2}}\' will expire on {{3}}. Please renew in advance to continue enjoying uninterrupted services.',
  },
  {
    templateId: '',
    name: 'Month / Account Freeze Notice',
    templateType: 'MONTH_FREEZE',
    category: 'UTILITY',
    language: 'en',
    messageText: 'Hi {{1}}, your membership/rent account has been placed on hold from {{2}} to {{3}} as requested. Contact admin for any questions.',
  },
];

export const getWhatsAppTemplates = async (req: Request, res: Response) => {
  try {
    const { organizationId } = req.query;

    const count = await prisma.whatsAppTemplate.count();
    if (count === 0) {
      for (const tpl of SEEDED_DEFAULT_TEMPLATES) {
        await prisma.whatsAppTemplate.create({
          data: {
            templateId: tpl.templateId,
            name: tpl.name,
            templateType: tpl.templateType,
            category: tpl.category,
            language: tpl.language,
            messageText: tpl.messageText,
            isActive: true,
          },
        });
      }
    }

    const whereClause = organizationId
      ? { OR: [{ organizationId: organizationId as string }, { organizationId: null }] }
      : {};

    const templates = await prisma.whatsAppTemplate.findMany({
      where: whereClause,
      orderBy: { createdAt: 'asc' },
    });

    return res.status(200).json({ success: true, templates });
  } catch (error: any) {
    console.error('Error fetching WhatsApp templates:', error);
    return res.status(500).json({ success: false, error: error.message || 'Failed to fetch templates' });
  }
};

export const createWhatsAppTemplate = async (req: Request, res: Response) => {
  try {
    const { templateId, name, templateType, category, language, messageText, isActive, organizationId } = req.body;

    if (!messageText || !name) {
      return res.status(400).json({ success: false, error: 'Name and messageText are required' });
    }

    const template = await prisma.whatsAppTemplate.create({
      data: {
        templateId: templateId || `rt_custom_${Date.now()}`,
        name: name.trim(),
        templateType: templateType || 'CUSTOM',
        category: category || 'UTILITY',
        language: language || 'en',
        messageText: messageText.trim(),
        isActive: isActive !== undefined ? Boolean(isActive) : true,
        organizationId: organizationId || null,
      },
    });

    return res.status(201).json({ success: true, template, message: 'Template created successfully' });
  } catch (error: any) {
    console.error('Error creating WhatsApp template:', error);
    return res.status(500).json({ success: false, error: error.message || 'Failed to create template' });
  }
};

export const updateWhatsAppTemplate = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { templateId, name, templateType, category, language, messageText, isActive } = req.body;

    const existing = await prisma.whatsAppTemplate.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ success: false, error: 'Template not found' });
    }

    const updated = await prisma.whatsAppTemplate.update({
      where: { id },
      data: {
        ...(templateId !== undefined && { templateId: templateId.trim() }),
        ...(name !== undefined && { name: name.trim() }),
        ...(templateType !== undefined && { templateType }),
        ...(category !== undefined && { category }),
        ...(language !== undefined && { language }),
        ...(messageText !== undefined && { messageText: messageText.trim() }),
        ...(isActive !== undefined && { isActive: Boolean(isActive) }),
      },
    });

    return res.status(200).json({ success: true, template: updated, message: 'Template updated successfully' });
  } catch (error: any) {
    console.error('Error updating WhatsApp template:', error);
    return res.status(500).json({ success: false, error: error.message || 'Failed to update template' });
  }
};

export const deleteWhatsAppTemplate = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const existing = await prisma.whatsAppTemplate.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ success: false, error: 'Template not found' });
    }

    await prisma.whatsAppTemplate.delete({ where: { id } });

    return res.status(200).json({ success: true, message: 'Template deleted successfully' });
  } catch (error: any) {
    console.error('Error deleting WhatsApp template:', error);
    return res.status(500).json({ success: false, error: error.message || 'Failed to delete template' });
  }
};
