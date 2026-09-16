import { Request, Response } from 'express';
import { prisma } from '../index';
import { createRazorpayOrder, verifyRazorpaySignature } from '../services/razorpayService';

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
 * Mark a payment schedule as PAID
 */
export const markAsPaid = async (req: Request, res: Response) => {
  try {
    const { scheduleId, amountPaid, paymentMethod = 'CASH', notes } = req.body;

    const schedule = await prisma.paymentSchedule.findUnique({ where: { id: scheduleId } });
    if (!schedule) return res.status(404).json({ error: 'Payment schedule not found' });

    const updatedSchedule = await prisma.paymentSchedule.update({
      where: { id: scheduleId },
      data: { status: 'PAID', notes },
    });

    const transaction = await prisma.transaction.create({
      data: {
        memberId: schedule.memberId,
        paymentScheduleId: schedule.id,
        amountPaid: amountPaid || schedule.amount,
        paymentMethod,
        notes,
      },
    });

    res.status(200).json({
      message: 'Payment marked as PAID',
      schedule: updatedSchedule,
      transaction,
      confirmationFlow: {
        sendInvoice: `/api/payments/${transaction.id}/invoice`,
        sendWhatsApp: `/api/whatsapp/send-receipt?transactionId=${transaction.id}`,
        skipOptionAvailable: true,
      },
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Revert payment status back to UNPAID (with confirmation requirement)
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

    const updatedSchedule = await prisma.paymentSchedule.update({
      where: { id: scheduleId },
      data: { status: 'UNPAID' },
    });

    res.status(200).json({ message: 'Payment reverted to UNPAID successfully', schedule: updatedSchedule });
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

    const schedule = await prisma.paymentSchedule.findUnique({ where: { id: scheduleId } });
    if (!schedule) return res.status(404).json({ error: 'Payment schedule not found' });

    const updatedSchedule = await prisma.paymentSchedule.update({
      where: { id: scheduleId },
      data: {
        status: 'FROZEN',
        frozenAt: new Date(),
        notes: notes || 'Month frozen by admin',
      },
    });

    res.status(200).json({
      message: 'Month frozen successfully. Excluded from pending dues calculations.',
      schedule: updatedSchedule,
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
 * Production Razorpay Order Creation
 */
export const createRazorpayPaymentOrder = async (req: Request, res: Response) => {
  try {
    const { scheduleId, memberId, amount } = req.body;

    const schedule = await prisma.paymentSchedule.findUnique({ where: { id: scheduleId } });
    if (!schedule) return res.status(404).json({ error: 'Schedule not found' });

    const orderReceipt = `rcpt_${schedule.id.slice(0, 8)}_${Date.now()}`;
    const order = await createRazorpayOrder(amount || schedule.amount, orderReceipt, {
      scheduleId: schedule.id,
      memberId,
    });

    res.status(200).json({
      message: 'Razorpay order created successfully',
      keyId: process.env.RAZORPAY_KEY_ID,
      order,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Production Razorpay Signature Verification & Auto-Mark Paid
 */
export const verifyRazorpayPayment = async (req: Request, res: Response) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature, scheduleId, paymentMethod = 'UPI' } = req.body;

    const isValid = verifyRazorpaySignature(razorpay_order_id, razorpay_payment_id, razorpay_signature);

    if (!isValid) {
      return res.status(400).json({ error: 'Invalid Razorpay signature verification failed' });
    }

    const schedule = await prisma.paymentSchedule.findUnique({ where: { id: scheduleId } });
    if (!schedule) return res.status(404).json({ error: 'Schedule not found' });

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
      message: 'Razorpay payment verified and marked as PAID successfully',
      schedule: updatedSchedule,
      transaction,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Get all payment transactions with filters
 */
export const getTransactions = async (req: Request, res: Response) => {
  try {
    const { organizationId, filter } = req.query;

    const transactions = await prisma.transaction.findMany({
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
    const { scheduleId } = req.body;

    if (!scheduleId) {
      return res.status(400).json({ success: false, error: 'scheduleId is required' });
    }

    const schedule = await prisma.paymentSchedule.findUnique({
      where: { id: scheduleId },
      include: {
        member: {
          include: { organization: true, plan: true },
        },
      },
    });

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

    if (subCredit) {
      const available = subCredit.purchasedCredits - subCredit.usedCredits;
      if (available > 0) {
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

    // 2. Construct Direct Tenant Payout Link
    let paymentLink = '';
    if (org.bankUpiId) {
      const payeeName = encodeURIComponent(org.bankAccountName || org.name);
      const note = encodeURIComponent(`Rent ${schedule.monthYear || ''} - ${member.fullName}`);
      paymentLink = `upi://pay?pa=${encodeURIComponent(org.bankUpiId)}&pn=${payeeName}&am=${schedule.amount}&cu=INR&tn=${note}`;
    } else {
      paymentLink = `https://trackmyrent.app/pay/${schedule.id}`;
    }

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

    let messageBody = '';
    if (template && template.messageText) {
      messageBody = template.messageText
        .replace(/\{\{1\}\}/g, member.fullName)
        .replace(/\{\{2\}\}/g, String(schedule.amount))
        .replace(/\{\{3\}\}/g, schedule.monthYear || 'Current Month')
        .replace(/\{\{4\}\}/g, dueDateFormatted)
        .replace(/\{\{5\}\}/g, paymentLink);
    } else {
      messageBody = `Hello ${member.fullName}, your payment of ₹${schedule.amount} for ${schedule.monthYear || 'rent'} is due on ${dueDateFormatted}. Pay directly to ${org.name} via: ${paymentLink}`;
    }

    const cleanPhone = String(member.phone).replace(/[^0-9]/g, '');
    const fullPhone = cleanPhone.length === 10 ? `91${cleanPhone}` : cleanPhone;
    const directWhatsAppUrl = `https://wa.me/${fullPhone}?text=${encodeURIComponent(messageBody)}`;

    return res.status(200).json({
      success: true,
      message: creditDeducted ? 'Payment reminder generated and 1 credit deducted' : 'Reminder ready via direct WhatsApp (0 credits remaining)',
      creditDeducted,
      remainingCredits,
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

