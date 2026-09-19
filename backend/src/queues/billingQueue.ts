import { Queue, Worker, Job } from 'bullmq';
import { redisConfig } from '../config/redis';
import { prisma } from '../index';

export const BILLING_QUEUE_NAME = 'monthly-billing-queue';

export const billingQueue = new Queue(BILLING_QUEUE_NAME, {
  connection: redisConfig,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 10000,
    },
    removeOnComplete: 100,
    removeOnFail: 200,
  },
});

/**
 * Worker to automatically generate monthly billing payment schedules
 */
export const billingWorker = new Worker(
  BILLING_QUEUE_NAME,
  async (job: Job) => {
    const { name } = job;
    console.log(`[BillingWorker] Executing job "${name}" (ID: ${job.id})`);

    if (name === 'generate-monthly-schedules' || name === 'manual-billing-run') {
      const now = new Date();
      const currentYear = now.getFullYear();
      const currentMonth = now.getMonth(); // 0-indexed

      // 1. Fetch all active members who have an active plan
      const activeMembers = await prisma.member.findMany({
        where: {
          isActive: true,
          planId: { not: null },
        },
        include: {
          plan: true,
        },
      });

      console.log(`[BillingWorker] Found ${activeMembers.length} active members to check for billing`);

      let createdCount = 0;
      let skippedCount = 0;

      for (const member of activeMembers) {
        if (!member.plan) continue;
        const plan = member.plan;

        // Determine due date based on collectionDayType
        let dueDate: Date;
        if (plan.collectionDayType === 'FIRST_DAY_OF_MONTH') {
          dueDate = new Date(currentYear, currentMonth, 1);
        } else if (plan.collectionDayType === 'LAST_DAY_OF_MONTH') {
          dueDate = new Date(currentYear, currentMonth + 1, 0);
        } else {
          const customDay = plan.customDayNumber || 1;
          dueDate = new Date(currentYear, currentMonth, customDay);
        }

        const monthYear = `${dueDate.getFullYear()}-${String(dueDate.getMonth() + 1).padStart(2, '0')}`;

        // Check if schedule already exists for this member and monthYear
        const existing = await prisma.paymentSchedule.findFirst({
          where: {
            memberId: member.id,
            monthYear,
          },
        });

        if (existing) {
          skippedCount++;
          continue;
        }

        // Create new monthly payment schedule
        await prisma.paymentSchedule.create({
          data: {
            memberId: member.id,
            monthYear,
            dueDate,
            amount: plan.price,
            status: 'UNPAID',
          },
        });

        createdCount++;
      }

      console.log(`[BillingWorker] Billing completed: Created ${createdCount} new schedules, skipped ${skippedCount} existing.`);
      return { createdCount, skippedCount, totalChecked: activeMembers.length };
    }

    return { status: 'UNKNOWN_JOB' };
  },
  {
    connection: redisConfig,
    concurrency: 2,
  }
);

billingWorker.on('completed', (job) => {
  console.log(`[BillingWorker] Job ${job.id} finished successfully.`);
});

billingWorker.on('failed', (job, err) => {
  console.error(`[BillingWorker] Job ${job?.id} failed:`, err.message);
});

/**
 * Register monthly recurring cron job (Runs on 1st of every month at midnight)
 */
export const registerMonthlyBillingCron = async () => {
  try {
    await billingQueue.upsertJobScheduler(
      'monthly-billing-cron',
      { pattern: '0 0 1 * *' },
      { name: 'generate-monthly-schedules', data: {} }
    );
    console.log('⏰ Monthly Rent Billing Cron scheduled (1st of every month)');
  } catch (err) {
    console.warn('⚠️ Could not schedule monthly billing cron (Redis may be offline):', (err as Error).message);
  }
};
