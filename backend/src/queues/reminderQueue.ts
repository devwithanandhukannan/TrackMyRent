import { Queue, Worker, Job } from 'bullmq';
import { redisConfig } from '../config/redis';
import { prisma } from '../index';
import { sendWhatsAppReminder, sendWhatsAppRenewalReminder } from '../services/whatsappService';

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
      const now = new Date();
      const threeDaysAhead = new Date();
      threeDaysAhead.setDate(now.getDate() + 3);

      // 1. Scan for members whose rent is due in next 2-3 days or overdue
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

      // Pre-filter schedules to only queue reminders for orgs that have valid, non-expired credits.
      const eligibleSchedules = [];
      const orgCreditCache = new Map<string, boolean>();

      for (const schedule of dueSchedules) {
        const orgId = schedule.member.organizationId;
        if (!orgCreditCache.has(orgId)) {
          const subCredit = await prisma.subscriptionCredit.findUnique({ where: { organizationId: orgId } });
          const isExpired = subCredit?.expiresAt && subCredit.expiresAt < now;
          const hasCredits = subCredit && !isExpired && (subCredit.purchasedCredits - subCredit.usedCredits) > 0;
          orgCreditCache.set(orgId, !!hasCredits);
        }
        if (orgCreditCache.get(orgId)) {
          eligibleSchedules.push(schedule);
        }
      }

      console.log(`[ReminderWorker] ${eligibleSchedules.length}/${dueSchedules.length} schedules eligible (orgs with valid credits)`);

      for (const schedule of eligibleSchedules) {
        await reminderQueue.add('send-single-reminder', {
          scheduleId: schedule.id,
          memberId: schedule.memberId,
          organizationId: schedule.member.organizationId,
        });
      }

      // 2. Scan for members whose subscription / membership expires in the next 1 or 2 days
      const activeMembers = await prisma.member.findMany({
        where: {
          isActive: true,
          planId: { not: null },
        },
        include: {
          plan: true,
          organization: true,
          paymentSchedules: {
            orderBy: { dueDate: 'desc' },
            take: 1,
          },
        },
        take: 200,
      });

      let renewalQueuedCount = 0;
      for (const m of activeMembers) {
        if (!m.plan) continue;
        const orgId = m.organizationId;

        if (!orgCreditCache.has(orgId)) {
          const subCredit = await prisma.subscriptionCredit.findUnique({ where: { organizationId: orgId } });
          const isExpired = subCredit?.expiresAt && subCredit.expiresAt < now;
          const hasCredits = subCredit && !isExpired && (subCredit.purchasedCredits - subCredit.usedCredits) > 0;
          orgCreditCache.set(orgId, !!hasCredits);
        }
        if (!orgCreditCache.get(orgId)) continue;

        // Calculate expiry date: based on latest payment schedule dueDate or joiningDate + plan durationDays
        let expiryDate: Date;
        if (m.paymentSchedules && m.paymentSchedules.length > 0) {
          expiryDate = new Date(m.paymentSchedules[0].dueDate);
        } else {
          const days = m.plan.durationDays || (m.plan.frequencyMonths * 30) || 30;
          expiryDate = new Date(m.joiningDate.getTime() + days * 24 * 60 * 60 * 1000);
        }

        const diffMs = expiryDate.getTime() - now.getTime();
        const diffDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

        // Trigger reminder if expiring in 1 or 2 days
        if (diffDays === 1 || diffDays === 2) {
          await reminderQueue.add('send-renewal-reminder', {
            memberId: m.id,
            organizationId: m.organizationId,
            expiryDateStr: expiryDate.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }),
          });
          renewalQueuedCount++;
        }
      }

      console.log(`[ReminderWorker] Queued ${renewalQueuedCount} membership renewal reminders (expiring in 1-2 days)`);

      return {
        scannedCount: dueSchedules.length,
        queuedCount: eligibleSchedules.length,
        renewalQueuedCount,
      };
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

      // Fetch organization subscription credits
      const subCredit = await prisma.subscriptionCredit.findUnique({
        where: { organizationId: org.id },
      });

      const now = new Date();
      let creditDeducted = false;
      if (subCredit) {
        const isExpired = subCredit.expiresAt && subCredit.expiresAt < now;
        const available = subCredit.purchasedCredits - subCredit.usedCredits;
        if (!isExpired && available > 0) {
          await prisma.subscriptionCredit.update({
            where: { organizationId: org.id },
            data: { usedCredits: { increment: 1 } },
          });
          creditDeducted = true;
        }
      }

      if (!creditDeducted) {
        return { status: 'SKIPPED', reason: 'No valid credits or subscription expired' };
      }

      // Build Direct Tenant Payout Link (Hosted Gateway with UPI Intent, QR, and Bank Details)
      const backendBase = process.env.BACKEND_PUBLIC_URL || 'https://trackmyrent.anandhu-kannan.in';
      const paymentLink = `${backendBase}/pay/${schedule.id}`;

      const dueDate = schedule.dueDate
        ? new Date(schedule.dueDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
        : 'soon';

      const waResult = await sendWhatsAppReminder({
        phone: String(member.phone),
        memberName: member.fullName,
        billingMonth: schedule.monthYear || 'Current Month',
        amount: schedule.amount,
        dueDate,
        paymentLink,
        facilityName: org.name || 'TrackMyRent',
      });

      if (!waResult.success) {
        // Refund credit if send failed
        await prisma.subscriptionCredit.update({
          where: { organizationId: org.id },
          data: { usedCredits: { decrement: 1 } },
        });
      }

      console.log(
        `[ReminderWorker] Reminder ${waResult.success ? 'SENT' : 'FAILED'} for ${member.fullName} (${member.phone}) | Due: ₹${schedule.amount} | MsgID: ${waResult.messageId || 'N/A'}`
      );

      return {
        status: waResult.success ? 'SENT' : 'FAILED',
        member: member.fullName,
        phone: member.phone,
        amount: schedule.amount,
        paymentLink,
        creditDeducted: waResult.success,
        whatsappMessageId: waResult.messageId,
      };
    }

    if (name === 'send-renewal-reminder') {
      const { memberId, expiryDateStr } = data;
      const member = await prisma.member.findUnique({
        where: { id: memberId },
        include: { organization: true, plan: true },
      });

      if (!member || !member.isActive || !member.plan) {
        return { status: 'SKIPPED', reason: 'Member or plan not found or inactive' };
      }

      const org = member.organization;
      const subCredit = await prisma.subscriptionCredit.findUnique({
        where: { organizationId: org.id },
      });

      const now = new Date();
      let creditDeducted = false;
      if (subCredit) {
        const isExpired = subCredit.expiresAt && subCredit.expiresAt < now;
        const available = subCredit.purchasedCredits - subCredit.usedCredits;
        if (!isExpired && available > 0) {
          await prisma.subscriptionCredit.update({
            where: { organizationId: org.id },
            data: { usedCredits: { increment: 1 } },
          });
          creditDeducted = true;
        }
      }

      if (!creditDeducted) {
        return { status: 'SKIPPED', reason: 'No valid credits or subscription expired' };
      }

      // Build renewal payment link using hosted payment gateway (clickable in WhatsApp)
      const backendBase = process.env.BACKEND_PUBLIC_URL || 'https://trackmyrent.anandhu-kannan.in';
      const renewalLink = `${backendBase}/pay/renew/${member.id}`;

      const waResult = await sendWhatsAppRenewalReminder({
        phone: String(member.phone),
        memberName: member.fullName,
        planName: member.plan.name,
        facilityName: org.name,
        expiryDate: expiryDateStr,
        renewalLink,
      });

      if (!waResult.success) {
        await prisma.subscriptionCredit.update({
          where: { organizationId: org.id },
          data: { usedCredits: { decrement: 1 } },
        });
      }

      console.log(
        `[ReminderWorker] Renewal reminder ${waResult.success ? 'SENT' : 'FAILED'} for ${member.fullName} (${member.phone}) | MsgID: ${waResult.messageId || 'N/A'}`
      );

      return {
        status: waResult.success ? 'SENT' : 'FAILED',
        member: member.fullName,
        phone: member.phone,
        plan: member.plan.name,
        renewalLink,
        creditDeducted: waResult.success,
        whatsappMessageId: waResult.messageId,
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
