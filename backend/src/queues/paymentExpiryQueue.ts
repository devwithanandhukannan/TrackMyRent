import { Queue, Worker, Job } from 'bullmq';
import { redisConfig } from '../config/redis';
import { prisma } from '../index';
import { cancelRazorpayPaymentLink } from '../services/razorpayService';

export const PAYMENT_EXPIRY_QUEUE_NAME = 'payment-expiry-queue';

export const paymentExpiryQueue = new Queue(PAYMENT_EXPIRY_QUEUE_NAME, {
  connection: redisConfig,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 5000,
    },
    removeOnComplete: 200,
    removeOnFail: 500,
  },
});

/**
 * Worker to automatically cancel & expire payment links after exactly 10 minutes
 */
export const paymentExpiryWorker = new Worker(
  PAYMENT_EXPIRY_QUEUE_NAME,
  async (job: Job) => {
    const { linkId, recordId } = job.data;
    console.log(`[PaymentExpiryWorker] Checking 10-minute expiry for link "${linkId}" (Job: ${job.id})`);

    const record = await prisma.paymentLinkRecord.findFirst({
      where: {
        OR: [
          { linkId },
          { id: recordId },
        ],
      },
    });

    if (!record) {
      console.warn(`[PaymentExpiryWorker] No PaymentLinkRecord found for ${linkId}`);
      return { status: 'NOT_FOUND', linkId };
    }

    if (record.status === 'PAID') {
      console.log(`[PaymentExpiryWorker] Link ${linkId} was already paid within 10 minutes. No expiry needed.`);
      return { status: 'ALREADY_PAID', linkId, paidAt: record.paidAt };
    }

    if (record.status === 'CANCELLED' || record.status === 'EXPIRED') {
      console.log(`[PaymentExpiryWorker] Link ${linkId} is already marked as ${record.status}.`);
      return { status: record.status, linkId };
    }

    // Still PENDING after 10 minutes -> Cancel in Razorpay and mark as EXPIRED
    try {
      await cancelRazorpayPaymentLink(record.linkId);
    } catch (err: any) {
      console.warn(`[PaymentExpiryWorker] Error cancelling in Razorpay:`, err.message);
    }

    const updated = await prisma.paymentLinkRecord.update({
      where: { id: record.id },
      data: {
        status: 'EXPIRED',
        cancelledAt: new Date(),
      },
    });

    console.log(`[PaymentExpiryWorker] Link ${record.linkId} marked as EXPIRED after 10 minutes.`);
    return { status: 'EXPIRED', linkId: record.linkId, expiredAt: updated.cancelledAt };
  },
  {
    connection: redisConfig,
    concurrency: 5,
  }
);

paymentExpiryWorker.on('completed', (job) => {
  console.log(`[PaymentExpiryWorker] Job ${job.id} completed.`);
});

paymentExpiryWorker.on('failed', (job, err) => {
  console.error(`[PaymentExpiryWorker] Job ${job?.id} failed:`, err.message);
});
