import Redis from 'ioredis';
import { ConnectionOptions } from 'bullmq';

const REDIS_HOST = process.env.REDIS_HOST || 'localhost';
const REDIS_PORT = Number(process.env.REDIS_PORT) || 6379;

/**
 * Shared Redis connection options for BullMQ Queues and Workers.
 * maxRetriesPerRequest MUST be null for BullMQ.
 */
export const redisConfig: ConnectionOptions = {
  host: REDIS_HOST,
  port: REDIS_PORT,
  maxRetriesPerRequest: null,
  enableReadyCheck: false,
  lazyConnect: true,
  retryStrategy(times: number) {
    if (times > 10) {
      return null;
    }
    return Math.min(times * 200, 2000);
  },
};

let redisClient: Redis | null = null;

export const getRedisClient = (): Redis => {
  if (!redisClient) {
    redisClient = new Redis(redisConfig);

    redisClient.on('connect', () => {
      console.log(`✅ Redis connected successfully at ${REDIS_HOST}:${REDIS_PORT}`);
    });

    redisClient.on('error', (err) => {
      // Graceful warning so API won't crash if Redis is temporarily offline in local dev
      console.warn(`⚠️ Redis connection warning (${REDIS_HOST}:${REDIS_PORT}): ${err.message}`);
    });
  }

  return redisClient;
};

export const checkRedisHealth = async (): Promise<{ isConnected: boolean; host: string; port: number; latencyMs?: number; error?: string }> => {
  try {
    const client = getRedisClient();
    const start = Date.now();
    await client.ping();
    const latencyMs = Date.now() - start;
    return { isConnected: true, host: REDIS_HOST, port: REDIS_PORT, latencyMs };
  } catch (error) {
    return {
      isConnected: false,
      host: REDIS_HOST,
      port: REDIS_PORT,
      error: (error as Error).message,
    };
  }
};
