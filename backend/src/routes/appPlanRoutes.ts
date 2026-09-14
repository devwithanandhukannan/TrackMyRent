import { Router } from 'express';
import {
  getAppPlans,
  createAppPlan,
  updateAppPlan,
  toggleAppPlanStatus,
  deleteAppPlan,
} from '../controllers/appPlanController';

const router = Router();

router.get('/', getAppPlans);
router.post('/', createAppPlan);
router.put('/:id', updateAppPlan);
router.patch('/:id/toggle', toggleAppPlanStatus);
router.delete('/:id', deleteAppPlan);

export default router;
