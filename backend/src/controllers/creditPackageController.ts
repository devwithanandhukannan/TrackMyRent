import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export let defaultCreditPackages: any[] = [
  {
    id: 'pkg_100_credits',
    name: '100 Credits Top-Up',
    credits: 100,
    price: 99,
    description: 'Instant top-up for WhatsApp payment reminders & receipts',
    tag: 'Starter',
    isActive: true,
    sortOrder: 1,
  },
  {
    id: 'pkg_250_credits',
    name: '250 Credits Top-Up',
    credits: 250,
    price: 199,
    description: 'Standard pack for monthly reminders and receipts',
    tag: 'Popular',
    isActive: true,
    sortOrder: 2,
  },
  {
    id: 'pkg_500_credits',
    name: '500 Credits Top-Up',
    credits: 500,
    price: 349,
    description: 'High-volume booster with maximum savings',
    tag: 'Best Value',
    isActive: true,
    sortOrder: 3,
  },
  {
    id: 'pkg_1000_credits',
    name: '1000 Credits Mega Pack',
    credits: 1000,
    price: 599,
    description: 'Pro enterprise pack for high-member facilities',
    tag: 'Pro',
    isActive: true,
    sortOrder: 4,
  },
];

export const getCreditPackages = async (req: Request, res: Response) => {
  try {
    const { includeDisabled } = req.query;
    const whereCondition = includeDisabled === 'true' ? {} : { isActive: true };

    const packages = await prisma.appCreditPackage.findMany({
      where: whereCondition,
      orderBy: { sortOrder: 'asc' },
    });

    if (packages.length > 0) {
      defaultCreditPackages = packages;
      return res.json({ success: true, data: packages });
    }

    const filtered = includeDisabled === 'true'
      ? defaultCreditPackages
      : defaultCreditPackages.filter((p) => p.isActive);
    res.json({ success: true, data: filtered });
  } catch (error) {
    const { includeDisabled } = req.query;
    const filtered = includeDisabled === 'true'
      ? defaultCreditPackages
      : defaultCreditPackages.filter((p) => p.isActive);
    res.json({ success: true, data: filtered, fallback: true });
  }
};

export const createCreditPackage = async (req: Request, res: Response) => {
  try {
    const { name, credits, price, description, tag, isActive, sortOrder } = req.body;

    if (!name || credits === undefined || price === undefined) {
      return res.status(400).json({ success: false, error: 'Name, credits, and price are required' });
    }

    let pkg: any = {
      id: 'pkg_' + Date.now(),
      name,
      credits: Number(credits),
      price: Number(price),
      description: description || '',
      tag: tag || null,
      isActive: isActive !== undefined ? Boolean(isActive) : true,
      sortOrder: sortOrder !== undefined ? Number(sortOrder) : defaultCreditPackages.length + 1,
    };

    try {
      const dbPkg = await prisma.appCreditPackage.create({
        data: {
          name: pkg.name,
          credits: pkg.credits,
          price: pkg.price,
          description: pkg.description,
          tag: pkg.tag,
          isActive: pkg.isActive,
          sortOrder: pkg.sortOrder,
        },
      });
      pkg = dbPkg;
    } catch (_) {}

    defaultCreditPackages.push(pkg);
    res.status(201).json({ success: true, data: pkg });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

export const updateCreditPackage = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { name, credits, price, description, tag, isActive, sortOrder } = req.body;

    let updatedPkg: any = null;

    try {
      updatedPkg = await prisma.appCreditPackage.update({
        where: { id },
        data: {
          ...(name !== undefined && { name }),
          ...(credits !== undefined && { credits: Number(credits) }),
          ...(price !== undefined && { price: Number(price) }),
          ...(description !== undefined && { description }),
          ...(tag !== undefined && { tag: tag || null }),
          ...(isActive !== undefined && { isActive: Boolean(isActive) }),
          ...(sortOrder !== undefined && { sortOrder: Number(sortOrder) }),
        },
      });
    } catch (_) {}

    const idx = defaultCreditPackages.findIndex((p) => p.id === id);
    if (idx !== -1) {
      defaultCreditPackages[idx] = {
        ...defaultCreditPackages[idx],
        ...(name !== undefined && { name }),
        ...(credits !== undefined && { credits: Number(credits) }),
        ...(price !== undefined && { price: Number(price) }),
        ...(description !== undefined && { description }),
        ...(tag !== undefined && { tag: tag || null }),
        ...(isActive !== undefined && { isActive: Boolean(isActive) }),
        ...(sortOrder !== undefined && { sortOrder: Number(sortOrder) }),
      };
      if (!updatedPkg) updatedPkg = defaultCreditPackages[idx];
    }

    if (!updatedPkg) {
      return res.status(404).json({ success: false, error: 'Credit package not found' });
    }

    res.json({ success: true, data: updatedPkg });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

export const toggleCreditPackageStatus = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    let toggled: any = null;

    try {
      const existing = await prisma.appCreditPackage.findUnique({ where: { id } });
      if (existing) {
        toggled = await prisma.appCreditPackage.update({
          where: { id },
          data: { isActive: !existing.isActive },
        });
      }
    } catch (_) {}

    const idx = defaultCreditPackages.findIndex((p) => p.id === id);
    if (idx !== -1) {
      defaultCreditPackages[idx].isActive = !defaultCreditPackages[idx].isActive;
      if (!toggled) toggled = defaultCreditPackages[idx];
    }

    if (!toggled) {
      return res.status(404).json({ success: false, error: 'Credit package not found' });
    }

    res.json({ success: true, data: toggled });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

export const deleteCreditPackage = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    try {
      await prisma.appCreditPackage.delete({ where: { id } });
    } catch (_) {}

    defaultCreditPackages = defaultCreditPackages.filter((p) => p.id !== id);
    res.json({ success: true, message: 'Credit package deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};
