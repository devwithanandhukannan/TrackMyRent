import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Get all expense categories for an organization
export const getExpenseCategories = async (req: Request, res: Response) => {
  try {
    const { organizationId } = req.query;

    let targetOrgId = organizationId as string;
    if (!targetOrgId && (req as any).user?.organizationId) {
      targetOrgId = (req as any).user.organizationId;
    }

    if (!targetOrgId) {
      const firstOrg = await prisma.organization.findFirst();
      if (!firstOrg) {
        return res.status(400).json({ error: 'No organization found' });
      }
      targetOrgId = firstOrg.id;
    }

    // Default categories
    const defaultCategories = [
      'Rent',
      'Utilities',
      'Equipment',
      'Salary',
      'Maintenance',
      'Marketing',
      'Other',
    ];

    // Ensure default categories exist for organization
    for (const catName of defaultCategories) {
      const existing = await prisma.expenseCategory.findFirst({
        where: { organizationId: targetOrgId, name: catName },
      });
      if (!existing) {
        await prisma.expenseCategory.create({
          data: {
            organizationId: targetOrgId,
            name: catName,
            isCustom: false,
          },
        });
      }
    }

    const categories = await prisma.expenseCategory.findMany({
      where: { organizationId: targetOrgId },
      orderBy: { createdAt: 'asc' },
    });

    return res.json({ categories });
  } catch (error: any) {
    console.error('Error fetching expense categories:', error);
    return res.status(500).json({ error: error.message || 'Failed to fetch categories' });
  }
};

// Create a custom expense category
export const createExpenseCategory = async (req: Request, res: Response) => {
  try {
    const { organizationId, name } = req.body;

    let targetOrgId = organizationId;
    if (!targetOrgId && (req as any).user?.organizationId) {
      targetOrgId = (req as any).user.organizationId;
    }

    if (!targetOrgId) {
      const firstOrg = await prisma.organization.findFirst();
      if (!firstOrg) {
        return res.status(400).json({ error: 'No organization found' });
      }
      targetOrgId = firstOrg.id;
    }

    if (!name || typeof name !== 'string' || !name.trim()) {
      return res.status(400).json({ error: 'Category name is required' });
    }

    const trimmedName = name.trim();

    const existing = await prisma.expenseCategory.findFirst({
      where: { organizationId: targetOrgId, name: trimmedName },
    });

    if (existing) {
      return res.status(400).json({ error: 'Category already exists' });
    }

    const category = await prisma.expenseCategory.create({
      data: {
        organizationId: targetOrgId,
        name: trimmedName,
        isCustom: true,
      },
    });

    return res.status(201).json({ category, message: 'Expense category created successfully' });
  } catch (error: any) {
    console.error('Error creating expense category:', error);
    return res.status(500).json({ error: error.message || 'Failed to create category' });
  }
};

// Delete a custom expense category
export const deleteExpenseCategory = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const category = await prisma.expenseCategory.findUnique({
      where: { id },
    });

    if (!category) {
      return res.status(404).json({ error: 'Category not found' });
    }

    if (!category.isCustom) {
      return res.status(400).json({ error: 'Standard categories cannot be deleted' });
    }

    await prisma.expenseCategory.delete({
      where: { id },
    });

    return res.json({ message: 'Category deleted successfully' });
  } catch (error: any) {
    console.error('Error deleting category:', error);
    return res.status(500).json({ error: error.message || 'Failed to delete category' });
  }
};
