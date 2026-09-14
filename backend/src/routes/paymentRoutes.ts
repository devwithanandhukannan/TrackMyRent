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

export default router;
