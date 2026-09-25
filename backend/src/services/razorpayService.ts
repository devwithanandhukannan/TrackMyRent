import Razorpay from 'razorpay';
import crypto from 'crypto';
import { getRazorpayCredentials } from './systemSettingService';

export const getRazorpayInstance = async () => {
  const { keyId, keySecret } = await getRazorpayCredentials();

  if (!keyId || !keySecret) {
    throw new Error('Razorpay Key ID and Key Secret are not configured. Please set them in Platform Settings in the Admin Dashboard.');
  }

  return new Razorpay({
    key_id: keyId,
    key_secret: keySecret,
  });
};

/**
 * Create a real Razorpay Order using configured credentials from DB
 */
export const createRazorpayOrder = async (amountInRupees: number, receiptId: string, notes: Record<string, any> = {}) => {
  const instance = await getRazorpayInstance();
  const options = {
    amount: Math.round(amountInRupees * 100), // Amount in paise
    currency: 'INR',
    receipt: receiptId,
    notes,
  };

  const order = await instance.orders.create(options);
  return order;
};

/**
 * Verify Razorpay Payment Signature
 */
export const verifyRazorpaySignature = async (orderId: string, paymentId: string, signature: string, secretOverride?: string): Promise<boolean> => {
  const secret = secretOverride || (await getRazorpayCredentials()).keySecret;
  if (!secret) {
    throw new Error('Razorpay Key Secret is not configured. Please set it in Platform Settings in the Admin Dashboard.');
  }
  const body = orderId + '|' + paymentId;
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(body.toString())
    .digest('hex');

  return expectedSignature === signature;
};

/**
 * Create a real Razorpay Hosted Payment Link with standard checkout
 */
export const createRazorpayPaymentLink = async ({
  amountInRupees,
  description,
  customerName,
  customerPhone,
  customerEmail,
  callbackUrl,
  notes = {},
}: {
  amountInRupees: number;
  description: string;
  customerName?: string;
  customerPhone?: string;
  customerEmail?: string;
  callbackUrl?: string;
  notes?: Record<string, any>;
}) => {
  const instance = await getRazorpayInstance();
  const phone = customerPhone ? customerPhone.replace(/[^0-9]/g, '') : '9876543210';
  const cleanPhone = phone.length >= 10 ? `+91${phone.slice(-10)}` : '+919876543210';

  // Set expire_by to 16 minutes from now (Razorpay API strictly requires >= 15 minutes)
  const expireByTimestamp = Math.floor(Date.now() / 1000) + 16 * 60;

  const link = await instance.paymentLink.create({
    amount: Math.round(amountInRupees * 100),
    currency: 'INR',
    accept_partial: false,
    description,
    customer: {
      name: customerName || 'RentTrack Customer',
      contact: cleanPhone,
      email: customerEmail || 'billing@renttrack.app',
    },
    notify: { sms: false, email: false, whatsapp: false },
    callback_url: callbackUrl,
    callback_method: 'get',
    expire_by: expireByTimestamp,
    notes,
  });

  return link;
};

/**
 * Cancel a Razorpay Payment Link so it cannot be used anymore
 */
export const cancelRazorpayPaymentLink = async (linkId: string) => {
  try {
    const instance = await getRazorpayInstance();
    return await instance.paymentLink.cancel(linkId);
  } catch (err: any) {
    console.warn(`[RazorpayService] Could not cancel link ${linkId}:`, err?.error?.description || err.message);
    return null;
  }
};

/**
 * Fetch live Payment Link details from Razorpay
 */
export const fetchRazorpayPaymentLink = async (linkId: string) => {
  try {
    const instance = await getRazorpayInstance();
    return await instance.paymentLink.fetch(linkId);
  } catch (err: any) {
    console.warn(`[RazorpayService] Could not fetch link ${linkId}:`, err?.error?.description || err.message);
    return null;
  }
};

/**
 * Fetch live payment status directly from Razorpay
 */
export const fetchPaymentDetails = async (paymentId: string) => {
  const instance = await getRazorpayInstance();
  return await instance.payments.fetch(paymentId);
};
