import { Router, Request, Response } from 'express';
import { checkRedisHealth } from '../config/redis';
import { reminderQueue } from '../queues/reminderQueue';
import { billingQueue } from '../queues/billingQueue';
import { webhookQueue } from '../queues/webhookQueue';

const router = Router();

/**
 * GET /api/queues/status
 * Check Redis health and BullMQ queue metrics
 */
router.get('/status', async (req: Request, res: Response) => {
  try {
    const redisHealth = await checkRedisHealth();

    let reminderCounts = null;
    let billingCounts = null;
    let webhookCounts = null;

    if (redisHealth.isConnected) {
      try {
        const [rActive, rWaiting, rCompleted, rFailed] = await Promise.all([
          reminderQueue.getActiveCount(),
          reminderQueue.getWaitingCount(),
          reminderQueue.getCompletedCount(),
          reminderQueue.getFailedCount(),
        ]);
        reminderCounts = { active: rActive, waiting: rWaiting, completed: rCompleted, failed: rFailed };

        const [bActive, bWaiting, bCompleted, bFailed] = await Promise.all([
          billingQueue.getActiveCount(),
          billingQueue.getWaitingCount(),
          billingQueue.getCompletedCount(),
          billingQueue.getFailedCount(),
        ]);
        billingCounts = { active: bActive, waiting: bWaiting, completed: bCompleted, failed: bFailed };

        const [wActive, wWaiting, wCompleted, wFailed] = await Promise.all([
          webhookQueue.getActiveCount(),
          webhookQueue.getWaitingCount(),
          webhookQueue.getCompletedCount(),
          webhookQueue.getFailedCount(),
        ]);
        webhookCounts = { active: wActive, waiting: wWaiting, completed: wCompleted, failed: wFailed };
      } catch (countError) {
        console.warn('Queue counts read warning:', (countError as Error).message);
      }
    }

    res.status(200).json({
      success: true,
      redis: redisHealth,
      queues: {
        reminderQueue: reminderCounts,
        billingQueue: billingCounts,
        webhookQueue: webhookCounts,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

/**
 * POST /api/queues/trigger-reminders
 * Manually trigger daily payment reminder scanning
 */
router.post('/trigger-reminders', async (req: Request, res: Response) => {
  try {
    const job = await reminderQueue.add('daily-reminder-scan', {
      manualTrigger: true,
      triggeredAt: new Date().toISOString(),
    });

    res.status(200).json({
      success: true,
      message: 'Daily reminder scan job added to BullMQ reminder queue',
      jobId: job.id,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

/**
 * POST /api/queues/trigger-billing
 * Manually trigger monthly rent schedule generation
 */
router.post('/trigger-billing', async (req: Request, res: Response) => {
  try {
    const job = await billingQueue.add('manual-billing-run', {
      manualTrigger: true,
      triggeredAt: new Date().toISOString(),
    });

    res.status(200).json({
      success: true,
      message: 'Monthly billing job added to BullMQ billing queue',
      jobId: job.id,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
});

/**
 * POST /api/queues/webhook-razorpay
 * Ingest Razorpay webhooks directly into BullMQ without blocking
 */
router.post('/webhook-razorpay', async (req: Request, res: Response) => {
  try {
    const event = req.body.event || 'unknown';
    const payload = req.body.payload || req.body;

    const job = await webhookQueue.add('razorpay-event', {
      event,
      payload,
      receivedAt: new Date().toISOString(),
    });

    // Immediate 200 OK acknowledgment to payment gateway
    res.status(200).json({
      received: true,
      queuedJobId: job.id,
    });
  } catch (error) {
    res.status(500).json({ received: false, error: (error as Error).message });
  }
});

export default router;
