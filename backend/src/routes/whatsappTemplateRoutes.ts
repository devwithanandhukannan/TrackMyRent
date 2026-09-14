import { Router } from 'express';
import {
  getWhatsAppTemplates,
  updateWhatsAppTemplate,
} from '../controllers/whatsappTemplateController';

const router = Router();

router.get('/', getWhatsAppTemplates);
router.put('/:id', updateWhatsAppTemplate);

export default router;
