import { Router } from 'express';
import { registerOrg, login, customerLogin } from '../controllers/authController';

const router = Router();

router.post('/register', registerOrg);
router.post('/login', login);
router.post('/customer-login', customerLogin);

export default router;
