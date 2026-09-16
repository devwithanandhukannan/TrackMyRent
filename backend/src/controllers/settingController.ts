import { Request, Response } from 'express';
import { prisma } from '../index';

const DEFAULT_SETTINGS = [
  { key: 'RAZORPAY_KEY_ID', value: 'rzp_test_placeholder_key', category: 'RAZORPAY', description: 'Platform Razorpay Key ID for subscription payments' },
  { key: 'RAZORPAY_KEY_SECRET', value: 'rzp_test_placeholder_secret', category: 'RAZORPAY', description: 'Platform Razorpay Key Secret' },
  { key: 'WHATSAPP_PHONE_NUMBER_ID', value: 'dummy_phone_number_id', category: 'WHATSAPP', description: 'Meta Cloud API WhatsApp Phone Number ID' },
  { key: 'WHATSAPP_BUSINESS_ACCOUNT_ID', value: 'dummy_waba_account_id', category: 'WHATSAPP', description: 'Meta WhatsApp Business Account ID (WABA ID)' },
  { key: 'WHATSAPP_ACCESS_TOKEN', value: 'dummy_meta_system_user_token', category: 'WHATSAPP', description: 'Meta Permanent System User Access Token' },
  { key: 'WHATSAPP_API_VERSION', value: 'v20.0', category: 'WHATSAPP', description: 'Graph API Version (e.g. v20.0)' },
  { key: 'WHATSAPP_WEBHOOK_SECRET', value: 'dummy_webhook_verify_secret', category: 'WHATSAPP', description: 'Webhook Verification Token for receiving events' },
];

export const getSettings = async (req: Request, res: Response) => {
  try {
    // Seed defaults if empty
    for (const def of DEFAULT_SETTINGS) {
      const existing = await prisma.systemSetting.findUnique({ where: { key: def.key } });
      if (!existing) {
        await prisma.systemSetting.create({
          data: def,
        });
      }
    }

    const settings = await prisma.systemSetting.findMany({
      orderBy: { key: 'asc' },
    });

    const settingsMap: Record<string, string> = {};
    settings.forEach((s) => {
      settingsMap[s.key] = s.value;
    });

    res.status(200).json({ success: true, settings: settingsMap, raw: settings });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

export const updateSettings = async (req: Request, res: Response) => {
  try {
    const { settings } = req.body; // Expect key-value object e.g. { RAZORPAY_KEY_ID: "..." }

    if (!settings || typeof settings !== 'object') {
      return res.status(400).json({ success: false, error: 'Settings object required' });
    }

    const updates = [];
    for (const [key, value] of Object.entries(settings)) {
      if (typeof value === 'string') {
        const category = key.startsWith('RAZORPAY')
          ? 'RAZORPAY'
          : key.startsWith('WHATSAPP')
          ? 'WHATSAPP'
          : 'GENERAL';

        updates.push(
          prisma.systemSetting.upsert({
            where: { key },
            update: { value },
            create: { key, value, category },
          })
        );
      }
    }

    await prisma.$transaction(updates);

    res.status(200).json({ success: true, message: 'Settings saved successfully' });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};
