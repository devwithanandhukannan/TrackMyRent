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

export const deleteExpense = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const existing = await prisma.expense.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ error: 'Expense record not found' });
    }

    await prisma.expense.delete({
      where: { id },
    });

    res.status(200).json({ message: 'Expense deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

export const updateExpense = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { categoryId, title, amount, expenseDate, notes } = req.body;

    const existing = await prisma.expense.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ error: 'Expense record not found' });
    }

    const updated = await prisma.expense.update({
      where: { id },
      data: {
        ...(categoryId ? { categoryId } : {}),
        ...(title !== undefined ? { title } : {}),
        ...(amount !== undefined ? { amount: parseFloat(amount) } : {}),
        ...(expenseDate ? { expenseDate: new Date(expenseDate) } : {}),
        ...(notes !== undefined ? { notes } : {}),
      },
      include: { category: true },
    });

    res.status(200).json({ message: 'Expense updated successfully', expense: updated });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};
