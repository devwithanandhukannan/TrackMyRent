import { Router } from 'express';
import {
  createPlan,
  createGroup,
  listPlans,
  getPlanDetail,
  getGroupDetail,
  deletePlan,
  listCustomFields,
  deleteCustomField,
} from '../controllers/planController';

const router = Router();

router.post('/', createPlan);
router.post('/groups', createGroup);
router.get('/', listPlans);
router.get('/custom-fields', listCustomFields);
router.delete('/custom-fields/:id', deleteCustomField);
router.get('/groups/:id', getGroupDetail);
router.get('/:id', getPlanDetail);
router.delete('/:id', deletePlan);

export default router;
