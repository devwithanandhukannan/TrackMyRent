import { Router } from 'express';
import {
  getSubscriptionAndCredits,
  deductWhatsAppCredit,
  purchaseCredits,
  getWhatsAppSettings,
  saveWhatsAppSettings,
} from '../controllers/creditController';

const router = Router();

router.get('/:organizationId', getSubscriptionAndCredits);
router.post('/deduct', deductWhatsAppCredit);
router.post('/purchase', purchaseCredits);
router.get('/settings/:organizationId', getWhatsAppSettings);
router.post('/settings/save', saveWhatsAppSettings);

export default router;
