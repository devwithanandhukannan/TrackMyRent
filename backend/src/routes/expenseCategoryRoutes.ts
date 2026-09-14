import { Router } from 'express';
import {
  getExpenseCategories,
  createExpenseCategory,
  deleteExpenseCategory,
} from '../controllers/expenseCategoryController';

const router = Router();

router.get('/', getExpenseCategories);
router.post('/', createExpenseCategory);
router.delete('/:id', deleteExpenseCategory);

export default router;
