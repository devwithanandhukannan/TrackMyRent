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
