import { Router } from 'express';
import {
  createMember,
  listMembers,
  getMemberDetails,
  createCustomFieldDefinition,
} from '../controllers/memberController';

const router = Router();

router.post('/', createMember);
router.get('/', listMembers);
router.post('/custom-fields', createCustomFieldDefinition); // must be before /:id
router.get('/:id', getMemberDetails);
router.put('/:id', async (req, res) => {
  const { prisma } = await import('../index.js');
  try {
    const { id } = req.params;
    const { fullName, phone, planId, groupId, joiningDate, duration, dateOfBirth, notes, customFieldsData } = req.body;
    const updated = await prisma.member.update({
      where: { id },
      data: {
        ...(fullName && { fullName }),
        ...(phone && { phone }),
        ...(planId !== undefined && { planId: planId || null }),
        ...(groupId !== undefined && { groupId: groupId || null }),
        ...(joiningDate && { joiningDate: new Date(joiningDate) }),
        ...(duration && { duration }),
        ...(dateOfBirth !== undefined && { dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : null }),
        ...(notes !== undefined && { notes }),
        ...(customFieldsData && { customFieldsData }),
      },
      include: { plan: true, group: true },
    });
    res.status(200).json({ message: 'Member updated successfully', member: updated });
  } catch (error) {
    res.status(500).json({ error: (error as Error).message });
  }
});

export default router;

