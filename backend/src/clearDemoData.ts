import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function clearDemoData() {
  console.log('🧹 Clearing sample demo members, plans, schedules, and transactions...');

  // Delete all transactions
  await prisma.transaction.deleteMany({});

  // Delete all payment schedules
  await prisma.paymentSchedule.deleteMany({});

  // Delete all members
  await prisma.member.deleteMany({});

  // Delete all groups
  await prisma.group.deleteMany({});

  // Delete all plans
  await prisma.plan.deleteMany({});

  // Delete all expenses
  await prisma.expense.deleteMany({});

  console.log('✅ Demo data successfully cleared from PostgreSQL database!');
}

clearDemoData()
  .catch((e) => {
    console.error('❌ Error clearing demo data:', e);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
