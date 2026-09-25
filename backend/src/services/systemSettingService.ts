import { prisma } from '../index';

interface CachedSettings {
  timestamp: number;
  data: Record<string, string>;
}

let settingsCache: CachedSettings | null = null;
const CACHE_TTL_MS = 10000; // 10 seconds cache to avoid querying DB repeatedly on rapid calls

export const invalidateSettingsCache = () => {
  settingsCache = null;
};

/**
 * Fetch all system settings from database with caching
 */
export const getAllSystemSettings = async (): Promise<Record<string, string>> => {
  const now = Date.now();
  if (settingsCache && now - settingsCache.timestamp < CACHE_TTL_MS) {
    return settingsCache.data;
  }

  try {
    const records = await prisma.systemSetting.findMany();
    const map: Record<string, string> = {};
    for (const r of records) {
      if (r.value && r.value.trim() !== '') {
        map[r.key] = r.value.trim();
      }
    }

    settingsCache = {
      timestamp: now,
      data: map,
    };
    return map;
  } catch (error) {
    console.warn('[SystemSettingService] Error fetching settings from DB, falling back to process.env:', (error as Error).message);
    return {};
  }
};

/**
 * Fetch a single setting from Database, fallback to process.env or defaultValue
 */
export const getSystemSetting = async (key: string, fallback: string = ''): Promise<string> => {
  const settings = await getAllSystemSettings();
  if (settings[key] && settings[key].trim() !== '') {
    return settings[key];
  }
  return process.env[key] || fallback;
};

/**
 * Fetch Razorpay Credentials dynamically from database
 */
export const getRazorpayCredentials = async (): Promise<{ keyId: string; keySecret: string }> => {
  const keyId = await getSystemSetting('RAZORPAY_KEY_ID', process.env.RAZORPAY_KEY_ID || '');
  const keySecret = await getSystemSetting('RAZORPAY_KEY_SECRET', process.env.RAZORPAY_KEY_SECRET || '');

  return {
    keyId,
    keySecret,
  };
};

/**
 * Fetch WhatsApp Cloud API Credentials dynamically from database
 */
export const getWhatsAppCredentials = async (): Promise<{
  phoneNumberId: string;
  wabaId: string;
  accessToken: string;
  apiVersion: string;
  webhookSecret: string;
}> => {
  const phoneNumberId = await getSystemSetting('WHATSAPP_PHONE_NUMBER_ID', process.env.WHATSAPP_PHONE_NUMBER_ID || '');
  const wabaId = await getSystemSetting('WHATSAPP_BUSINESS_ACCOUNT_ID', process.env.WHATSAPP_BUSINESS_ACCOUNT_ID || '');
  const accessToken = await getSystemSetting('WHATSAPP_ACCESS_TOKEN', process.env.WHATSAPP_ACCESS_TOKEN || '');
  const apiVersion = await getSystemSetting('WHATSAPP_API_VERSION', process.env.WHATSAPP_API_VERSION || 'v20.0');
  const webhookSecret = await getSystemSetting('WHATSAPP_WEBHOOK_SECRET', process.env.WHATSAPP_VERIFY_TOKEN || 'trackmyrent_verify_token_2026');

  return {
    phoneNumberId,
    wabaId,
    accessToken,
    apiVersion,
    webhookSecret,
  };
};
