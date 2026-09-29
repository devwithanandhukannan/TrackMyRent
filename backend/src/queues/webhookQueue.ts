import { Queue, Worker, Job } from 'bullmq';
import { redisConfig } from '../config/redis';
import { prisma } from '../index';

export const WEBHOOK_QUEUE_NAME = 'payment-webhook-queue';

export const webhookQueue = new Queue(WEBHOOK_QUEUE_NAME, {
  connection: redisConfig,
  defaultJobOptions: {
    attempts: 5,
    backoff: {
      type: 'exponential',
      delay: 2000,
    },
    removeOnComplete: 200,
    removeOnFail: 500,
  },
});

/**
 * Worker to reliably process payment webhooks asynchronously
 */
export const webhookWorker = new Worker(
  WEBHOOK_QUEUE_NAME,
  async (job: Job) => {
    const { event, payload } = job.data;
    console.log(`[WebhookWorker] Processing webhook event "${event}" (Job ID: ${job.id})`);

    if (event === 'payment.captured' || event === 'payment_link.paid') {
      const payment = payload?.payment?.entity || payload?.paymentLink?.entity || payload;
      const paymentId = payment?.id;
      const amount = payment?.amount ? payment.amount / 100 : 0;
      const notes = payment?.notes || {};
      const scheduleId = notes?.scheduleId;

      // Mark any associated PaymentLinkRecord as PAID
      const linkEntityId = payload?.paymentLink?.entity?.id || payment?.payment_link_id;
      if (linkEntityId || scheduleId) {
        await prisma.paymentLinkRecord.updateMany({
          where: {
            OR: [
              ...(linkEntityId ? [{ linkId: linkEntityId }] : []),
              ...(scheduleId ? [{ scheduleId }] : []),
            ],
            status: { not: 'PAID' },
          },
          data: {
            status: 'PAID',
            paidAt: new Date(),
            paymentId: paymentId || undefined,
          },
        });
      }

      // If it is a subscription or credit package purchase from notes
      if (notes?.type === 'SUBSCRIPTION' && notes?.organizationId) {
        const numCredits = Number(notes.credits) || 0;

        // Link organization to matching AppSubscriptionPlan
        try {
          let resolvedPlan = null;
          if (notes.planId) {
            resolvedPlan = await prisma.appSubscriptionPlan.findUnique({
              where: { id: notes.planId },
            }).catch(() => null);
          }
          if (!resolvedPlan && notes.planName) {
            resolvedPlan = await prisma.appSubscriptionPlan.findFirst({
              where: { name: { equals: notes.planName, mode: 'insensitive' } },
            });
          }
          if (resolvedPlan) {
            await prisma.organization.update({
              where: { id: notes.organizationId },
              data: { selectedAppPlanId: resolvedPlan.id },
            });
          }
        } catch (planErr) {
          console.warn('[WebhookWorker] Could not link selectedAppPlanId:', planErr);
        }

        await prisma.subscriptionCredit.upsert({
          where: { organizationId: notes.organizationId },
          update: {
            planType: 'CREDIT',
            subscriptionName: notes.planName || 'Pro Plan',
            purchasedCredits: { increment: numCredits },
            expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
          },
          create: {
            organizationId: notes.organizationId,
            planType: 'CREDIT',
            subscriptionName: notes.planName || 'Pro Plan',
            purchasedCredits: numCredits > 0 ? numCredits : 100,
            expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
          },
        });
        console.log(`[WebhookWorker] Subscription activated for org ${notes.organizationId} via payment ${paymentId}`);
        return { status: 'SUCCESS', type: 'SUBSCRIPTION', organizationId: notes.organizationId };
      }

      // BUG-FIX BUG-07: Handle both 'CREDIT_TOPUP' (created by paymentController) and
      // 'CREDIT_PACKAGE' (legacy/webhook format) to ensure credits are always applied.
      if ((notes?.type === 'CREDIT_TOPUP' || notes?.type === 'CREDIT_PACKAGE') && notes?.organizationId) {
        const numCredits = Number(notes.credits) || 0;
        await prisma.subscriptionCredit.upsert({
          where: { organizationId: notes.organizationId },
          update: {
            purchasedCredits: { increment: numCredits },
          },
          create: {
            organizationId: notes.organizationId,
            planType: 'CREDIT',
            subscriptionName: 'Standard Plan',
            purchasedCredits: numCredits,
            expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
          },
        });
        console.log(`[WebhookWorker] Added ${numCredits} credits to org ${notes.organizationId} via payment ${paymentId}`);
        return { status: 'SUCCESS', type: notes.type, organizationId: notes.organizationId };
      }

      if (!scheduleId) {
        console.warn(`[WebhookWorker] No scheduleId or subscription found in webhook for payment ${paymentId}`);
        return { status: 'SKIPPED', reason: 'No scheduleId or subscription type provided' };
      }

      // Check if transaction with this payment ID already recorded (Idempotency)
      const existingTx = await prisma.transaction.findFirst({
        where: { notes: { contains: paymentId } },
      });

      if (existingTx) {
        console.log(`[WebhookWorker] Payment ${paymentId} already processed. Skipping.`);
        return { status: 'ALREADY_PROCESSED', transactionId: existingTx.id };
      }

      // Find and update schedule
      const schedule = await prisma.paymentSchedule.findUnique({
        where: { id: scheduleId },
      });

      if (!schedule) {
        throw new Error(`Schedule ${scheduleId} not found in database`);
      }

      // Update schedule to PAID
      const updatedSchedule = await prisma.paymentSchedule.update({
        where: { id: scheduleId },
        data: {
          status: 'PAID',
          notes: `Paid via Razorpay Webhook (${paymentId})`,
        },
      });

      // Record transaction
      const transaction = await prisma.transaction.create({
        data: {
          memberId: schedule.memberId,
          paymentScheduleId: schedule.id,
          amountPaid: amount || schedule.amount,
          paymentMethod: 'UPI',
          receiptUrl: `https://dashboard.razorpay.com/app/payments/${paymentId}`,
          notes: `Razorpay Payment ID: ${paymentId}`,
        },
      });

      console.log(`[WebhookWorker] Schedule ${scheduleId} marked as PAID via payment ${paymentId}`);
      return { status: 'SUCCESS', scheduleId, transactionId: transaction.id };
    }

    return { status: 'IGNORED_EVENT', event };
  },
  {
    connection: redisConfig,
    concurrency: 5,
  }
);

webhookWorker.on('completed', (job) => {
  console.log(`[WebhookWorker] Webhook job ${job.id} completed.`);
});

webhookWorker.on('failed', (job, err) => {
  console.error(`[WebhookWorker] Webhook job ${job?.id} failed:`, err.message);
});
