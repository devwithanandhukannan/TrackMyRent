import { Request, Response } from 'express';
import { prisma } from '../index';

/**
 * Add a new Member / Tenant
 * Auto-applies Plan Duration settings if Plan is selected.
 * Supports Admin Dynamic Custom Fields (Aadhaar, Address, Emergency Contact, etc.)
 */
export const createMember = async (req: Request, res: Response) => {
  try {
    const {
      organizationId,
      fullName,
      phone,
      planId,
      groupId,
      joiningDate,
      duration,
      dateOfBirth,
      notes,
      customFieldsData,
    } = req.body;

    if (!organizationId || !fullName || !phone) {
      return res.status(400).json({ error: 'organizationId, fullName, and phone are required' });
    }

    if (!planId) {
      return res.status(400).json({ error: 'Plan is mandatory: Member cannot be created without selecting a Plan.' });
    }

    let computedDuration = duration;
    const selectedPlan = await prisma.plan.findUnique({ where: { id: planId } });
    if (!selectedPlan) {
      return res.status(404).json({ error: 'Selected Plan not found. Please choose a valid plan.' });
    }

    if (!duration) {
      computedDuration = selectedPlan.durationType === 'DAYS_30' ? `${selectedPlan.durationDays} Days` : 'Monthly (Custom Date)';
    }

    const member = await prisma.member.create({
      data: {
        organizationId,
        fullName,
        phone,
        planId: planId || null,
        groupId: groupId || null,
        joiningDate: joiningDate ? new Date(joiningDate) : new Date(),
        duration: computedDuration || '30 Days',
        dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : null,
        notes: notes || null,
        customFieldsData: customFieldsData || {},
      },
      include: { plan: true, group: true },
    });

    // Auto-generate initial payment schedule if plan selected
    if (selectedPlan) {
      const cycleDate = new Date(member.joiningDate);
      let dueDate = new Date(cycleDate);
      if (req.body.dueDayNumber) {
        dueDate = new Date(cycleDate.getFullYear(), cycleDate.getMonth(), Number(req.body.dueDayNumber));
      } else if (selectedPlan.collectionDayType === 'FIRST_DAY_OF_MONTH') {
        dueDate = new Date(cycleDate.getFullYear(), cycleDate.getMonth(), 1);
      } else if (selectedPlan.collectionDayType === 'LAST_DAY_OF_MONTH') {
        dueDate = new Date(cycleDate.getFullYear(), cycleDate.getMonth() + 1, 0);
      } else if (selectedPlan.customDayNumber) {
        dueDate = new Date(cycleDate.getFullYear(), cycleDate.getMonth(), selectedPlan.customDayNumber);
      }

      const monthYear = `${dueDate.getFullYear()}-${String(dueDate.getMonth() + 1).padStart(2, '0')}`;
      const scheduleAmount = req.body.monthlyRent ? Number(req.body.monthlyRent) : selectedPlan.price;

      await prisma.paymentSchedule.create({
        data: {
          memberId: member.id,
          monthYear,
          dueDate,
          amount: scheduleAmount,
          status: 'UNPAID',
        },
      });
    }

    res.status(201).json({
      message: 'Member created successfully',
      member,
      whatsappWelcomeTemplate: `Hello ${fullName}, welcome to our facility! Your membership plan is ${selectedPlan?.name || 'Default'}.`,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * List Members with status filters (PAID, UNPAID, FROZEN)
 */
export const listMembers = async (req: Request, res: Response) => {
  try {
    const { organizationId, status, planId, groupId, search } = req.query;

    const where: any = {};
    if (organizationId) where.organizationId = String(organizationId);
    if (planId) where.planId = String(planId);
    if (groupId) where.groupId = String(groupId);
    if (search) {
      where.OR = [
        { fullName: { contains: String(search), mode: 'insensitive' } },
        { phone: { contains: String(search), mode: 'insensitive' } },
      ];
    }

    const members = await prisma.member.findMany({
      where,
      include: {
        organization: true,
        plan: true,
        group: true,
        paymentSchedules: {
          orderBy: { dueDate: 'desc' },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    // Compute status for each member based on latest schedule
    const formattedMembers = members.map((m) => {
      const latestSchedule = m.paymentSchedules[0];
      const memberStatus = latestSchedule ? latestSchedule.status : 'UNPAID';

      return {
        id: m.id,
        organizationId: m.organizationId,
        organizationName: m.organization?.name || 'Unknown Facility',
        organizationType: m.organization?.type || 'FACILITY',
        fullName: m.fullName,
        phone: m.phone,
        joiningDate: m.joiningDate,
        duration: m.duration,
        planName: m.plan?.name || 'No Plan',
        groupName: m.group?.name || 'Direct',
        status: memberStatus,
        amount: latestSchedule ? latestSchedule.amount : (m.plan?.price || 0),
        dueDate: latestSchedule?.dueDate || null,
        latestMonthYear: latestSchedule?.monthYear || 'N/A',
        customFields: m.customFieldsData,
      };
    });

    // Apply status filter if requested
    const filtered = status
      ? formattedMembers.filter((m) => m.status === String(status).toUpperCase())
      : formattedMembers;

    res.status(200).json({ count: filtered.length, members: filtered });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Get Single Member Details with Paid History, Unpaid History, and Frozen History
 */
export const getMemberDetails = async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    const member = await prisma.member.findUnique({
      where: { id },
      include: {
        plan: true,
        group: true,
        paymentSchedules: {
          orderBy: { dueDate: 'desc' },
          include: { transactions: true },
        },
      },
    });

    if (!member) return res.status(404).json({ error: 'Member not found' });

    const paidHistory = member.paymentSchedules.filter((s) => s.status === 'PAID');
    const unpaidHistory = member.paymentSchedules.filter((s) => s.status === 'UNPAID');
    const frozenHistory = member.paymentSchedules.filter((s) => s.status === 'FROZEN');

    const totalPendingAmount = unpaidHistory.reduce((sum, s) => sum + s.amount, 0);

    res.status(200).json({
      member: {
        id: member.id,
        fullName: member.fullName,
        phone: member.phone,
        dateOfBirth: member.dateOfBirth,
        notes: member.notes,
        joiningDate: member.joiningDate,
        duration: member.duration,
        plan: member.plan,
        group: member.group,
        customFields: member.customFieldsData,
      },
      summary: {
        totalPendingAmount, // Strictly excludes frozen months
        paidMonthsCount: paidHistory.length,
        unpaidMonthsCount: unpaidHistory.length,
        frozenMonthsCount: frozenHistory.length,
      },
      paidHistory,
      unpaidHistory,
      frozenHistory,
    });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
};

/**
 * Custom Fields Manager: Create dynamic fields (Aadhaar, Emergency Contact, Address, etc.)
 */
export const createCustomFieldDefinition = async (req: Request, res: Response) => {
  try {
    const { organizationId, fieldName, fieldType = 'TEXT', options = [], isRequired = false } = req.body;

    if (!fieldName || !String(fieldName).trim()) {
      return res.status(400).json({ error: 'Field label/name is required' });
    }

    let orgId = organizationId ? String(organizationId) : null;
    if (!orgId) {
      const firstOrg = await prisma.organization.findFirst();
      orgId = firstOrg?.id ?? null;
    }
    if (!orgId) {
      return res.status(400).json({ error: 'Organization ID is required' });
    }

    // Map and sanitize fieldType to valid CustomFieldType enum
    let normalizedType: any = 'TEXT';
    const rawType = String(fieldType).toUpperCase().trim();
    if (rawType === 'NUMBER') normalizedType = 'NUMBER';
    else if (rawType === 'DATE') normalizedType = 'DATE';
    else if (rawType === 'DROPDOWN') normalizedType = 'DROPDOWN';
    else if (rawType === 'CHECKBOX' || rawType === 'BOOLEAN') normalizedType = 'CHECKBOX';
    else if (rawType === 'MULTI_LINE' || rawType === 'MULTILINE' || rawType === 'TEXTAREA') normalizedType = 'MULTI_LINE';
    else normalizedType = 'TEXT';

    const customField = await prisma.customFieldDefinition.create({
      data: {
        organizationId: orgId,
        fieldName: String(fieldName).trim(),
        fieldType: normalizedType,
        options: Array.isArray(options) ? options : [],
        isRequired: Boolean(isRequired),
      },
    });

    res.status(201).json({ success: true, message: 'Custom field definition created', customField });
  } catch (error) {
    res.status(500).json({ success: false, error: (error as Error).message });
  }
};
