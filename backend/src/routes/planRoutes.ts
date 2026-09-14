import { Router } from 'express';
import { createPlan, createGroup, listPlans } from '../controllers/planController';

const router = Router();

router.post('/', createPlan);
router.post('/groups', createGroup);
router.get('/', listPlans);

export default router;
