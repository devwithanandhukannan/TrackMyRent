import { Router } from 'express';
import {
  getFinancialSummaryReport,
  getTenantBillingReport,
  adminAdjustTenantSubscription,
} from '../controllers/reportController';

const router = Router();

router.get('/summary', getFinancialSummaryReport);
router.get('/tenant-billing', getTenantBillingReport);
router.post('/tenant-billing/adjust', adminAdjustTenantSubscription);

export default router;
