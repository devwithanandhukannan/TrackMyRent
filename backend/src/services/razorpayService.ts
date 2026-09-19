import Razorpay from 'razorpay';
import crypto from 'crypto';

export const getRazorpayInstance = () => {
  const razorpayKeyId = process.env.RAZORPAY_KEY_ID || 'rzp_test_TboZVU3RUHPlBF';
  const razorpayKeySecret = process.env.RAZORPAY_KEY_SECRET || 'HBQLAZCgsRUo5wBFyVygnBGL';

  return new Razorpay({
    key_id: razorpayKeyId,
    key_secret: razorpayKeySecret,
  });
};

/**
 * Create a real Razorpay Order using configured credentials
 */
export const createRazorpayOrder = async (amountInRupees: number, receiptId: string, notes: Record<string, any> = {}) => {
  const instance = getRazorpayInstance();
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
export const verifyRazorpaySignature = (orderId: string, paymentId: string, signature: string): boolean => {
  const secret = process.env.RAZORPAY_KEY_SECRET || 'HBQLAZCgsRUo5wBFyVygnBGL';
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
  const instance = getRazorpayInstance();
  const phone = customerPhone ? customerPhone.replace(/[^0-9]/g, '') : '9876543210';
  const cleanPhone = phone.length >= 10 ? `+91${phone.slice(-10)}` : '+919876543210';

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
    notes,
  });

  return link;
};

/**
 * Fetch live payment status directly from Razorpay
 */
export const fetchPaymentDetails = async (paymentId: string) => {
  const instance = getRazorpayInstance();
  return await instance.payments.fetch(paymentId);
};
