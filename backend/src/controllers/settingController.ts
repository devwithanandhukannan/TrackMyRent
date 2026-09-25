import { Request, Response } from 'express';
import { prisma } from '../index';
import { invalidateSettingsCache, getRazorpayCredentials, getWhatsAppCredentials } from '../services/systemSettingService';
import { sendWhatsAppOtp } from '../services/whatsappService';

const DEFAULT_SETTINGS = [
  { key: 'RAZORPAY_KEY_ID', envKey: 'RAZORPAY_KEY_ID', category: 'RAZORPAY', description: 'Platform Razorpay Key ID for subscription payments' },
  { key: 'RAZORPAY_KEY_SECRET', envKey: 'RAZORPAY_KEY_SECRET', category: 'RAZORPAY', description: 'Platform Razorpay Key Secret' },
  { key: 'WHATSAPP_PHONE_NUMBER_ID', envKey: 'WHATSAPP_PHONE_NUMBER_ID', category: 'WHATSAPP', description: 'Meta Cloud API WhatsApp Phone Number ID' },
  { key: 'WHATSAPP_BUSINESS_ACCOUNT_ID', envKey: 'WHATSAPP_BUSINESS_ACCOUNT_ID', category: 'WHATSAPP', description: 'Meta WhatsApp Business Account ID (WABA ID)' },
  { key: 'WHATSAPP_ACCESS_TOKEN', envKey: 'WHATSAPP_ACCESS_TOKEN', category: 'WHATSAPP', description: 'Meta Permanent System User Access Token' },
  { key: 'WHATSAPP_API_VERSION', envKey: 'WHATSAPP_API_VERSION', category: 'WHATSAPP', description: 'Graph API Version (e.g. v20.0)', defaultValue: 'v20.0' },
  { key: 'WHATSAPP_WEBHOOK_SECRET', envKey: 'WHATSAPP_VERIFY_TOKEN', category: 'WHATSAPP', description: 'Webhook Verification Token for receiving events', defaultValue: 'trackmyrent_verify_token_2026' },
];

export const getSettings = async (req: Request, res: Response) => {
  try {
    // Seed or populate defaults from initial environment if empty
    for (const def of DEFAULT_SETTINGS) {
      const initialVal = (def.envKey && process.env[def.envKey]) || def.defaultValue || '';
      const existing = await prisma.systemSetting.findUnique({ where: { key: def.key } });
      if (!existing) {
        await prisma.systemSetting.create({
          data: {
            key: def.key,
            value: initialVal,
            category: def.category,
            description: def.description,
          },
        });
      } else if ((!existing.value || existing.value.trim() === '') && initialVal.trim() !== '') {
        // If DB had an empty string but env has a value, sync it into DB
        await prisma.systemSetting.update({
          where: { key: def.key },
          data: { value: initialVal },
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

        // Keep process.env in memory in sync as well
        process.env[key] = value.trim();

        updates.push(
          prisma.systemSetting.upsert({
            where: { key },
            update: { value: value.trim() },
            create: { key, value: value.trim(), category },
          })
        );
      }
    }

    await prisma.$transaction(updates);

    // Invalidate cached settings
    invalidateSettingsCache();

    console.log('✅ [SystemSettings] Updated settings in PostgreSQL database and invalidated cache.');
    res.status(200).json({ success: true, message: 'Settings saved successfully in database' });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

/**
 * Test Razorpay Gateway Connection
 */
export const testRazorpayConnection = async (req: Request, res: Response) => {
  try {
    const { keyId, keySecret } = await getRazorpayCredentials();

    if (!keyId || !keySecret) {
      return res.status(400).json({
        success: false,
        error: 'Razorpay Key ID or Key Secret is missing. Please save valid credentials first.',
      });
    }

    const Razorpay = (await import('razorpay')).default;
    const rzp = new Razorpay({ key_id: keyId, key_secret: keySecret });

    // Validate by querying Razorpay Orders API
    const orders = await rzp.orders.all({ count: 1 });

    res.status(200).json({
      success: true,
      message: 'Razorpay API credentials verified successfully! Connected to Razorpay servers.',
      details: {
        keyId,
        activeOrdersCount: orders.items ? orders.items.length : 0,
        status: 'AUTHENTICATED',
      },
    });
  } catch (error: any) {
    const errorMsg = error?.error?.description || error?.message || 'Razorpay connection failed';
    res.status(400).json({
      success: false,
      error: errorMsg,
    });
  }
};

/**
 * Test Meta WhatsApp Cloud API Connection
 */
export const testWhatsAppConnection = async (req: Request, res: Response) => {
  try {
    const { phoneNumberId, accessToken, apiVersion } = await getWhatsAppCredentials();
    const testRecipient = req.body?.phone;

    if (!phoneNumberId || !accessToken) {
      return res.status(400).json({
        success: false,
        error: 'WhatsApp Phone Number ID and Access Token must be configured in settings.',
      });
    }

    const axios = (await import('axios')).default;
    const version = apiVersion || 'v20.0';

    // 1. Verify credentials with Meta Graph API
    const metaCheckUrl = `https://graph.facebook.com/${version}/${phoneNumberId}?fields=id,verified_name,display_phone_number,quality_rating,code_verification_status`;
    const checkRes = await axios.get(metaCheckUrl, {
      headers: { Authorization: `Bearer ${accessToken}` },
      timeout: 10000,
    });

    const phoneData = checkRes.data;

    let messageResult = null;
    if (testRecipient && typeof testRecipient === 'string' && testRecipient.trim() !== '') {
      const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
      messageResult = await sendWhatsAppOtp(testRecipient.trim(), otpCode);
    }

    res.status(200).json({
      success: true,
      message: 'Meta WhatsApp Cloud API connection verified successfully! Token and Phone Number are live.',
      details: {
        phoneNumberId: phoneData.id,
        displayPhoneNumber: phoneData.display_phone_number,
        verifiedName: phoneData.verified_name,
        qualityRating: phoneData.quality_rating,
        verificationStatus: phoneData.code_verification_status,
        messageResult,
      },
    });
  } catch (error: any) {
    const errorDetails = error.response?.data?.error?.message || error?.message || 'Meta WhatsApp verification failed';
    res.status(400).json({
      success: false,
      error: errorDetails,
    });
  }
};
