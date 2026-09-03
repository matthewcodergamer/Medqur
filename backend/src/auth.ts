import type { NextFunction, Request, Response } from 'express';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { config } from './config.js';
import { pool } from './db.js';

export type MedqurRole =
  | 'doctor'
  | 'nurse'
  | 'triage_nurse'
  | 'pharmacist'
  | 'pharmacy_technician'
  | 'administrator';

export interface AuthContext {
  staffId: string;
  displayName: string;
  roles: MedqurRole[];
  facilityIds: string[];
  dev: boolean;
}

declare global {
  namespace Express {
    interface Request {
      auth?: AuthContext;
    }
  }
}

const jwks = config.oidcJwksUrl
  ? createRemoteJWKSet(new URL(config.oidcJwksUrl))
  : null;

async function loadRoles(staffId: string): Promise<{ roles: MedqurRole[]; facilityIds: string[] }> {
  const result = await pool.query(
    `SELECT role, facility_id
       FROM staff_facility_roles
      WHERE staff_id = $1 AND active = true`,
    [staffId],
  );
  return {
    roles: [...new Set(result.rows.map((row) => row.role as MedqurRole))],
    facilityIds: [...new Set(result.rows.map((row) => String(row.facility_id)))],
  };
}

export async function authenticate(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    if (config.devAuth) {
      const staffId = String(req.header('x-medqur-staff-id') ?? 'DEV-PHARMACIST');
      const roleHeader = String(req.header('x-medqur-role') ?? 'pharmacist');
      const facility = String(req.header('x-medqur-facility') ?? 'MRH');
      req.auth = {
        staffId,
        displayName: String(req.header('x-medqur-staff-name') ?? 'Development User'),
        roles: roleHeader.split(',').map((value) => value.trim()) as MedqurRole[],
        facilityIds: facility.split(',').map((value) => value.trim()),
        dev: true,
      };
      next();
      return;
    }

    if (!jwks || !config.oidcIssuer) {
      res.status(503).json({ error: 'Production OIDC authentication is not configured.' });
      return;
    }

    const header = req.header('authorization') ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!token) {
      res.status(401).json({ error: 'Bearer token required.' });
      return;
    }

    const verified = await jwtVerify(token, jwks, {
      issuer: config.oidcIssuer,
      audience: config.oidcAudience,
    });
    const staffId = String(verified.payload.sub ?? '');
    if (!staffId) {
      res.status(401).json({ error: 'Token subject is missing.' });
      return;
    }
    const permissions = await loadRoles(staffId);
    req.auth = {
      staffId,
      displayName: String(verified.payload.name ?? staffId),
      roles: permissions.roles,
      facilityIds: permissions.facilityIds,
      dev: false,
    };
    next();
  } catch (error) {
    res.status(401).json({ error: 'Authentication failed.', detail: String(error) });
  }
}

export function requireRoles(...allowed: MedqurRole[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const auth = req.auth;
    if (!auth || !auth.roles.some((role) => allowed.includes(role))) {
      res.status(403).json({ error: 'This clinical role is not authorized for this action.' });
      return;
    }
    next();
  };
}

export function requireFacility(req: Request, res: Response, facilityId: string): boolean {
  const auth = req.auth;
  if (!auth) {
    res.status(401).json({ error: 'Authentication required.' });
    return false;
  }
  if (!auth.roles.includes('administrator') && !auth.facilityIds.includes(facilityId)) {
    res.status(403).json({ error: 'The user is not authorized for this facility.' });
    return false;
  }
  return true;
}
