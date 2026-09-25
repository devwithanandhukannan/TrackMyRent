import express, { Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

dotenv.config();

const app = express();
const prisma = new PrismaClient();

const PORT = process.env.PORT || 5001;

import authRoutes from './routes/authRoutes';
import paymentRoutes from './routes/paymentRoutes';
import memberRoutes from './routes/memberRoutes';
import planRoutes from './routes/planRoutes';
import expenseRoutes from './routes/expenseRoutes';
import reportRoutes from './routes/reportRoutes';
import creditRoutes from './routes/creditRoutes';
import appPlanRoutes from './routes/appPlanRoutes';
import expenseCategoryRoutes from './routes/expenseCategoryRoutes';
import whatsappTemplateRoutes from './routes/whatsappTemplateRoutes';
import settingRoutes from './routes/settingRoutes';
import creditPackageRoutes from './routes/creditPackageRoutes';
import queueRoutes from './routes/queueRoutes';
import whatsappWebhookRoutes from './routes/whatsappWebhookRoutes';

import { reminderWorker, registerDailyReminderCron } from './queues/reminderQueue';
import { billingWorker, registerMonthlyBillingCron } from './queues/billingQueue';
import { webhookWorker } from './queues/webhookQueue';
import { paymentExpiryWorker } from './queues/paymentExpiryQueue';

import { renderHostedPaymentGateway } from './controllers/paymentController';

app.use(cors());
app.use(express.json());

// Public Hosted Payment Gateway for WhatsApp Payment Links
app.get('/pay/:id', renderHostedPaymentGateway);
app.get('/pay', renderHostedPaymentGateway);

app.use('/api/auth', authRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/members', memberRoutes);
app.use('/api/plans', planRoutes);
app.use('/api/expenses', expenseRoutes);
app.use('/api/expenses/categories', expenseCategoryRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/credits', creditRoutes);
app.use('/api/app-plans', appPlanRoutes);
app.use('/api/credit-packages', creditPackageRoutes);
app.use('/api/settings', settingRoutes);
app.use('/api/settings/whatsapp-templates', whatsappTemplateRoutes);
app.use('/api/queues', queueRoutes);
app.use('/api/whatsapp/webhook', whatsappWebhookRoutes);
app.use('/webhook', whatsappWebhookRoutes);

// Root Status
app.get('/', (req: Request, res: Response) => {
  res.status(200).json({
    status: 'ONLINE',
    app: 'TrackMyRent API',
    domain: 'https://trackmyrent.anandhu-kannan.in',
    docs: 'https://trackmyrent.anandhu-kannan.in/health',
    timestamp: new Date().toISOString(),
  });
});

// Health Check Endpoint
app.get('/health', async (req: Request, res: Response) => {
  try {
    // Quick database ping
    await prisma.$queryRaw`SELECT 1`;
    res.status(200).json({
      status: 'OK',
      message: 'RentTrack Backend API is healthy and connected to Docker PostgreSQL Database!',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    res.status(500).json({
      status: 'ERROR',
      message: 'Database connection failed',
      error: (error as Error).message,
    });
  }
});

const server = app.listen(PORT, async () => {
  console.log(`🚀 RentTrack Backend running on http://localhost:${PORT}`);
  
  // Register BullMQ repeatable background cron jobs
  await registerDailyReminderCron();
  await registerMonthlyBillingCron();
});

// Graceful Shutdown for BullMQ Workers
const shutdown = async (signal: string) => {
  console.log(`\n🛑 Received ${signal}. Shutting down BullMQ workers cleanly...`);
  try {
    await Promise.all([
      reminderWorker.close(),
      billingWorker.close(),
      webhookWorker.close(),
      paymentExpiryWorker.close(),
    ]);
    console.log('✅ BullMQ workers closed.');
    server.close(() => {
      console.log('✅ HTTP server closed.');
      process.exit(0);
    });
  } catch (err) {
    console.error('Error during shutdown:', err);
    process.exit(1);
  }
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

export { app, prisma };
