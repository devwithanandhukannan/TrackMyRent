import { Router } from 'express';
import {
  getCreditPackages,
  createCreditPackage,
  updateCreditPackage,
  toggleCreditPackageStatus,
  deleteCreditPackage,
} from '../controllers/creditPackageController';

const router = Router();

router.get('/', getCreditPackages);
router.post('/', createCreditPackage);
router.put('/:id', updateCreditPackage);
router.patch('/:id/toggle', toggleCreditPackageStatus);
router.delete('/:id', deleteCreditPackage);

export default router;
