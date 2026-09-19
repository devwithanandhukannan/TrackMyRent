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

      if (!scheduleId) {
        console.warn(`[WebhookWorker] No scheduleId found in webhook notes for payment ${paymentId}`);
        return { status: 'SKIPPED', reason: 'No scheduleId provided' };
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
