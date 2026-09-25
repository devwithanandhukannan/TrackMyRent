import { Router } from 'express';
import {
  getSettings,
  updateSettings,
  testRazorpayConnection,
  testWhatsAppConnection,
} from '../controllers/settingController';

const router = Router();

router.get('/', getSettings);
router.put('/', updateSettings);
router.post('/test-razorpay', testRazorpayConnection);
router.post('/test-whatsapp', testWhatsAppConnection);

export default router;
