import { Router } from 'express';
import { getFinancialSummaryReport } from '../controllers/reportController';

const router = Router();

router.get('/summary', getFinancialSummaryReport);

export default router;
