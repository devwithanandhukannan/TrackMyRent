import { Request, Response } from 'express';
import { prisma } from '../index';

export const SEEDED_DEFAULT_TEMPLATES = [
  {
    templateId: '2573338346420823',
    name: 'Admin Login OTP',
    templateType: 'OTP',
    category: 'AUTHENTICATION',
    language: 'en',
    messageText: 'TrackMyRent Update: Your receipt is {{1}}. Thank you,TrackMyRent',
  },
  {
    templateId: '1675946917194699',
    name: 'Month / Account Freeze Notice',
    templateType: 'MONTH_FREEZE',
    category: 'UTILITY',
    language: 'en',
    messageText: 'Dear {{1}}, As requested, your membership billing for {{2}} has been put on freeze. Note: {{3}}. This month\'s dues are waived and will not be counted as pending. Please let us know when you are ready to resume. Thank you!',
  },
  {
    templateId: '840152119154400',
    name: 'Plan Renewal Reminder',
    templateType: 'RENEWAL_REMINDER',
    category: 'UTILITY',
    language: 'en',
    messageText: 'Dear {{1}}, Your {{2}} membership at {{3}} will expire on {{4}}. To continue without interruption, please renew your plan using the link below: {{5}}. Thank you!',
  },
  {
    templateId: '2332169737525031',
    name: 'New Member Welcome',
    templateType: 'MEMBER_WELCOME',
    category: 'MARKETING',
    language: 'en',
    messageText: 'Hello {{1}}, Welcome to {{2}}! Your membership plan ({{3}}) is active starting from {{4}}. Your monthly payment due date is the {{5}} of each month. Feel free to reach out if you have any questions. We are glad to have you with us!',
  },
  {
    templateId: '1081300614678972',
    name: 'Payment Receipt & Confirmation',
    templateType: 'PAYMENT_RECEIPT',
    category: 'UTILITY',
    language: 'en',
    messageText: 'Dear {{1}}, We have successfully received your payment of ₹{{3}} for {{2}} via {{4}}. Click the link below to view and download your official digital receipt: {{5}}. Thank you for choosing {{6}}!. Have an amazing day!',
  },
  {
    templateId: '1813194829858504',
    name: 'Rent / Fee Due Reminder',
    templateType: 'RENT_REMINDER',
    category: 'UTILITY',
    language: 'en',
    messageText: 'Hello there, You have received a fee payment request of ₹{{1}} from {{2}}. Payment details: Name: {{3}}, Description: {{4}}. Tap below to securely complete the payment. If already paid, kindly ignore.',
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
    } else {
      // Auto-sync approved template IDs for default system templates
      for (const tpl of SEEDED_DEFAULT_TEMPLATES) {
        const match = await prisma.whatsAppTemplate.findFirst({
          where: { organizationId: null, templateType: tpl.templateType },
        });
        if (match && (!match.templateId || match.templateId !== tpl.templateId)) {
          await prisma.whatsAppTemplate.update({
            where: { id: match.id },
            data: { templateId: tpl.templateId },
          });
        }
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
