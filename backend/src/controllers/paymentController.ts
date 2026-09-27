import { Request, Response } from 'express';
import { prisma } from '../index';
import {
  createRazorpayOrder,
  verifyRazorpaySignature,
  createRazorpayPaymentLink,
  cancelRazorpayPaymentLink,
  fetchRazorpayPaymentLink,
  fetchPaymentDetails,
} from '../services/razorpayService';
import { sendWhatsAppReceipt, sendWhatsAppReminder, sendWhatsAppFreezeConfirmation } from '../services/whatsappService';
import { paymentExpiryQueue } from '../queues/paymentExpiryQueue';
import { getRazorpayCredentials } from '../services/systemSettingService';

/**
 * Generate payment schedules based on Plan Duration & Frequency Settings
 * Frequency: 1, 3, 6, 12 months
 * Collection Day: FIRST_DAY_OF_MONTH (1st), LAST_DAY_OF_MONTH, or CUSTOM_DAY_OF_MONTH (e.g., 5th)
 */
export const generatePaymentSchedules = async (req: Request, res: Response) => {
  try {
    const { memberId, planId, startDate, numberOfCycles = 4 } = req.body;

    const member = await prisma.member.findUnique({ where: { id: memberId } });
    if (!member) return res.status(404).json({ error: 'Member not found' });

    const plan = await prisma.plan.findUnique({ where: { id: planId } });
    if (!plan) return res.status(404).json({ error: 'Plan not found' });

    const schedules = [];
    let baseDate = new Date(startDate || member.joiningDate);

    for (let i = 0; i < numberOfCycles; i++) {
      const cycleDate = new Date(baseDate);
      cycleDate.setMonth(cycleDate.getMonth() + i * plan.frequencyMonths);

      let dueDate: Date;
      if (plan.collectionDayType === 'FIRST_DAY_OF_MONTH') {
        dueDate = new Date(cycleDate.getFullYear(), cycleDate.getMonth(), 1);
      } else if (plan.collectionDayType === 'LAST_DAY_OF_MONTH') {
        dueDate = new Date(cycleDate.getFullYear(), cycleDate.getMonth() + 1, 0);
      } else {
        const customDay = plan.customDayNumber || 1;
        dueDate = new Date(cycleDate.getFullYear(), cycleDate.getMonth(), customDay);
      }

      const monthYear = `${dueDate.getFullYear()}-${String(dueDate.getMonth() + 1).padStart(2, '0')}`;

      const schedule = await prisma.paymentSchedule.create({
        data: {
          memberId: member.id,
          monthYear,
          dueDate,
          amount: plan.price,
          status: 'UNPAID',
        },
      });
      schedules.push(schedule);
    }

    res.status(201).json({ message: 'Payment schedules generated successfully', schedules });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Mark a payment schedule as PAID and send WhatsApp receipt via Cloud API
 */
export const markAsPaid = async (req: Request, res: Response) => {
  try {
    const { scheduleId, amountPaid, paymentMethod = 'CASH', notes } = req.body;

    const schedule = await prisma.paymentSchedule.findUnique({
      where: { id: scheduleId },
      include: {
        member: {
          include: { organization: true },
        },
      },
    });
    if (!schedule) return res.status(404).json({ error: 'Payment schedule not found' });

    const updatedSchedule = await prisma.paymentSchedule.update({
      where: { id: scheduleId },
      data: { status: 'PAID', notes },
    });

    const finalAmount = amountPaid || schedule.amount;
    const transaction = await prisma.transaction.create({
      data: {
        memberId: schedule.memberId,
        paymentScheduleId: schedule.id,
        amountPaid: finalAmount,
        paymentMethod,
        notes,
      },
    });

    // BUG-FIX BUG-06: Send WhatsApp receipt via Cloud API (not manual wa.me)
    let whatsappSent = false;
    if (schedule.member?.phone) {
      const org = schedule.member.organization;
      const receiptUrl = `${process.env.APP_BASE_URL || 'https://trackmyrent.app'}/receipt/${transaction.id}`;
      const waResult = await sendWhatsAppReceipt({
        phone: schedule.member.phone,
        memberName: schedule.member.fullName,
        billingMonth: schedule.monthYear || 'Current Month',
        amountPaid: finalAmount,
        paymentMethod,
        receiptUrl,
        facilityName: org?.name || 'TrackMyRent',
      });
      whatsappSent = waResult.success;

      // Deduct 1 WhatsApp credit if sent successfully
      if (whatsappSent && org) {
        const subCredit = await prisma.subscriptionCredit.findUnique({ where: { organizationId: org.id } });
        const now = new Date();
        const isExpired = subCredit?.expiresAt && subCredit.expiresAt < now;
        if (subCredit && !isExpired && (subCredit.purchasedCredits - subCredit.usedCredits) > 0) {
          await prisma.subscriptionCredit.update({
            where: { organizationId: org.id },
            data: { usedCredits: { increment: 1 } },
          });
        }
      }
    }

    res.status(200).json({
      message: 'Payment marked as PAID',
      schedule: updatedSchedule,
      transaction,
      whatsappReceiptSent: whatsappSent,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Revert payment status back to UNPAID (with confirmation requirement)
 * BUG-FIX HIGH-04: Also deletes/voids the associated transaction record
 */
export const markAsUnpaid = async (req: Request, res: Response) => {
  try {
    const { scheduleId, confirmed = false } = req.body;

    if (!confirmed) {
      return res.status(400).json({
        warningRequired: true,
        message: 'This payment was previously marked as Paid. Are you sure you want to change its status to Unpaid?',
      });
    }

    // Delete associated transaction records before reverting (fixes stale financial data)
    await prisma.transaction.deleteMany({
      where: { paymentScheduleId: scheduleId },
    });

    const updatedSchedule = await prisma.paymentSchedule.update({
      where: { id: scheduleId },
      data: { status: 'UNPAID' },
    });

    res.status(200).json({ message: 'Payment reverted to UNPAID successfully. Associated transaction voided.', schedule: updatedSchedule });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Freeze a specific month (excludes month from pending sum & collection reports)
 */
export const freezeMonth = async (req: Request, res: Response) => {
  try {
    const { scheduleId, notes } = req.body;

    const schedule = await prisma.paymentSchedule.findUnique({
      where: { id: scheduleId },
      include: {
        member: {
          include: { organization: true },
        },
      },
    });
    if (!schedule) return res.status(404).json({ error: 'Payment schedule not found' });

    const updatedSchedule = await prisma.paymentSchedule.update({
      where: { id: scheduleId },
      data: {
        status: 'FROZEN',
        frozenAt: new Date(),
        notes: notes || 'Month frozen by admin',
      },
    });

    let whatsappSent = false;
    if (schedule.member?.phone) {
      const org = schedule.member.organization;
      const waResult = await sendWhatsAppFreezeConfirmation({
        phone: schedule.member.phone,
        memberName: schedule.member.fullName,
        frozenMonth: schedule.monthYear || 'Current Month',
        notes: notes || 'Month billing frozen by admin',
      });
      whatsappSent = waResult.success;

      // Deduct 1 credit if sent
      if (whatsappSent && org) {
        const subCredit = await prisma.subscriptionCredit.findUnique({ where: { organizationId: org.id } });
        const now = new Date();
        const isExpired = subCredit?.expiresAt && subCredit.expiresAt < now;
        if (subCredit && !isExpired && (subCredit.purchasedCredits - subCredit.usedCredits) > 0) {
          await prisma.subscriptionCredit.update({
            where: { organizationId: org.id },
            data: { usedCredits: { increment: 1 } },
          });
        }
      }
    }

    res.status(200).json({
      message: 'Month frozen successfully. Excluded from pending dues calculations.',
      schedule: updatedSchedule,
      whatsappFreezeSent: whatsappSent,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Unfreeze a month back to UNPAID
 */
export const unfreezeMonth = async (req: Request, res: Response) => {
  try {
    const { scheduleId } = req.body;

    const updatedSchedule = await prisma.paymentSchedule.update({
      where: { id: scheduleId },
      data: {
        status: 'UNPAID',
        frozenAt: null,
      },
    });

    res.status(200).json({ message: 'Month unfrozen back to UNPAID', schedule: updatedSchedule });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Calculate Pending Dues Formula: Sum of Unpaid Months excluding Frozen Months
 */
export const getPendingDues = async (req: Request, res: Response) => {
  try {
    const { memberId } = req.params;

    const unpaidSchedules = await prisma.paymentSchedule.findMany({
      where: {
        memberId,
        status: 'UNPAID', // Excludes FROZEN and PAID
      },
    });

    const totalPendingAmount = unpaidSchedules.reduce((sum, s) => sum + s.amount, 0);

    const frozenSchedules = await prisma.paymentSchedule.findMany({
      where: { memberId, status: 'FROZEN' },
    });

    res.status(200).json({
      memberId,
      totalPendingAmount,
      unpaidCount: unpaidSchedules.length,
      frozenCount: frozenSchedules.length,
      unpaidSchedules,
      frozenSchedules,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Helper to cancel any existing pending payment links for an organization or schedule
 */
const cleanupPendingLinks = async (filter: { organizationId?: string; scheduleId?: string; type?: string }) => {
  try {
    const existingPending = await prisma.paymentLinkRecord.findMany({
      where: {
        ...filter,
        status: 'PENDING',
      },
    });

    for (const oldLink of existingPending) {
      await cancelRazorpayPaymentLink(oldLink.linkId);
      await prisma.paymentLinkRecord.update({
        where: { id: oldLink.id },
        data: {
          status: 'CANCELLED',
          cancelledAt: new Date(),
        },
      });
      console.log(`[PaymentController] Superseded old pending link ${oldLink.linkId} and cancelled it.`);
    }
  } catch (err: any) {
    console.warn('[PaymentController] Error cleaning up old pending links:', err.message);
  }
};

/**
 * Production Razorpay Order Creation with 10-Minute Validity & Duplicate Protection
 */
export const createRazorpayPaymentOrder = async (req: Request, res: Response) => {
  try {
    const { scheduleId, memberId, amount } = req.body;

    const schedule = await prisma.paymentSchedule.findUnique({
      where: { id: scheduleId },
      include: { member: true },
    });
    if (!schedule) return res.status(404).json({ success: false, error: 'Schedule not found' });

    // Guard 1: Prevent paying for an already-paid schedule
    if (schedule.status === 'PAID') {
      return res.status(400).json({
        success: false,
        code: 'ALREADY_PAID',
        error: 'This payment schedule has already been marked as PAID. Duplicate payment is blocked.',
      });
    }

    // Guard 2: Cancel any existing pending links for this schedule
    await cleanupPendingLinks({ scheduleId });

    const orderReceipt = `rcpt_${schedule.id.slice(0, 8)}_${Date.now()}`;
    const numAmount = amount || schedule.amount;
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // Exactly 10 minutes

    const order = await createRazorpayOrder(numAmount, orderReceipt, {
      scheduleId: schedule.id,
      memberId: memberId || schedule.memberId,
      expiresAt: expiresAt.toISOString(),
    });

    // Also record in PaymentLinkRecord for lifecycle tracking
    const record = await prisma.paymentLinkRecord.create({
      data: {
        linkId: order.id,
        shortUrl: `https://trackmyrent.app/pay/${schedule.id}`,
        type: 'RENT',
        scheduleId: schedule.id,
        memberId: memberId || schedule.memberId,
        amount: numAmount,
        currency: 'INR',
        status: 'PENDING',
        expiresAt,
      },
    });

    // Schedule 10-minute expiry worker
    await paymentExpiryQueue.add(
      'expire-order',
      { linkId: order.id, recordId: record.id },
      { delay: 10 * 60 * 1000 }
    );

    const { keyId } = await getRazorpayCredentials();

    res.status(200).json({
      success: true,
      message: 'Razorpay order created successfully (valid for 10 minutes)',
      keyId: keyId || process.env.RAZORPAY_KEY_ID,
      order,
      expiresAt: expiresAt.toISOString(),
      expiresInSeconds: 600,
      validityMinutes: 10,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

/**
 * Production Razorpay Signature Verification & Auto-Mark Paid
 * Validates that link is within 10 minutes and has not been used before
 */
export const verifyRazorpayPayment = async (req: Request, res: Response) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, scheduleId, paymentMethod = 'UPI' } = req.body;

    const isValid = await verifyRazorpaySignature(razorpay_order_id, razorpay_payment_id, razorpay_signature);

    if (!isValid) {
      return res.status(400).json({ success: false, error: 'Invalid Razorpay signature verification failed' });
    }

    const schedule = await prisma.paymentSchedule.findUnique({ where: { id: scheduleId } });
    if (!schedule) return res.status(404).json({ success: false, error: 'Schedule not found' });

    // Guard: Prevent double-marking if already paid
    if (schedule.status === 'PAID') {
      return res.status(400).json({
        success: false,
        code: 'ALREADY_PAID',
        error: 'This rent schedule has already been marked as PAID. Duplicate receipt generation blocked.',
      });
    }

    // Check payment link / order record for 10-minute expiration
    const record = await prisma.paymentLinkRecord.findFirst({
      where: {
        OR: [
          { linkId: razorpay_order_id },
          { scheduleId },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });

    if (record) {
      if (record.status === 'PAID' || record.paidAt) {
        return res.status(400).json({
          success: false,
          code: 'ALREADY_PAID',
          error: 'This payment order was already processed and completed.',
        });
      }

      if (record.status === 'EXPIRED' || Date.now() > record.expiresAt.getTime()) {
        if (record.status !== 'EXPIRED') {
          await prisma.paymentLinkRecord.update({
            where: { id: record.id },
            data: { status: 'EXPIRED', cancelledAt: new Date() },
          });
        }
        return res.status(410).json({
          success: false,
          code: 'LINK_EXPIRED',
          error: 'This payment order has expired (valid for 10 minutes only). Please request a fresh payment link.',
        });
      }

      // Mark record as PAID
      await prisma.paymentLinkRecord.update({
        where: { id: record.id },
        data: {
          status: 'PAID',
          paymentId: razorpay_payment_id,
          paidAt: new Date(),
        },
      });
    }

    const updatedSchedule = await prisma.paymentSchedule.update({
      where: { id: scheduleId },
      data: { status: 'PAID', notes: `Paid via Razorpay (${razorpay_payment_id})` },
    });

    const transaction = await prisma.transaction.create({
      data: {
        memberId: schedule.memberId,
        paymentScheduleId: schedule.id,
        amountPaid: schedule.amount,
        paymentMethod: paymentMethod === 'UPI' ? 'UPI' : 'BANK_TRANSFER',
        receiptUrl: `https://dashboard.razorpay.com/app/payments/${razorpay_payment_id}`,
        notes: `Razorpay Payment ID: ${razorpay_payment_id}`,
      },
    });

    res.status(200).json({
      success: true,
      message: 'Razorpay payment verified and marked as PAID successfully',
      schedule: updatedSchedule,
      transaction,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

/**
 * Create Razorpay Payment Link for Subscription Plan Purchase / Upgrade
 * strictly valid for 10 minutes, cancels old pending links
 */
export const createSubscriptionRazorpayOrder = async (req: Request, res: Response) => {
  try {
    const organizationId = req.body.organizationId || (req as any).user?.orgId || (req as any).user?.organizationId;
    const { planId, planName, amount, credits, phone, name } = req.body;

    if (!organizationId || !amount) {
      return res.status(400).json({ success: false, error: 'Organization ID and amount are required' });
    }

    const org = await prisma.organization.findUnique({ where: { id: organizationId } });
    if (!org) return res.status(404).json({ success: false, error: 'Organization not found' });

    // Cancel any previous pending links for this organization's subscription
    await cleanupPendingLinks({ organizationId, type: 'SUBSCRIPTION' });

    const numAmount = Number(amount);
    const expiresAt = new Date(Date.now() + 16 * 60 * 1000); // 16 minutes (meets Razorpay >= 15m minimum)

    const paymentLink = await createRazorpayPaymentLink({
      amountInRupees: numAmount,
      description: `RentTrack Subscription - ${planName || 'Plan'} (Valid 15 mins)`,
      customerName: name || org.name || 'Property Owner',
      customerPhone: phone || '9876543210',
      notes: {
        type: 'SUBSCRIPTION',
        organizationId,
        planId,
        planName,
        credits: String(credits || 0),
        expiresAt: expiresAt.toISOString(),
      },
    });

    // Record in database
    const record = await prisma.paymentLinkRecord.create({
      data: {
        linkId: paymentLink.id,
        shortUrl: paymentLink.short_url,
        type: 'SUBSCRIPTION',
        organizationId,
        planId,
        planName,
        credits: Number(credits) || 0,
        amount: numAmount,
        currency: 'INR',
        status: 'PENDING',
        expiresAt,
      },
    });

    // Schedule 16-minute expiry worker
    await paymentExpiryQueue.add(
      'expire-subscription-link',
      { linkId: paymentLink.id, recordId: record.id },
      { delay: 16 * 60 * 1000 }
    );

    const { keyId } = await getRazorpayCredentials();
    const appBase = process.env.APP_BASE_URL || 'https://trackmyrent.anandhu-kannan.in';

    res.status(200).json({
      success: true,
      message: 'Razorpay subscription payment link created (valid for 15 minutes)',
      keyId: keyId || process.env.RAZORPAY_KEY_ID,
      paymentLinkId: paymentLink.id,
      shortUrl: paymentLink.short_url,
      gatewayUrl: `${appBase}/api/payments/pay/${record.id}`,
      amount: numAmount,
      currency: 'INR',
      expiresAt: expiresAt.toISOString(),
      expiresInSeconds: 960,
      validityMinutes: 16,
    });
  } catch (error: any) {
    console.error('[createSubscriptionRazorpayOrder] ERROR:', error);
    res.status(500).json({
      success: false,
      error: error?.message || (error?.error?.description ? error.error.description : JSON.stringify(error)),
    });
  }
};

/**
 * Create Razorpay Payment Link for WhatsApp Credit Top-up
 * strictly valid for 16 minutes, cancels old pending links
 */
export const createCreditPackageRazorpayOrder = async (req: Request, res: Response) => {
  try {
    const organizationId = req.body.organizationId || (req as any).user?.orgId || (req as any).user?.organizationId;
    const { packageId, packageName, amount, credits, phone, name } = req.body;

    if (!organizationId || !amount || !credits) {
      return res.status(400).json({ success: false, error: 'Organization ID, amount, and credits are required' });
    }

    const org = await prisma.organization.findUnique({ where: { id: organizationId } });
    if (!org) return res.status(404).json({ success: false, error: 'Organization not found' });

    // Cancel any previous pending links for credit top-up
    await cleanupPendingLinks({ organizationId, type: 'CREDIT_TOPUP' });

    const numAmount = Number(amount);
    const numCredits = Number(credits);
    const expiresAt = new Date(Date.now() + 16 * 60 * 1000); // 16 minutes (meets Razorpay >= 15m minimum)

    const paymentLink = await createRazorpayPaymentLink({
      amountInRupees: numAmount,
      description: `RentTrack Top-up - ${packageName || `${numCredits} WhatsApp Credits`} (Valid 15 mins)`,
      customerName: name || org.name || 'Property Owner',
      customerPhone: phone || '9876543210',
      notes: {
        type: 'CREDIT_TOPUP',
        organizationId,
        packageId,
        packageName,
        credits: String(numCredits),
        expiresAt: expiresAt.toISOString(),
      },
    });

    // Record in database
    const record = await prisma.paymentLinkRecord.create({
      data: {
        linkId: paymentLink.id,
        shortUrl: paymentLink.short_url,
        type: 'CREDIT_TOPUP',
        organizationId,
        credits: numCredits,
        amount: numAmount,
        currency: 'INR',
        status: 'PENDING',
        expiresAt,
      },
    });

    // Schedule 16-minute expiry worker
    await paymentExpiryQueue.add(
      'expire-credit-link',
      { linkId: paymentLink.id, recordId: record.id },
      { delay: 16 * 60 * 1000 }
    );

    const { keyId } = await getRazorpayCredentials();
    const appBase = process.env.APP_BASE_URL || 'https://trackmyrent.anandhu-kannan.in';

    res.status(200).json({
      success: true,
      message: 'Razorpay credit package payment link created (valid for 15 minutes)',
      keyId: keyId || process.env.RAZORPAY_KEY_ID,
      paymentLinkId: paymentLink.id,
      shortUrl: paymentLink.short_url,
      gatewayUrl: `${appBase}/api/payments/pay/${record.id}`,
      amount: numAmount,
      credits: numCredits,
      currency: 'INR',
      expiresAt: expiresAt.toISOString(),
      expiresInSeconds: 960,
      validityMinutes: 16,
    });
  } catch (error: any) {
    console.error('[createCreditPackageRazorpayOrder] ERROR:', error);
    res.status(500).json({
      success: false,
      error: error?.message || (error?.error?.description ? error.error.description : JSON.stringify(error)),
    });
  }
};

/**
 * Verify Razorpay Subscription or Credit Top-up Payment & Credit Account
 * Enforces 10-minute validity and prevents reusing already-paid or expired links
 */
export const verifySubscriptionOrCreditPayment = async (req: Request, res: Response) => {
  try {
    const { organizationId, paymentId, paymentLinkId, type, planName, credits = 0 } = req.body;

    if (!organizationId) {
      return res.status(400).json({ success: false, error: 'organizationId is required' });
    }

    // 1. Check PaymentLinkRecord lifecycle
    let linkRecord = null;
    if (paymentLinkId) {
      linkRecord = await prisma.paymentLinkRecord.findFirst({
        where: {
          OR: [
            { linkId: paymentLinkId },
            { id: paymentLinkId },
          ],
        },
      });
    }

    if (linkRecord) {
      // Guard A: Check if already paid/used
      if (linkRecord.status === 'PAID' || linkRecord.paidAt) {
        return res.status(400).json({
          success: false,
          code: 'ALREADY_PAID',
          error: 'This payment link has already been used and processed. Duplicate activations are blocked.',
          data: {
            paymentId: linkRecord.paymentId,
            paidAt: linkRecord.paidAt,
          },
        });
      }

      // Guard B: Check if expired (> 10 minutes)
      const nowMs = Date.now();
      if (linkRecord.status === 'EXPIRED' || nowMs > linkRecord.expiresAt.getTime()) {
        if (linkRecord.status !== 'EXPIRED') {
          await cancelRazorpayPaymentLink(linkRecord.linkId);
          await prisma.paymentLinkRecord.update({
            where: { id: linkRecord.id },
            data: { status: 'EXPIRED', cancelledAt: new Date() },
          });
        }
        return res.status(410).json({
          success: false,
          code: 'LINK_EXPIRED',
          error: 'This payment link has expired. Payment links are valid for only 10 minutes. Please generate a fresh payment link.',
        });
      }

      // Guard C: Check if cancelled
      if (linkRecord.status === 'CANCELLED') {
        return res.status(400).json({
          success: false,
          code: 'LINK_CANCELLED',
          error: 'This payment link was superseded by a newer link and cancelled. Please generate or use the latest link.',
        });
      }
    }

    // 2. Strict Verification with Razorpay API (prevent false activations on decline)
    let verifiedPaymentId = paymentId;
    let isCaptured = false;

    if (verifiedPaymentId) {
      try {
        const payment = await fetchPaymentDetails(verifiedPaymentId);
        isCaptured = payment.status === 'captured' || payment.status === 'authorized';
      } catch (err: any) {
        console.warn('[PaymentController] Live Razorpay fetch warning:', err.message);
        const { keyId, keySecret } = await getRazorpayCredentials();
        if (process.env.NODE_ENV !== 'production' && (!keyId || !keySecret)) {
          isCaptured = true;
        }
      }
    } else if (linkRecord && linkRecord.linkId) {
      try {
        const linkData = await fetchRazorpayPaymentLink(linkRecord.linkId);
        if (linkData && linkData.status === 'paid') {
          isCaptured = true;
          verifiedPaymentId = (linkData as any).payments?.[0]?.payment_id || `plink_paid_${Date.now()}`;
        }
      } catch (err: any) {
        console.warn('[PaymentController] Live Razorpay link fetch warning:', err.message);
      }
    }

    if (!isCaptured) {
      return res.status(400).json({
        success: false,
        code: 'PAYMENT_NOT_CAPTURED',
        error: 'Payment was not captured or was declined. Subscription cannot be activated without confirmed payment.',
      });
    }

    // 3. Mark link as PAID in database
    if (linkRecord) {
      await prisma.paymentLinkRecord.update({
        where: { id: linkRecord.id },
        data: {
          status: 'PAID',
          paymentId: verifiedPaymentId,
          paidAt: new Date(),
        },
      });
    }

    const numCredits = Number(credits);

    if (type === 'SUBSCRIPTION') {
      const updated = await prisma.subscriptionCredit.upsert({
        where: { organizationId },
        update: {
          planType: 'CREDIT',
          subscriptionName: planName || 'Pro Plan',
          purchasedCredits: { increment: numCredits },
          expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days active
        },
        create: {
          organizationId,
          planType: 'CREDIT',
          subscriptionName: planName || 'Pro Plan',
          purchasedCredits: numCredits > 0 ? numCredits : 100,
          expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        },
      });

      return res.status(200).json({
        success: true,
        message: `Subscription to ${planName} activated successfully! ${numCredits} credits added.`,
        data: updated,
      });
    } else {
      const updated = await prisma.subscriptionCredit.upsert({
        where: { organizationId },
        update: {
          purchasedCredits: { increment: numCredits },
        },
        create: {
          organizationId,
          planType: 'CREDIT',
          subscriptionName: 'Standard',
          purchasedCredits: numCredits,
          expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
        },
      });

      return res.status(200).json({
        success: true,
        message: `${numCredits} credits added successfully!`,
        data: updated,
      });
    }
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

/**
 * Check Payment Link Status (Live 10-Minute Validity & Usage Check)
 */
export const getPaymentLinkStatus = async (req: Request, res: Response) => {
  try {
    const { linkId } = req.params;

    const record = await prisma.paymentLinkRecord.findFirst({
      where: {
        OR: [
          { linkId },
          { id: linkId },
        ],
      },
    });

    if (!record) {
      return res.status(404).json({ success: false, error: 'Payment link record not found' });
    }

    const now = Date.now();
    const remainingMs = record.expiresAt.getTime() - now;
    const remainingSeconds = Math.max(0, Math.floor(remainingMs / 1000));
    const isExpired = record.status === 'EXPIRED' || remainingMs <= 0;
    const isPaid = record.status === 'PAID';

    // Auto-update expired status in DB if past 10 minutes
    if (isExpired && record.status === 'PENDING') {
      await cancelRazorpayPaymentLink(record.linkId);
      await prisma.paymentLinkRecord.update({
        where: { id: record.id },
        data: { status: 'EXPIRED', cancelledAt: new Date() },
      });
    }

    return res.status(200).json({
      success: true,
      linkId: record.linkId,
      status: isPaid ? 'PAID' : isExpired ? 'EXPIRED' : record.status,
      isPaid,
      isExpired,
      remainingSeconds,
      validityMinutes: 10,
      amount: record.amount,
      currency: record.currency,
      type: record.type,
      shortUrl: record.shortUrl,
      expiresAt: record.expiresAt.toISOString(),
      paidAt: record.paidAt ? record.paidAt.toISOString() : null,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

/**
 * Public Hosted Payment Gateway / Redirect Handler
 * Validates 10-minute expiry and prevents reusing expired/paid links
 */
export const renderHostedPaymentGateway = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const record = await prisma.paymentLinkRecord.findFirst({
      where: {
        OR: [
          { linkId: id },
          { id },
          { scheduleId: id },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!record) {
      // Check if id is a Member renewal link (/pay/renew/:memberId or just memberId)
      let targetScheduleId = id;
      if (id.startsWith('renew/')) {
        const memberId = id.replace('renew/', '');
        const activeSchedule = await prisma.paymentSchedule.findFirst({
          where: { memberId, status: 'UNPAID' },
          orderBy: { dueDate: 'asc' },
        });
        if (activeSchedule) {
          targetScheduleId = activeSchedule.id;
        }
      }

      // Check if id corresponds directly to a Member's PaymentSchedule
      const schedule = await prisma.paymentSchedule.findUnique({
        where: { id: targetScheduleId },
        include: {
          member: {
            include: {
              organization: true,
              plan: true,
            },
          },
        },
      });

      if (schedule) {
        const member = schedule.member;
        const org = member.organization;
        const formattedAmount = Number(schedule.amount).toLocaleString('en-IN');
        const dueDateFormatted = new Date(schedule.dueDate).toLocaleDateString('en-IN', {
          day: '2-digit',
          month: 'short',
          year: 'numeric',
        });

        if (schedule.status === 'PAID') {
          return res.status(200).send(`
            <!DOCTYPE html>
            <html>
            <head>
              <title>Payment Completed - TrackMyRent</title>
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0B141A; color: #E9EDEF; margin:0; padding:20px; display:flex; justify-content:center; align-items:center; min-height:100vh; }
                .card { background: #111B21; border: 1px solid #222E35; border-radius: 24px; max-width: 420px; width: 100%; padding: 32px 24px; text-align: center; box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
                .badge { width: 64px; height: 64px; border-radius: 50%; background: rgba(0, 168, 132, 0.15); color: #00A884; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; font-size: 28px; }
              </style>
            </head>
            <body>
              <div class="card">
                <div class="badge">✓</div>
                <h2 style="margin: 0 0 8px; color: #E9EDEF;">Payment Already Settled</h2>
                <p style="color: #8696A0; font-size: 14px; margin: 0 0 24px;">The fee of <strong style="color:#00A884;">₹${formattedAmount}</strong> for ${schedule.monthYear || 'this month'} has already been paid to <strong>${org.name}</strong>.</p>
                <div style="background: #202C33; border-radius: 12px; padding: 14px; font-size: 13px; color: #8696A0;">
                  Member: <strong style="color:#E9EDEF;">${member.fullName}</strong>
                </div>
              </div>
            </body>
            </html>
          `);
        }

        const upiId = org.bankUpiId;
        const payeeName = org.bankAccountName || org.name;
        const note = `Rent ${schedule.monthYear || ''} - ${member.fullName}`;
        const directUpiUrl = upiId
          ? `upi://pay?pa=${encodeURIComponent(upiId)}&pn=${encodeURIComponent(payeeName)}&am=${schedule.amount}&cu=INR&tn=${encodeURIComponent(note)}`
          : '';
        const qrUrl = directUpiUrl
          ? `https://api.qrserver.com/v1/create-qr-code/?size=260x260&data=${encodeURIComponent(directUpiUrl)}`
          : '';

        // Format masked account number for privacy/security (e.g. •••• 1073)
        const maskedAccountNo = org.bankAccountNumber && org.bankAccountNumber.length > 4
          ? `•••• •••• ${org.bankAccountNumber.slice(-4)}`
          : (org.bankAccountNumber || '');

        return res.status(200).send(`
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="utf-8">
            <title>Pay ${org.name} • ₹${formattedAmount}</title>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
            <link rel="preconnect" href="https://fonts.googleapis.com">
            <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
            <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
            <style>
              :root {
                --bg: #090B0E;
                --surface: rgba(18, 22, 28, 0.75);
                --surface-hover: rgba(26, 32, 40, 0.85);
                --border: rgba(255, 255, 255, 0.08);
                --text-primary: #FFFFFF;
                --text-secondary: #94A3B8;
                --text-muted: #64748B;
                --accent: #10B981;
                --accent-hover: #059669;
                --accent-glow: rgba(16, 185, 129, 0.25);
              }
              * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
              body {
                font-family: -apple-system, BlinkMacSystemFont, "Plus Jakarta Sans", "SF Pro Display", "Segoe UI", Roboto, sans-serif;
                background-color: var(--bg);
                background-image: 
                  radial-gradient(at 50% 0%, rgba(16, 185, 129, 0.12) 0px, transparent 50%),
                  radial-gradient(at 100% 100%, rgba(14, 165, 233, 0.06) 0px, transparent 40%);
                color: var(--text-primary);
                margin: 0;
                padding: 24px 16px;
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                min-height: 100vh;
                letter-spacing: -0.01em;
              }
              .wrapper {
                max-width: 410px;
                width: 100%;
                margin: 0 auto;
              }
              .card {
                background: var(--surface);
                backdrop-filter: blur(24px);
                -webkit-backdrop-filter: blur(24px);
                border: 1px solid var(--border);
                border-radius: 28px;
                padding: 32px 24px 28px;
                box-shadow: 0 24px 60px -12px rgba(0, 0, 0, 0.7), inset 0 1px 0 rgba(255, 255, 255, 0.06);
              }
              .brand-header {
                display: flex;
                align-items: center;
                justify-content: space-between;
                margin-bottom: 24px;
              }
              .brand-badge {
                display: inline-flex;
                align-items: center;
                gap: 6px;
                padding: 4px 10px;
                border-radius: 20px;
                background: rgba(16, 185, 129, 0.1);
                border: 1px solid rgba(16, 185, 129, 0.2);
                color: var(--accent);
                font-size: 11px;
                font-weight: 600;
                letter-spacing: 0.02em;
              }
              .brand-badge .pulse {
                width: 6px;
                height: 6px;
                border-radius: 50%;
                background: var(--accent);
                box-shadow: 0 0 8px var(--accent);
              }
              .org-name {
                font-size: 14px;
                font-weight: 600;
                color: var(--text-secondary);
                margin: 0;
                white-space: nowrap;
                overflow: hidden;
                text-overflow: ellipsis;
                max-width: 220px;
              }
              
              /* Amount Showcase */
              .amount-container {
                text-align: center;
                padding: 8px 0 24px;
              }
              .amount-tag {
                font-size: 11px;
                font-weight: 700;
                text-transform: uppercase;
                letter-spacing: 0.1em;
                color: var(--text-muted);
                margin-bottom: 6px;
              }
              .amount-display {
                font-size: 44px;
                font-weight: 800;
                color: #FFFFFF;
                line-height: 1;
                letter-spacing: -0.03em;
                margin-bottom: 10px;
              }
              .amount-display span {
                font-size: 32px;
                font-weight: 600;
                color: var(--text-secondary);
                margin-right: 2px;
              }
              .member-subtitle {
                display: inline-flex;
                align-items: center;
                gap: 6px;
                background: rgba(255, 255, 255, 0.03);
                border: 1px solid var(--border);
                border-radius: 20px;
                padding: 5px 12px;
                font-size: 12px;
                color: var(--text-secondary);
              }
              .member-subtitle strong {
                color: #FFFFFF;
              }
              
              /* Primary Action Button */
              .action-primary {
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 10px;
                width: 100%;
                background: linear-gradient(180deg, #10B981 0%, #059669 100%);
                color: #041E15;
                font-size: 16px;
                font-weight: 700;
                text-decoration: none;
                padding: 16px 20px;
                border-radius: 18px;
                box-shadow: 0 10px 25px -4px var(--accent-glow);
                transition: transform 0.12s ease, box-shadow 0.15s ease, opacity 0.15s ease;
                border: none;
                cursor: pointer;
                margin-bottom: 12px;
              }
              .action-primary:active {
                transform: scale(0.98);
                opacity: 0.95;
              }
              .action-primary svg {
                width: 18px;
                height: 18px;
                fill: currentColor;
              }

              /* Secondary Card Row (UPI copy) */
              .upi-row {
                background: rgba(255, 255, 255, 0.02);
                border: 1px solid var(--border);
                border-radius: 16px;
                padding: 10px 14px;
                display: flex;
                align-items: center;
                justify-content: space-between;
                margin-bottom: 16px;
                transition: background 0.15s ease;
              }
              .upi-info {
                display: flex;
                flex-direction: column;
                min-width: 0;
              }
              .upi-title {
                font-size: 10px;
                font-weight: 600;
                text-transform: uppercase;
                letter-spacing: 0.06em;
                color: var(--text-muted);
              }
              .upi-vpa {
                font-size: 13px;
                font-weight: 600;
                color: var(--text-primary);
                overflow: hidden;
                text-overflow: ellipsis;
                white-space: nowrap;
              }
              .btn-chip {
                background: rgba(255, 255, 255, 0.06);
                border: 1px solid rgba(255, 255, 255, 0.08);
                color: #FFFFFF;
                font-size: 11px;
                font-weight: 600;
                padding: 6px 12px;
                border-radius: 10px;
                cursor: pointer;
                transition: all 0.15s ease;
                flex-shrink: 0;
              }
              .btn-chip:hover {
                background: rgba(255, 255, 255, 0.1);
              }
              .btn-chip:active {
                transform: scale(0.96);
              }

              /* Collapsible Section Toggles */
              .toggle-row {
                display: flex;
                gap: 8px;
                margin-bottom: 16px;
              }
              .btn-toggle {
                flex: 1;
                background: transparent;
                border: 1px solid var(--border);
                border-radius: 12px;
                padding: 9px 12px;
                font-size: 12px;
                font-weight: 600;
                color: var(--text-secondary);
                cursor: pointer;
                transition: all 0.15s ease;
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 6px;
              }
              .btn-toggle:hover {
                background: rgba(255, 255, 255, 0.03);
                color: var(--text-primary);
              }
              .btn-toggle.active {
                background: rgba(16, 185, 129, 0.08);
                border-color: rgba(16, 185, 129, 0.3);
                color: var(--accent);
              }

              /* QR Container Modal/Drawer */
              .drawer {
                display: none;
                animation: slideDown 0.2s cubic-bezier(0.16, 1, 0.3, 1);
                margin-bottom: 16px;
              }
              @keyframes slideDown {
                from { opacity: 0; transform: translateY(-8px); }
                to { opacity: 1; transform: translateY(0); }
              }
              .qr-card {
                background: #FFFFFF;
                border-radius: 20px;
                padding: 20px;
                text-align: center;
                box-shadow: 0 10px 30px rgba(0,0,0,0.4);
                max-width: 250px;
                margin: 0 auto;
              }
              .qr-card img {
                display: block;
                margin: 0 auto;
                border-radius: 10px;
              }
              .qr-hint {
                font-size: 11px;
                color: #0F172A;
                font-weight: 700;
                margin-top: 10px;
              }

              /* Masked / Protected Bank Details Accordion */
              .secure-bank-box {
                background: rgba(255, 255, 255, 0.02);
                border: 1px solid var(--border);
                border-radius: 16px;
                padding: 14px 16px;
                font-size: 12px;
              }
              .secure-bank-title {
                display: flex;
                justify-content: space-between;
                align-items: center;
                color: var(--text-muted);
                font-size: 11px;
                font-weight: 700;
                text-transform: uppercase;
                letter-spacing: 0.05em;
                margin-bottom: 10px;
              }
              .secure-badge {
                display: inline-flex;
                align-items: center;
                gap: 4px;
                color: var(--accent);
                font-size: 10px;
              }
              .bank-detail-item {
                display: flex;
                justify-content: space-between;
                padding: 4px 0;
                font-size: 12px;
                color: var(--text-secondary);
              }
              .bank-detail-item span {
                color: var(--text-muted);
              }
              .bank-detail-item strong {
                color: var(--text-primary);
                font-weight: 600;
                font-family: -apple-system, monospace;
                letter-spacing: 0.02em;
              }

              /* UTR Confirmation Box - Minimalist Input */
              .utr-box {
                background: rgba(255, 255, 255, 0.02);
                border: 1px solid var(--border);
                border-radius: 18px;
                padding: 16px;
                margin-top: 16px;
              }
              .utr-header {
                display: flex;
                align-items: center;
                justify-content: space-between;
                margin-bottom: 10px;
              }
              .utr-title {
                font-size: 12px;
                font-weight: 700;
                color: var(--text-primary);
              }
              .utr-subtitle {
                font-size: 11px;
                color: var(--text-muted);
                line-height: 1.4;
                margin-bottom: 12px;
              }
              .utr-input-group {
                display: flex;
                gap: 8px;
              }
              .utr-field {
                flex: 1;
                background: rgba(0, 0, 0, 0.35);
                border: 1px solid var(--border);
                border-radius: 12px;
                padding: 11px 14px;
                font-size: 13px;
                color: #FFFFFF;
                font-family: -apple-system, monospace;
                letter-spacing: 0.05em;
                outline: none;
                transition: border-color 0.15s ease;
              }
              .utr-field:focus {
                border-color: var(--accent);
              }
              .btn-submit-utr {
                background: #FFFFFF;
                color: #090B0E;
                border: none;
                border-radius: 12px;
                padding: 0 16px;
                font-size: 13px;
                font-weight: 700;
                cursor: pointer;
                transition: all 0.15s ease;
              }
              .btn-submit-utr:hover {
                background: #E2E8F0;
              }
              .btn-submit-utr:active {
                transform: scale(0.96);
              }
              .utr-feedback {
                font-size: 11px;
                margin-top: 10px;
                display: none;
                padding: 8px 12px;
                border-radius: 10px;
              }

              /* Footer */
              .footer {
                text-align: center;
                font-size: 11px;
                color: var(--text-muted);
                margin-top: 24px;
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 8px;
              }
              .footer svg {
                width: 12px;
                height: 12px;
                fill: var(--accent);
              }
            </style>
          </head>
          <body>
            <div class="wrapper">
              <div class="card">
                <!-- Brand Bar -->
                <div class="brand-header">
                  <div class="org-name">${org.name}</div>
                  <div class="brand-badge">
                    <span class="pulse"></span>
                    Verified Direct P2P
                  </div>
                </div>

                <!-- Due Amount Hero -->
                <div class="amount-container">
                  <div class="amount-tag">Payment Due</div>
                  <div class="amount-display"><span>₹</span>${formattedAmount}</div>
                  <div class="member-subtitle">
                    Payer: <strong>${member.fullName}</strong> • Due: ${dueDateFormatted}
                  </div>
                </div>

                ${upiId ? `
                  <!-- Main Native UPI Pay Button -->
                  <a href="${directUpiUrl}" class="action-primary" id="payBtn">
                    <svg viewBox="0 0 24 24"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
                    <span>Pay ₹${formattedAmount} via UPI</span>
                  </a>

                  <!-- Landlord UPI ID Chip with Copy -->
                  <div class="upi-row">
                    <div class="upi-info">
                      <span class="upi-title">Landlord VPA</span>
                      <span class="upi-vpa" id="upiText">${upiId}</span>
                    </div>
                    <button class="btn-chip" onclick="copyUpi()">Copy</button>
                  </div>

                  <!-- Segmented Controls for QR & Direct Details -->
                  <div class="toggle-row">
                    <button class="btn-toggle" onclick="toggleDrawer('qrContainer', this)">
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
                      <span>Show QR Code</span>
                    </button>
                    ${org.bankAccountNumber ? `
                      <button class="btn-toggle" onclick="toggleDrawer('bankContainer', this)">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 21h18M3 10h18M5 6l7-3 7 3M4 10v11M20 10v11M8 14v4M12 14v4M16 14v4"/></svg>
                        <span>Bank Details</span>
                      </button>
                    ` : ''}
                  </div>

                  <!-- Collapsible QR Code -->
                  <div class="drawer" id="qrContainer">
                    <div class="qr-card">
                      <img src="${qrUrl}" width="200" height="200" alt="UPI QR" />
                      <div class="qr-hint">Scan with GPay, PhonePe, Paytm, or BHIM</div>
                    </div>
                  </div>

                  <!-- Collapsible Protected Bank Details -->
                  ${org.bankAccountNumber ? `
                    <div class="drawer" id="bankContainer">
                      <div class="secure-bank-box">
                        <div class="secure-bank-title">
                          <span>Bank Account (IMPS / NEFT)</span>
                          <span class="secure-badge">
                            <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>
                            Direct Settlement
                          </span>
                        </div>
                        <div class="bank-detail-item">
                          <span>Beneficiary</span>
                          <strong>${org.bankAccountName || org.name}</strong>
                        </div>
                        <div class="bank-detail-item">
                          <span>Account Number</span>
                          <strong>${maskedAccountNo}</strong>
                        </div>
                        <div class="bank-detail-item">
                          <span>IFSC Code</span>
                          <strong>${org.bankIfsc || 'N/A'}</strong>
                        </div>
                      </div>
                    </div>
                  ` : ''}

                  <!-- UTR Confirmation Box -->
                  <div class="utr-box">
                    <div class="utr-header">
                      <span class="utr-title">Confirm Transfer</span>
                      <span style="font-size: 10px; color: var(--accent); font-weight:600;">Instant Status</span>
                    </div>
                    <div class="utr-subtitle">
                      Paid already? Enter the 12-digit UTR / Reference ID from your UPI receipt to automatically confirm your rent schedule.
                    </div>
                    <div class="utr-input-group">
                      <input type="text" id="utrInput" placeholder="12-digit UPI UTR" maxlength="22" class="utr-field" />
                      <button onclick="submitUtr('${schedule.id}')" id="utrBtn" class="btn-submit-utr">Confirm</button>
                    </div>
                    <div id="utrMsg" class="utr-feedback"></div>
                  </div>
                ` : `
                  <div style="background: rgba(255,255,255,0.03); border: 1px solid var(--border); padding: 20px; border-radius: 16px; text-align: center; color: var(--text-secondary); font-size: 13px;">
                    Please contact <strong>${org.name}</strong> to configure payout credentials.
                  </div>
                `}
              </div>

              <!-- Minimal Footer -->
              <div class="footer">
                <svg viewBox="0 0 24 24"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"/></svg>
                <span>Direct P2P Settlement • Powered by TrackMyRent</span>
              </div>
            </div>

            <script>
              function copyUpi() {
                const text = document.getElementById('upiText').innerText.trim();
                navigator.clipboard.writeText(text).then(() => {
                  const btn = event.target;
                  const original = btn.innerText;
                  btn.innerText = 'Copied!';
                  btn.style.color = '#10B981';
                  setTimeout(() => {
                    btn.innerText = original;
                    btn.style.color = '';
                  }, 2000);
                });
              }

              function toggleDrawer(id, btn) {
                const el = document.getElementById(id);
                if (!el) return;
                const isShown = el.style.display === 'block';
                
                // Hide other drawers first for clean view
                ['qrContainer', 'bankContainer'].forEach(dId => {
                  const d = document.getElementById(dId);
                  if (d) d.style.display = 'none';
                });
                document.querySelectorAll('.btn-toggle').forEach(b => b.classList.remove('active'));

                if (!isShown) {
                  el.style.display = 'block';
                  btn.classList.add('active');
                }
              }

              async function submitUtr(scheduleId) {
                const input = document.getElementById('utrInput');
                const utr = input.value.trim();
                const msg = document.getElementById('utrMsg');
                const btn = document.getElementById('utrBtn');
                
                if (!utr || utr.length < 6) {
                  msg.style.display = 'block';
                  msg.style.background = 'rgba(239, 68, 68, 0.1)';
                  msg.style.border = '1px solid rgba(239, 68, 68, 0.2)';
                  msg.style.color = '#F87171';
                  msg.innerText = 'Please enter a valid 12-digit UTR reference.';
                  return;
                }

                btn.disabled = true;
                btn.innerText = 'Verifying...';

                try {
                  const res = await fetch('/api/payments/submit-utr', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ scheduleId, utrNumber: utr })
                  });
                  const data = await res.json();
                  msg.style.display = 'block';
                  if (data.success) {
                    msg.style.background = 'rgba(16, 185, 129, 0.1)';
                    msg.style.border = '1px solid rgba(16, 185, 129, 0.2)';
                    msg.style.color = '#34D399';
                    msg.innerText = '✓ Reference recorded. Landlord will verify and issue receipt.';
                    input.disabled = true;
                    btn.style.display = 'none';
                  } else {
                    msg.style.background = 'rgba(239, 68, 68, 0.1)';
                    msg.style.border = '1px solid rgba(239, 68, 68, 0.2)';
                    msg.style.color = '#F87171';
                    msg.innerText = data.error || 'Failed to submit. Please try again.';
                    btn.disabled = false;
                    btn.innerText = 'Confirm';
                  }
                } catch(e) {
                  msg.style.display = 'block';
                  msg.style.background = 'rgba(239, 68, 68, 0.1)';
                  msg.style.color = '#F87171';
                  msg.innerText = 'Network error. Please try again.';
                  btn.disabled = false;
                  btn.innerText = 'Confirm';
                }
              }
            </script>
          </body>
          </html>
        `);
      }

      return res.status(404).send(`
        <!DOCTYPE html>
        <html>
        <head><title>Payment Not Found - TrackMyRent</title><meta name="viewport" content="width=device-width, initial-scale=1"></head>
        <body style="font-family: system-ui, -apple-system, sans-serif; display:flex; justify-content:center; align-items:center; min-height:100vh; background:#F8FAFC; margin:0; padding:20px;">
          <div style="background:white; max-width:440px; width:100%; border-radius:24px; padding:36px; text-align:center; box-shadow:0 10px 25px -5px rgba(0,0,0,0.05); border:1px solid #E2E8F0;">
            <div style="width:64px; height:64px; border-radius:20px; background:#FEF2F2; color:#EF4444; display:flex; align-items:center; justify-content:center; margin:0 auto 20px; font-size:28px;">✕</div>
            <h2 style="color:#0F172A; margin:0 0 8px; font-size:20px;">Payment Link Not Found</h2>
            <p style="color:#64748B; font-size:14px; line-height:1.5;">This payment link does not exist or has been removed.</p>
          </div>
        </body>
        </html>
      `);
    }

    // Check if ALREADY PAID
    if (record.status === 'PAID' || record.paidAt) {
      const paidDate = record.paidAt ? new Date(record.paidAt).toLocaleString('en-IN') : 'Recently';
      return res.status(200).send(`
        <!DOCTYPE html>
        <html>
        <head><title>Payment Completed - TrackMyRent</title><meta name="viewport" content="width=device-width, initial-scale=1"></head>
        <body style="font-family: system-ui, -apple-system, sans-serif; display:flex; justify-content:center; align-items:center; min-height:100vh; background:#F8FAFC; margin:0; padding:20px;">
          <div style="background:white; max-width:440px; width:100%; border-radius:24px; padding:36px; text-align:center; box-shadow:0 10px 25px -5px rgba(0,0,0,0.05); border:1px solid #E2E8F0;">
            <div style="width:64px; height:64px; border-radius:20px; background:#ECFDF5; color:#10B981; display:flex; align-items:center; justify-content:center; margin:0 auto 20px; font-size:28px;">✓</div>
            <h2 style="color:#0F172A; margin:0 0 8px; font-size:20px;">Payment Already Completed</h2>
            <p style="color:#64748B; font-size:14px; line-height:1.5; margin-bottom:20px;">This invoice of <strong>₹${record.amount}</strong> was successfully paid on ${paidDate}. Duplicate payments are blocked for your safety.</p>
            <div style="background:#F1F5F9; border-radius:12px; padding:12px; font-size:12px; color:#475569; word-break:break-all;">
              Transaction ID: ${record.paymentId || record.linkId}
            </div>
          </div>
        </body>
        </html>
      `);
    }

    // Check if EXPIRED (> 10 minutes)
    const now = Date.now();
    if (record.status === 'EXPIRED' || now > record.expiresAt.getTime()) {
      if (record.status !== 'EXPIRED') {
        await cancelRazorpayPaymentLink(record.linkId);
        await prisma.paymentLinkRecord.update({
          where: { id: record.id },
          data: { status: 'EXPIRED', cancelledAt: new Date() },
        });
      }

      return res.status(410).send(`
        <!DOCTYPE html>
        <html>
        <head><title>Payment Link Expired - TrackMyRent</title><meta name="viewport" content="width=device-width, initial-scale=1"></head>
        <body style="font-family: system-ui, -apple-system, sans-serif; display:flex; justify-content:center; align-items:center; min-height:100vh; background:#F8FAFC; margin:0; padding:20px;">
          <div style="background:white; max-width:440px; width:100%; border-radius:24px; padding:36px; text-align:center; box-shadow:0 10px 25px -5px rgba(0,0,0,0.05); border:1px solid #E2E8F0;">
            <div style="width:64px; height:64px; border-radius:20px; background:#FFFBEB; color:#D97706; display:flex; align-items:center; justify-content:center; margin:0 auto 20px; font-size:28px;">⏱</div>
            <h2 style="color:#0F172A; margin:0 0 8px; font-size:20px;">Payment Link Expired</h2>
            <p style="color:#64748B; font-size:14px; line-height:1.5; margin-bottom:20px;">
              For security, Razorpay payment links are valid for <strong>10 minutes only</strong>. This link has expired and cannot be processed.
            </p>
            <div style="background:#FEF3C7; color:#92400E; border-radius:12px; padding:12px; font-size:13px; font-weight:600; margin-bottom:24px;">
              Expired at ${new Date(record.expiresAt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}
            </div>
            <p style="color:#94A3B8; font-size:12px;">Please return to the TrackMyRent app to generate a fresh payment link.</p>
          </div>
        </body>
        </html>
      `);
    }

    // Valid and within 10 minutes -> Redirect directly to Razorpay checkout!
    if (record.shortUrl && record.shortUrl.startsWith('http') && !record.shortUrl.includes('trackmyrent.app/pay')) {
      return res.redirect(record.shortUrl);
    }

    // BUG-FIX HIGH-07: If shortUrl is a placeholder (rent orders use Order API not Payment Links),
    // show a proper error page instead of silently redirecting to Razorpay dashboard
    return res.status(400).send(`
      <!DOCTYPE html>
      <html>
      <head><title>Payment Unavailable - TrackMyRent</title><meta name="viewport" content="width=device-width, initial-scale=1"></head>
      <body style="font-family: system-ui, -apple-system, sans-serif; display:flex; justify-content:center; align-items:center; min-height:100vh; background:#F8FAFC; margin:0; padding:20px;">
        <div style="background:white; max-width:440px; width:100%; border-radius:24px; padding:36px; text-align:center; box-shadow:0 10px 25px -5px rgba(0,0,0,0.05); border:1px solid #E2E8F0;">
          <div style="width:64px; height:64px; border-radius:20px; background:#FFF7ED; color:#F59E0B; display:flex; align-items:center; justify-content:center; margin:0 auto 20px; font-size:28px;">⚠</div>
          <h2 style="color:#0F172A; margin:0 0 8px; font-size:20px;">Payment Link Unavailable</h2>
          <p style="color:#64748B; font-size:14px; line-height:1.5;">This payment requires the TrackMyRent app to complete. Please return to the app and use the in-app payment screen to proceed.</p>
        </div>
      </body>
      </html>
    `);
  } catch (error) {
    res.status(500).send(`Error processing payment link: ${(error as Error).message}`);
  }
};

/**
 * Get all payment transactions with filters
 * BUG-FIX HIGH-02: organizationId filter is now applied to the query
 */
export const getTransactions = async (req: Request, res: Response) => {
  try {
    const { organizationId, filter } = req.query;

    const transactions = await prisma.transaction.findMany({
      where: organizationId
        ? {
            member: {
              organizationId: organizationId as string,
            },
          }
        : undefined,
      include: {
        member: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            plan: { select: { name: true, price: true } },
            group: { select: { name: true } },
          },
        },
        paymentSchedule: true,
      },
      orderBy: { paymentDate: 'desc' },
    });

    return res.json({ transactions });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Get all payment schedules for a member (Paid, Unpaid, Frozen)
 */
export const getMemberSchedules = async (req: Request, res: Response) => {
  try {
    const { memberId } = req.params;

    const schedules = await prisma.paymentSchedule.findMany({
      where: { memberId },
      orderBy: { dueDate: 'desc' },
      include: {
        transactions: {
          orderBy: { paymentDate: 'desc' },
        },
      },
    });

    const paidSchedules = schedules.filter((s) => s.status === 'PAID');
    const unpaidSchedules = schedules.filter((s) => s.status === 'UNPAID');
    const frozenSchedules = schedules.filter((s) => s.status === 'FROZEN');

    const totalPendingAmount = unpaidSchedules.reduce((sum, s) => sum + s.amount, 0);

    return res.json({
      memberId,
      schedules,
      paidSchedules,
      unpaidSchedules,
      frozenSchedules,
      totalPendingAmount,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Send WhatsApp Payment Reminder with Direct Tenant Payout Link (UPI / Razorpay)
 * Deducts 1 credit from Tenant's balance. If credits = 0, falls back to direct WhatsApp opening.
 */
export const sendPaymentReminder = async (req: Request, res: Response) => {
  try {
    const { scheduleId, memberId } = req.body;

    if (!scheduleId && !memberId) {
      return res.status(400).json({ success: false, error: 'scheduleId or memberId is required' });
    }

    let schedule = null;
    if (scheduleId) {
      schedule = await prisma.paymentSchedule.findUnique({
        where: { id: scheduleId },
        include: {
          member: {
            include: { organization: true, plan: true },
          },
        },
      });
    } else if (memberId) {
      schedule = await prisma.paymentSchedule.findFirst({
        where: { memberId, status: 'UNPAID' },
        include: {
          member: {
            include: { organization: true, plan: true },
          },
        },
        orderBy: { dueDate: 'asc' },
      });
    }

    if (!schedule || !schedule.member) {
      return res.status(404).json({ success: false, error: 'Payment schedule or member not found' });
    }

    const member = schedule.member;
    const org = member.organization;

    // 1. Credit balance deduction check
    const subCredit = await prisma.subscriptionCredit.findUnique({
      where: { organizationId: org.id },
    });

    let creditDeducted = false;
    let remainingCredits = 0;

    // BUG-FIX HIGH-06: Also check subscription expiry before deducting credit
    const now = new Date();
    if (subCredit) {
      const isExpired = subCredit.expiresAt && subCredit.expiresAt < now;
      const available = subCredit.purchasedCredits - subCredit.usedCredits;
      if (!isExpired && available > 0) {
        const updated = await prisma.subscriptionCredit.update({
          where: { organizationId: org.id },
          data: { usedCredits: subCredit.usedCredits + 1 },
        });
        creditDeducted = true;
        remainingCredits = updated.purchasedCredits - updated.usedCredits;
      } else {
        remainingCredits = 0;
      }
    }

    // 2. Construct Direct Tenant Payout Link (Hosted Gateway with UPI Intent, QR, and Bank Details)
    const backendBase = process.env.BACKEND_PUBLIC_URL || 'https://trackmyrent.anandhu-kannan.in';
    const paymentLink = `${backendBase}/pay/${schedule.id}`;

    // 3. Fetch WhatsApp template or use standard format
    const template = await prisma.whatsAppTemplate.findFirst({
      where: {
        OR: [
          { organizationId: org.id, templateType: 'RENT_REMINDER' },
          { organizationId: null, templateType: 'RENT_REMINDER' },
        ],
      },
      orderBy: { organizationId: 'desc' },
    });

    const dueDateFormatted = new Date(schedule.dueDate).toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    });

    // BUG-FIX MED-01: Template variable order aligned with Meta-approved template
    // Template: rent_due_reminder
    // {{1}}=name, {{2}}=billingMonth, {{3}}=amount, {{4}}=dueDate, {{5}}=paymentLink
    let messageBody = '';
    if (template && template.messageText) {
      messageBody = template.messageText
        .replace(/\{\{1\}\}/g, member.fullName)          // name
        .replace(/\{\{2\}\}/g, schedule.monthYear || 'Current Month')  // billingMonth
        .replace(/\{\{3\}\}/g, String(schedule.amount))  // amount
        .replace(/\{\{4\}\}/g, dueDateFormatted)          // dueDate
        .replace(/\{\{5\}\}/g, paymentLink);              // paymentLink
    } else {
      messageBody = `Hello ${member.fullName}, your payment of \u20b9${schedule.amount} for ${schedule.monthYear || 'rent'} is due on ${dueDateFormatted}. Pay directly to ${org.name} via: ${paymentLink}`;
    }

    const cleanPhone = String(member.phone).replace(/[^0-9]/g, '');
    const fullPhone = cleanPhone.length === 10 ? `91${cleanPhone}` : cleanPhone;
    const directWhatsAppUrl = `https://wa.me/${fullPhone}?text=${encodeURIComponent(messageBody)}`;

    // BUG-FIX BUG-06: Actually send via WhatsApp Cloud API (not just return a wa.me link)
    let whatsappApiSent = false;
    if (creditDeducted) {
      const waResult = await sendWhatsAppReminder({
        phone: String(member.phone),
        memberName: member.fullName,
        billingMonth: schedule.monthYear || 'Current Month',
        amount: schedule.amount,
        dueDate: dueDateFormatted,
        paymentLink,
        facilityName: org?.name || 'TrackMyRent',
      });
      whatsappApiSent = waResult.success;
      if (!waResult.success) {
        // Refund the credit if Cloud API delivery failed
        if (subCredit) {
          await prisma.subscriptionCredit.update({
            where: { organizationId: org.id },
            data: { usedCredits: { decrement: 1 } },
          });
          creditDeducted = false;
          remainingCredits++;
        }
      }
    }

    return res.status(200).json({
      success: true,
      message: creditDeducted
        ? (whatsappApiSent ? 'Payment reminder sent via WhatsApp Cloud API. 1 credit deducted.' : 'Reminder generated but Cloud API unavailable. Use directWhatsAppUrl as fallback.')
        : 'No credits remaining. Use directWhatsAppUrl to send manually.',
      creditDeducted,
      remainingCredits,
      whatsappApiSent,
      paymentLink,
      messageBody,
      directWhatsAppUrl,
      customer: {
        name: member.fullName,
        phone: member.phone,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};

/**
 * Send official WhatsApp Payment Receipt via Meta Cloud API
 * Deducts 1 credit if available and sends template `payment_receipt_confirmation`.
 */
export const sendPaymentReceipt = async (req: Request, res: Response) => {
  try {
    const { scheduleId, transactionId } = req.body;

    if (!scheduleId && !transactionId) {
      return res.status(400).json({ success: false, error: 'Either scheduleId or transactionId is required' });
    }

    let schedule = null;
    let transaction = null;

    if (transactionId) {
      transaction = await prisma.transaction.findUnique({
        where: { id: transactionId },
        include: {
          paymentSchedule: {
            include: {
              member: { include: { organization: true } },
            },
          },
        },
      });
      schedule = transaction?.paymentSchedule;
    } else if (scheduleId) {
      schedule = await prisma.paymentSchedule.findUnique({
        where: { id: scheduleId },
        include: {
          member: { include: { organization: true } },
          transactions: { orderBy: { createdAt: 'desc' }, take: 1 },
        },
      });
      transaction = schedule?.transactions?.[0] || null;
    }

    if (!schedule || !schedule.member) {
      return res.status(404).json({ success: false, error: 'Payment schedule or member not found' });
    }

    const member = schedule.member;
    const org = member.organization;
    const finalAmount = transaction?.amountPaid || schedule.amount;
    const paymentMethod = transaction?.paymentMethod || 'UPI';
    const receiptUrl = `${process.env.APP_BASE_URL || 'https://trackmyrent.app'}/receipt/${transaction?.id || schedule.id}`;

    const waResult = await sendWhatsAppReceipt({
      phone: member.phone,
      memberName: member.fullName,
      billingMonth: schedule.monthYear || 'Current Month',
      amountPaid: finalAmount,
      paymentMethod,
      receiptUrl,
      facilityName: org?.name || 'TrackMyRent',
    });

    if (waResult.success && org) {
      const subCredit = await prisma.subscriptionCredit.findUnique({ where: { organizationId: org.id } });
      const now = new Date();
      const isExpired = subCredit?.expiresAt && subCredit.expiresAt < now;
      if (subCredit && !isExpired && (subCredit.purchasedCredits - subCredit.usedCredits) > 0) {
        await prisma.subscriptionCredit.update({
          where: { organizationId: org.id },
          data: { usedCredits: { increment: 1 } },
        });
      }
    }

    return res.status(200).json({
      success: waResult.success,
      message: waResult.success
        ? 'Receipt sent successfully via WhatsApp Cloud API'
        : waResult.error || 'Failed to send WhatsApp receipt via Cloud API',
      messageId: waResult.messageId,
      receiptUrl,
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * Public Endpoint: Customer submits UTR / UPI Reference ID after paying direct to landlord UPI
 */
export const submitUtrReference = async (req: Request, res: Response) => {
  try {
    const { scheduleId, utrNumber } = req.body;

    if (!scheduleId || !utrNumber) {
      return res.status(400).json({ success: false, error: 'scheduleId and utrNumber are required' });
    }

    const cleanedUtr = String(utrNumber).trim();
    if (cleanedUtr.length < 6) {
      return res.status(400).json({ success: false, error: 'Invalid UTR reference number length' });
    }

    const schedule = await prisma.paymentSchedule.findUnique({
      where: { id: scheduleId },
      include: { member: true },
    });

    if (!schedule) {
      return res.status(404).json({ success: false, error: 'Payment schedule not found' });
    }

    // Attach UTR reference note to payment schedule notes
    const currentNotes = schedule.notes ? `${schedule.notes} | ` : '';
    const updatedNotes = `${currentNotes}UTR Ref: ${cleanedUtr} (Pending Owner Verification)`;

    await prisma.paymentSchedule.update({
      where: { id: scheduleId },
      data: {
        notes: updatedNotes,
      },
    });

    return res.status(200).json({
      success: true,
      message: 'UTR reference submitted successfully. Landlord has been notified.',
      utr: cleanedUtr,
    });
  } catch (error: any) {
    return res.status(500).json({ success: false, error: error.message });
  }
};

