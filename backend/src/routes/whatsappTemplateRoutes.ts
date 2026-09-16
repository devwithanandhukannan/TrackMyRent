import { Router } from 'express';
import {
  getWhatsAppTemplates,
  createWhatsAppTemplate,
  updateWhatsAppTemplate,
  deleteWhatsAppTemplate,
} from '../controllers/whatsappTemplateController';

const router = Router();

router.get('/', getWhatsAppTemplates);
router.post('/', createWhatsAppTemplate);
router.put('/:id', updateWhatsAppTemplate);
router.delete('/:id', deleteWhatsAppTemplate);

export default router;
