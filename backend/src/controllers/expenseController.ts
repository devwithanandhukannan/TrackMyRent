import { Request, Response } from 'express';
import { prisma } from '../index';

export const createExpense = async (req: Request, res: Response) => {
  try {
    const { organizationId, categoryId, title, amount, expenseDate, notes } = req.body;

    const expense = await prisma.expense.create({
      data: {
        organizationId,
        categoryId,
        title,
        amount,
        expenseDate: expenseDate ? new Date(expenseDate) : new Date(),
        notes,
      },
      include: { category: true },
    });

    res.status(201).json({ message: 'Expense recorded successfully', expense });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

export const listExpenses = async (req: Request, res: Response) => {
  try {
    const { organizationId, search } = req.query;

    const expenses = await prisma.expense.findMany({
      where: {
        organizationId: String(organizationId),
        ...(search ? { title: { contains: String(search), mode: 'insensitive' } } : {}),
      },
      include: { category: true },
      orderBy: { expenseDate: 'desc' },
    });

    const totalExpense = expenses.reduce((sum, e) => sum + e.amount, 0);

    res.status(200).json({ totalExpense, count: expenses.length, expenses });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

export const createCustomExpenseCategory = async (req: Request, res: Response) => {
  try {
    const { organizationId, name } = req.body;

    const category = await prisma.expenseCategory.create({
      data: {
        organizationId,
        name,
        isCustom: true,
      },
    });

    res.status(201).json({ message: 'Custom expense category created', category });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};
