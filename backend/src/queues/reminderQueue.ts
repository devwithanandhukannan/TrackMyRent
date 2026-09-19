import { Queue, Worker, Job } from 'bullmq';
import { redisConfig } from '../config/redis';
import { prisma } from '../index';

export const REMINDER_QUEUE_NAME = 'whatsapp-reminder-queue';

export const reminderQueue = new Queue(REMINDER_QUEUE_NAME, {
  connection: redisConfig,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 5000,
    },
    removeOnComplete: 100,
    removeOnFail: 200,
  },
});

/**
 * Worker to process automated daily reminders and individual WhatsApp dispatches
 */
export const reminderWorker = new Worker(
  REMINDER_QUEUE_NAME,
  async (job: Job) => {
    const { name, data } = job;
    console.log(`[ReminderWorker] Processing job "${name}" (ID: ${job.id})`);

    if (name === 'daily-reminder-scan') {
      // 1. Scan for members whose rent is due in next 2 days or overdue
      const now = new Date();
      const threeDaysAhead = new Date();
      threeDaysAhead.setDate(now.getDate() + 3);

      const dueSchedules = await prisma.paymentSchedule.findMany({
        where: {
          status: 'UNPAID',
          dueDate: {
            lte: threeDaysAhead,
          },
        },
        include: {
          member: {
            include: { organization: true },
          },
        },
        take: 200, // Batch limit
      });

      console.log(`[ReminderWorker] Found ${dueSchedules.length} pending schedules for reminder`);

      for (const schedule of dueSchedules) {
        await reminderQueue.add('send-single-reminder', {
          scheduleId: schedule.id,
          memberId: schedule.memberId,
          organizationId: schedule.member.organizationId,
        });
      }

      return { scannedCount: dueSchedules.length };
    }

    if (name === 'send-single-reminder') {
      const { scheduleId } = data;
      const schedule = await prisma.paymentSchedule.findUnique({
        where: { id: scheduleId },
        include: {
          member: {
            include: { organization: true, plan: true },
          },
        },
      });

      if (!schedule || schedule.status !== 'UNPAID') {
        return { status: 'SKIPPED', reason: 'Schedule not found or already paid' };
      }

      const member = schedule.member;
      const org = member.organization;

      // Check tenant's WhatsApp credit balance
      const subCredit = await prisma.subscriptionCredit.findUnique({
        where: { organizationId: org.id },
      });

      let creditDeducted = false;
      if (subCredit && subCredit.purchasedCredits - subCredit.usedCredits > 0) {
        await prisma.subscriptionCredit.update({
          where: { organizationId: org.id },
          data: { usedCredits: { increment: 1 } },
        });
        creditDeducted = true;
      }

      // Build UPI link
      let paymentLink = '';
      if (org.bankUpiId) {
        const payeeName = encodeURIComponent(org.bankAccountName || org.name);
        const note = encodeURIComponent(`Rent ${schedule.monthYear} - ${member.fullName}`);
        paymentLink = `upi://pay?pa=${encodeURIComponent(org.bankUpiId)}&pn=${payeeName}&am=${schedule.amount}&cu=INR&tn=${note}`;
      } else {
        paymentLink = `https://trackmyrent.app/pay/${schedule.id}`;
      }

      console.log(
        `[ReminderWorker] Reminder queued for ${member.fullName} (${member.phone}) | Due: ₹${schedule.amount} | Credit Deducted: ${creditDeducted}`
      );

      return {
        status: 'SUCCESS',
        member: member.fullName,
        phone: member.phone,
        amount: schedule.amount,
        paymentLink,
        creditDeducted,
      };
    }

    return { status: 'UNKNOWN_JOB' };
  },
  {
    connection: redisConfig,
    concurrency: 5,
  }
);

reminderWorker.on('completed', (job) => {
  console.log(`[ReminderWorker] Job ${job.id} completed successfully.`);
});

reminderWorker.on('failed', (job, err) => {
  console.error(`[ReminderWorker] Job ${job?.id} failed:`, err.message);
});

/**
 * Register repeatable cron job (Runs daily at 09:00 AM)
 */
export const registerDailyReminderCron = async () => {
  try {
    await reminderQueue.upsertJobScheduler(
      'daily-reminder-cron',
      { pattern: '0 9 * * *' },
      { name: 'daily-reminder-scan', data: {} }
    );
    console.log('⏰ Daily WhatsApp Reminder Cron scheduled (09:00 AM every day)');
  } catch (err) {
    console.warn('⚠️ Could not schedule daily reminder cron (Redis may be offline):', (err as Error).message);
  }
};
