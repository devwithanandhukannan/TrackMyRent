import { Router } from 'express';
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
} from '../controllers/paymentController';

const router = Router();

router.post('/generate-schedules', generatePaymentSchedules);
router.post('/mark-paid', markAsPaid);
router.post('/mark-unpaid', markAsUnpaid);
router.post('/freeze', freezeMonth);
router.post('/unfreeze', unfreezeMonth);
router.get('/pending/:memberId', getPendingDues);
router.get('/transactions', getTransactions);
router.get('/schedules/:memberId', getMemberSchedules);
router.post('/razorpay/create-order', createRazorpayPaymentOrder);
router.post('/razorpay/verify-payment', verifyRazorpayPayment);
router.post('/razorpay/subscription-order', createSubscriptionRazorpayOrder);
router.post('/razorpay/credit-order', createCreditPackageRazorpayOrder);
router.post('/razorpay/verify-subscription', verifySubscriptionOrCreditPayment);
router.post('/send-reminder', sendPaymentReminder);

export default router;
