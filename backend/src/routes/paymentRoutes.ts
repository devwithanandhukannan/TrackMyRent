import { Router, Request, Response } from 'express';
import { webhookQueue } from '../queues/webhookQueue';
import {
  generatePaymentSchedules,
  markAsPaid,
  markAsUnpaid,
  freezeMonth,
  unfreezeMonth,
  getPendingDues,
  getTransactions,
  getMemberSchedules,
  createRazorpayPaymentOrder,
  verifyRazorpayPayment,
  createSubscriptionRazorpayOrder,
  createCreditPackageRazorpayOrder,
  verifySubscriptionOrCreditPayment,
  sendPaymentReminder,
  sendPaymentReceipt,
  getPaymentLinkStatus,
  renderHostedPaymentGateway,
  renderDigitalReceipt,
  submitUtrReference,
} from '../controllers/paymentController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// Facility Admin & Internal Payment Actions (Protected by Auth Middleware)
router.post('/generate-schedules', authMiddleware, generatePaymentSchedules);
router.post('/mark-paid', authMiddleware, markAsPaid);
router.post('/mark-unpaid', authMiddleware, markAsUnpaid);
router.post('/freeze', authMiddleware, freezeMonth);
router.post('/unfreeze', authMiddleware, unfreezeMonth);
router.get('/pending/:memberId', authMiddleware, getPendingDues);
router.get('/transactions', authMiddleware, getTransactions);
router.get('/schedules/:memberId', authMiddleware, getMemberSchedules);
router.post('/razorpay/create-order', authMiddleware, createRazorpayPaymentOrder);
router.post('/razorpay/verify-payment', authMiddleware, verifyRazorpayPayment);
router.post('/razorpay/subscription-order', authMiddleware, createSubscriptionRazorpayOrder);
router.post('/razorpay/credit-order', authMiddleware, createCreditPackageRazorpayOrder);
router.post('/razorpay/verify-subscription', authMiddleware, verifySubscriptionOrCreditPayment);
router.post('/send-reminder', authMiddleware, sendPaymentReminder);
router.post('/send-receipt', authMiddleware, sendPaymentReceipt);

// Public routes for tenants / members paying via UPI or checking link validity
router.get('/link-status/:linkId', getPaymentLinkStatus);
router.get('/pay/:id', renderHostedPaymentGateway);
router.get('/receipt/:id', renderDigitalReceipt);
router.post('/submit-utr', submitUtrReference);

// Public Razorpay Webhook Endpoint
router.post('/webhook', async (req: Request, res: Response) => {
  try {
    const event = req.body.event || 'unknown';
    const payload = req.body.payload || req.body;

    const job = await webhookQueue.add('razorpay-event', {
      event,
      payload,
      receivedAt: new Date().toISOString(),
    });

    res.status(200).json({
      received: true,
      queuedJobId: job.id,
    });
  } catch (error) {
    res.status(500).json({ received: false, error: (error as Error).message });
  }
});

export default router;
