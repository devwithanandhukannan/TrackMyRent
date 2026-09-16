import { Router } from 'express';
import {
  registerOrg,
  login,
  customerLogin,
  sendOtp,
  verifyOtp,
  getAllOrganizations,
  updateTenantPayout,
  subscribeAppPlan,
} from '../controllers/authController';

const router = Router();

router.post('/register', registerOrg);
router.post('/login', login);
router.post('/customer-login', customerLogin);
router.post('/send-otp', sendOtp);
router.post('/verify-otp', verifyOtp);
router.get('/organizations', getAllOrganizations);
router.put('/organization/:id/payout', updateTenantPayout);
router.post('/organization/:id/subscribe-app-plan', subscribeAppPlan);

export default router;

