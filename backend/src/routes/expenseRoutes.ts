import { Router } from 'express';
import {
  createExpense,
  listExpenses,
  createCustomExpenseCategory,
  deleteExpense,
  updateExpense,
} from '../controllers/expenseController';

const router = Router();

router.post('/', createExpense);
router.get('/', listExpenses);
router.post('/categories', createCustomExpenseCategory);
router.put('/:id', updateExpense);
router.delete('/:id', deleteExpense);

export default router;
