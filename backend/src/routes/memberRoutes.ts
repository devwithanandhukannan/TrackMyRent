import { Router } from 'express';
import {
  createMember,
  listMembers,
  getMemberDetails,
  createCustomFieldDefinition,
} from '../controllers/memberController';

const router = Router();

router.post('/', createMember);
router.get('/', listMembers);
router.get('/:id', getMemberDetails);
router.post('/custom-fields', createCustomFieldDefinition);

export default router;
