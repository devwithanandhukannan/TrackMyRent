import { Router, Request, Response } from 'express';
import { getWhatsAppCredentials } from '../services/systemSettingService';

const router = Router();

/**
 * GET /api/whatsapp/webhook
 * Verification endpoint for Meta / WhatsApp Cloud API
 */
router.get('/', async (req: Request, res: Response) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  const { webhookSecret } = await getWhatsAppCredentials();
  const expectedToken = webhookSecret || process.env.WHATSAPP_VERIFY_TOKEN || 'trackmyrent_verify_token_2026';

  if (mode === 'subscribe' && token === expectedToken) {
    console.log('✅ WhatsApp Webhook verified successfully by Meta!');
    return res.status(200).send(challenge);
  }

  console.warn('❌ WhatsApp Webhook verification failed. Token mismatch or invalid mode.', { mode, token });
  return res.sendStatus(403);
});

/**
 * POST /api/whatsapp/webhook
 * Incoming message delivery status events from WhatsApp Cloud API.
 * MED-09 FIX: Now processes status updates instead of silently discarding them.
 */
router.post('/', (req: Request, res: Response) => {
  try {
    const body = req.body;
    const entries = body?.entry || [];

    for (const entry of entries) {
      for (const change of entry.changes || []) {
        const value = change.value;

        // Process message status updates (sent, delivered, read, failed)
        for (const status of value?.statuses || []) {
          const { id: messageId, status: deliveryStatus, timestamp, recipient_id, errors } = status;
          const ts = new Date(Number(timestamp) * 1000).toISOString();

          if (deliveryStatus === 'failed') {
            const errorCode = errors?.[0]?.code;
            const errorTitle = errors?.[0]?.title;
            console.error(
              `❌ [WhatsApp Webhook] Message ${messageId} FAILED to ${recipient_id} at ${ts} | Error ${errorCode}: ${errorTitle}`
            );
          } else {
            console.log(
              `✅ [WhatsApp Webhook] Message ${messageId} → ${deliveryStatus.toUpperCase()} to ${recipient_id} at ${ts}`
            );
          }
        }

        // Log incoming messages (tenants replying)
        for (const msg of value?.messages || []) {
          console.log(`📨 [WhatsApp Webhook] Incoming message from ${msg.from}: type=${msg.type}`);
        }
      }
    }
  } catch (parseError) {
    console.warn('[WhatsApp Webhook] Failed to parse event body:', (parseError as Error).message);
  }

  // Always return 200 to Meta to prevent webhook retries
  return res.status(200).json({ status: 'EVENT_RECEIVED' });
});

export default router;

