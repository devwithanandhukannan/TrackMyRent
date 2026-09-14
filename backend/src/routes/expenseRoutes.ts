import { Router } from 'express';
import { createExpense, listExpenses, createCustomExpenseCategory } from '../controllers/expenseController';

const router = Router();

router.post('/', createExpense);
router.get('/', listExpenses);
router.post('/categories', createCustomExpenseCategory);

export default router;
