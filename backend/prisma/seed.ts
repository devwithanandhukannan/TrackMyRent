import { PrismaClient, OrgType, Role } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // Create demo organization
  let org = await prisma.organization.findFirst({
    where: { name: 'RentTrack Demo Gym & Hostel' },
  });
  if (!org) {
    org = await prisma.organization.create({
      data: {
        name: 'RentTrack Demo Gym & Hostel',
        type: OrgType.GYM,
      },
    });
  }

  // Create admin user
  const passwordHash = await bcrypt.hash('admin123', 10);
  let admin = await prisma.user.findUnique({
    where: { email: 'admin@renttrack.app' },
  });
  if (!admin) {
    admin = await prisma.user.create({
      data: {
        organizationId: org.id,
        name: 'Anandhu Admin',
        email: 'admin@renttrack.app',
        passwordHash,
        role: Role.ORG_ADMIN,
      },
    });
  }

  // Create default subscription & credits
  const existingCredit = await prisma.subscriptionCredit.findUnique({
    where: { organizationId: org.id },
  });
  if (!existingCredit) {
    await prisma.subscriptionCredit.create({
      data: {
        organizationId: org.id,
        planType: 'CREDIT',
        subscriptionName: 'Plus Plan (Trial)',
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
        purchasedCredits: 100,
        usedCredits: 0,
      },
    });
  }

  // Create default expense categories
  const categories = ['Rent', 'Utilities', 'Equipment', 'Salary', 'Maintenance', 'Marketing', 'Other'];
  for (const cat of categories) {
    await prisma.expenseCategory.create({
      data: {
        organizationId: org.id,
        name: cat,
        isCustom: false,
      },
    });
  }

  // Create sample business plans
  const samplePlans = [
    { name: 'Standard Shop', price: 18500, durationDays: 30, frequencyMonths: 1 },
    { name: 'Premium Corner', price: 27500, durationDays: 30, frequencyMonths: 1 },
    { name: 'Storage Unit', price: 12000, durationDays: 90, frequencyMonths: 3 },
  ];

  for (const p of samplePlans) {
    const existing = await prisma.plan.findFirst({
      where: { organizationId: org.id, name: p.name },
    });
    if (!existing) {
      const createdPlan = await prisma.plan.create({
        data: {
          organizationId: org.id,
          name: p.name,
          price: p.price,
          durationDays: p.durationDays,
          frequencyMonths: p.frequencyMonths,
        },
      });

      // Seed 2 members for Standard Shop
      if (p.name === 'Standard Shop') {
        const m1 = await prisma.member.create({
          data: {
            organizationId: org.id,
            planId: createdPlan.id,
            fullName: 'Priya Sharma',
            phone: '+91 98765 43210',
            duration: '30 Days',
          },
        });
        await prisma.paymentSchedule.create({
          data: {
            memberId: m1.id,
            monthYear: '2026-06',
            dueDate: new Date(),
            amount: 18500,
            status: 'PAID',
          },
        });

        const m2 = await prisma.member.create({
          data: {
            organizationId: org.id,
            planId: createdPlan.id,
            fullName: 'Rahul Verma',
            phone: '+91 98123 45678',
            duration: '30 Days',
          },
        });
        await prisma.paymentSchedule.create({
          data: {
            memberId: m2.id,
            monthYear: '2026-07',
            dueDate: new Date(),
            amount: 18500,
            status: 'PAID',
          },
        });
      }

      // Seed 1 member for Premium Corner
      if (p.name === 'Premium Corner') {
        const m3 = await prisma.member.create({
          data: {
            organizationId: org.id,
            planId: createdPlan.id,
            fullName: 'Amit Patel',
            phone: '+91 97111 22334',
            duration: '30 Days',
          },
        });
        await prisma.paymentSchedule.create({
          data: {
            memberId: m3.id,
            monthYear: '2026-07',
            dueDate: new Date(),
            amount: 27500,
            status: 'PAID',
          },
        });
      }
    }
  }

  // Create App Subscription Plans
  const appPlans = [
    {
      name: 'Free trial 30 days',
      price: 0,
      tag: 'Default',
      description: 'All features unlocked for one month',
      durationMonths: 1,
      isFreeTrial: true,
      isActive: true,
      sortOrder: 1,
    },
    {
      name: 'Plus',
      price: 399,
      tag: null,
      description: 'All features unlocked for one month',
      durationMonths: 1,
      isFreeTrial: false,
      isActive: true,
      sortOrder: 2,
    },
    {
      name: 'Max',
      price: 699,
      tag: null,
      description: 'All features unlocked for three months',
      durationMonths: 3,
      isFreeTrial: false,
      isActive: true,
      sortOrder: 3,
    },
    {
      name: 'Max+',
      price: 999,
      tag: 'Popular',
      description: 'All features unlocked for six months',
      durationMonths: 6,
      isFreeTrial: false,
      isActive: true,
      sortOrder: 4,
    },
  ];

  for (const planData of appPlans) {
    const existing = await prisma.appSubscriptionPlan.findFirst({
      where: { name: planData.name },
    });
    if (!existing) {
      await prisma.appSubscriptionPlan.create({ data: planData });
    }
  }

  console.log(`✅ Seed completed! Demo Org ID: ${org.id}, Admin: ${admin.email}`);
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
