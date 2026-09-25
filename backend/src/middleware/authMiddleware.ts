import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface AuthenticatedUser {
  userId: string;
  orgId: string;
  role: string;
}

export interface AuthenticatedRequest extends Request {
  user?: AuthenticatedUser;
}

/**
 * Authentication middleware for protecting sensitive facility/admin endpoints.
 * Verifies JWT token provided in the `Authorization: Bearer <token>` header.
 *
 * In production (`NODE_ENV === 'production'`), strict validation is enforced.
 * In development, permits demo tokens or local bypass with warnings.
 */
export const authMiddleware = (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  const isProduction = process.env.NODE_ENV === 'production';

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    if (!isProduction) {
      // In local development, fallback to mock demo admin if no token is provided
      console.warn(`[AuthMiddleware] DEV WARNING: No Bearer token provided for ${req.method} ${req.path}. Using dev admin fallback.`);
      req.user = {
        userId: 'dev_admin_user',
        orgId: req.body?.organizationId || req.query?.organizationId || 'dev_org',
        role: 'ORG_ADMIN',
      };
      return next();
    }
    return res.status(401).json({
      success: false,
      error: 'Authentication required. Missing or malformed Authorization header (Bearer <token>).',
    });
  }

  const token = authHeader.split(' ')[1];

  // Allow debug demo token in non-production environments
  if (!isProduction && token.startsWith('demo_token_')) {
    req.user = {
      userId: 'demo_admin_user',
      orgId: req.body?.organizationId || req.query?.organizationId || 'demo_facility_org',
      role: 'ORG_ADMIN',
    };
    return next();
  }

  try {
    const secret = process.env.JWT_SECRET || 'secret';
    const decoded = jwt.verify(token, secret) as AuthenticatedUser;
    req.user = decoded;
    next();
  } catch (error: any) {
    if (!isProduction && token === 'dev_bypass_token') {
      req.user = { userId: 'dev_user', orgId: 'dev_org', role: 'ORG_ADMIN' };
      return next();
    }
    return res.status(401).json({
      success: false,
      error: 'Invalid or expired authentication token. Please log in again.',
    });
  }
};
