import {
  createHash,
  createPrivateKey,
  createPublicKey,
  randomInt,
  randomUUID,
  sign as cryptoSign,
  verify as cryptoVerify,
} from 'node:crypto';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import type { PoolClient } from 'pg';
import { z } from 'zod';

import { appendAudit, emitOutbox } from './audit.js';
import { authenticate, requireRoles } from './auth.js';
import { config } from './config.js';
import { healthCheck, pool, withTransaction } from './db.js';

const app = express();
app.disable('x-powered-by');
app.use(helmet());
app.use(cors({
  origin: config.allowedOrigins.length === 0 ? false : config.allowedOrigins,
}));
app.use(express.json({ limit: '128kb' }));

const roleSchema = z.enum([
  'doctor',
  'nurse',
  'triage_nurse',
  'pharmacist',
  'pharmacy_technician',
  'administrator',
]);

const sixDigitStaffNumber = z.string().regex(/^\d{6}$/, 'Staff ID must contain exactly six digits.');

interface StaffBadgePayload {
  v: 1;
  t: 'staff';
  cid: string;
  iat: number;
  exp: number;
  kid: string;
}

interface StaffRow {
  id: string;
  staff_number: string;
  display_name: string;
  professional_registration: string | null;
  employment_status: string;
}

function privateKey() {
  if (!config.staffBadgeSigningPrivateKeyPem) {
    throw new Error('Staff badge signing key is not configured.');
  }
  return createPrivateKey(
    config.staffBadgeSigningPrivateKeyPem.replace(/\\n/g, '\n'),
  );
}

function publicKey() {
  if (config.staffBadgeVerifyPublicKeyPem) {
    return createPublicKey(
      config.staffBadgeVerifyPublicKeyPem.replace(/\\n/g, '\n'),
    );
  }
  if (config.staffBadgeSigningPrivateKeyPem) {
    return createPublicKey(privateKey());
  }
  throw new Error('Staff badge verification key is not configured.');
}

function encodePayload(payload: StaffBadgePayload): string {
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

function decodePayload(value: string): StaffBadgePayload | null {
  try {
    const parsed = JSON.parse(Buffer.from(value, 'base64url').toString('utf8')) as Partial<StaffBadgePayload>;
    if (
      parsed.v !== 1 ||
      parsed.t !== 'staff' ||
      typeof parsed.cid !== 'string' ||
      typeof parsed.iat !== 'number' ||
      typeof parsed.exp !== 'number' ||
      typeof parsed.kid !== 'string'
    ) {
      return null;
    }
    return parsed as StaffBadgePayload;
  } catch {
    return null;
  }
}

function signedToken(payload: StaffBadgePayload): string {
  const encoded = encodePayload(payload);
  const signature = cryptoSign(null, Buffer.from(encoded, 'utf8'), privateKey())
    .toString('base64url');
  return `MQW1.${encoded}.${signature}`;
}

function verifySignedToken(token: string): StaffBadgePayload | null {
  const parts = token.trim().split('.');
  if (parts.length !== 3 || parts[0] !== 'MQW1') return null;
  const payload = decodePayload(parts[1]);
  if (!payload || payload.kid !== config.staffBadgeKeyId) return null;
  try {
    const valid = cryptoVerify(
      null,
      Buffer.from(parts[1], 'utf8'),
      publicKey(),
      Buffer.from(parts[2], 'base64url'),
    );
    return valid ? payload : null;
  } catch {
    return null;
  }
}

function tokenDigest(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

async function allocateStaffNumber(client: PoolClient): Promise<string> {
  for (let attempt = 0; attempt < 120; attempt++) {
    const candidate = String(randomInt(100000, 1000000));
    const exists = await client.query(
      'SELECT 1 FROM staff_accounts WHERE staff_number=$1 LIMIT 1',
      [candidate],
    );
    if (exists.rowCount === 0) return candidate;
  }
  throw new Error('Unable to allocate a unique six-digit staff ID.');
}

async function findStaffByNumber(client: PoolClient, staffNumber: string): Promise<StaffRow | null> {
  const result = await client.query(
    `SELECT id, staff_number, display_name, professional_registration, employment_status
       FROM staff_accounts WHERE staff_number=$1 LIMIT 1`,
    [staffNumber],
  );
  return (result.rows[0] as StaffRow | undefined) ?? null;
}

async function findCurrentStaff(client: PoolClient, subject: string): Promise<StaffRow | null> {
  const result = await client.query(
    `SELECT id, staff_number, display_name, professional_registration, employment_status
       FROM staff_accounts
      WHERE id=$1 OR staff_number=$1
      LIMIT 1`,
    [subject],
  );
  return (result.rows[0] as StaffRow | undefined) ?? null;
}

async function staffPermissions(client: PoolClient, staffId: string) {
  const result = await client.query(
    `SELECT r.role, r.facility_id, f.name AS facility_name
       FROM staff_facility_roles r
       JOIN facilities f ON f.id=r.facility_id
      WHERE r.staff_id=$1 AND r.active=true AND f.active=true
      ORDER BY r.facility_id, r.role`,
    [staffId],
  );
  return result.rows.map((row) => ({
    role: String(row.role),
    facilityId: String(row.facility_id),
    facilityName: String(row.facility_name),
  }));
}

async function issueCredential(
  client: PoolClient,
  staffRow: StaffRow,
  createdBy: string,
  validDays: number,
) {
  if (staffRow.employment_status !== 'active') {
    throw new Error('Staff account is not active.');
  }

  await client.query(
    `UPDATE staff_badge_credentials
        SET revoked_at=now(), revoked_by=$2, revoke_reason='superseded'
      WHERE staff_id=$1 AND revoked_at IS NULL`,
    [staffRow.id, createdBy],
  );

  const credentialId = randomUUID();
  const issuedAtSeconds = Math.floor(Date.now() / 1000);
  const expiresAtSeconds = issuedAtSeconds + validDays * 86400;
  const payload: StaffBadgePayload = {
    v: 1,
    t: 'staff',
    cid: credentialId,
    iat: issuedAtSeconds,
    exp: expiresAtSeconds,
    kid: config.staffBadgeKeyId,
  };
  const token = signedToken(payload);
  const digest = tokenDigest(token);

  await client.query(
    `INSERT INTO staff_badge_credentials(
       id, staff_id, credential_version, issued_at, expires_at,
       qr_sha256, signing_key_id, created_by
     ) VALUES ($1,$2,1,$3,$4,$5,$6,$7)`,
    [
      credentialId,
      staffRow.id,
      new Date(issuedAtSeconds * 1000).toISOString(),
      new Date(expiresAtSeconds * 1000).toISOString(),
      digest,
      config.staffBadgeKeyId,
      createdBy,
    ],
  );

  await appendAudit(client, {
    actorId: createdBy,
    actorRole: 'administrator',
    eventType: 'staff.badge.issued',
    entityType: 'StaffBadgeCredential',
    entityId: credentialId,
    details: {
      staffId: staffRow.id,
      staffNumber: staffRow.staff_number,
      signingKeyId: config.staffBadgeKeyId,
      expiresAt: new Date(expiresAtSeconds * 1000).toISOString(),
    },
  });
  await emitOutbox(client, {
    topic: 'staff-identity',
    entityType: 'StaffBadgeCredential',
    entityId: credentialId,
    payload: {
      action: 'issued',
      staffId: staffRow.id,
      staffNumber: staffRow.staff_number,
    },
  });

  return {
    credentialId,
    token,
    staffNumber: staffRow.staff_number,
    issuedAt: new Date(issuedAtSeconds * 1000).toISOString(),
    expiresAt: new Date(expiresAtSeconds * 1000).toISOString(),
    signingKeyId: config.staffBadgeKeyId,
  };
}

async function presentationForCredential(row: Record<string, unknown>) {
  const issued = Math.floor(new Date(String(row.issued_at)).getTime() / 1000);
  const expires = Math.floor(new Date(String(row.expires_at)).getTime() / 1000);
  const payload: StaffBadgePayload = {
    v: 1,
    t: 'staff',
    cid: String(row.id),
    iat: issued,
    exp: expires,
    kid: String(row.signing_key_id),
  };
  const token = signedToken(payload);
  if (tokenDigest(token) !== String(row.qr_sha256)) {
    throw new Error('Stored badge fingerprint does not match the signing key/payload. Reissue this badge.');
  }
  return {
    credentialId: String(row.id),
    token,
    staffNumber: String(row.staff_number),
    issuedAt: new Date(String(row.issued_at)).toISOString(),
    expiresAt: new Date(String(row.expires_at)).toISOString(),
    signingKeyId: String(row.signing_key_id),
  };
}

app.get('/health', async (_req, res) => {
  try {
    res.json({
      ok: await healthCheck(),
      service: 'medqur-staff-identity',
      version: '0.10.0',
      signedBadges: Boolean(
        config.staffBadgeVerifyPublicKeyPem || config.staffBadgeSigningPrivateKeyPem,
      ),
    });
  } catch (error) {
    res.status(503).json({ ok: false, error: String(error) });
  }
});

const badgeVerifySchema = z.object({ token: z.string().min(16).max(4096) });

// Pre-auth route: a random signed credential can be verified before the staff
// member begins biometric/passkey sign-in. The QR itself contains no name,
// profession, registration number, facility or clinical data.
app.post('/v1/public/staff-badge/verify', async (req, res) => {
  const input = badgeVerifySchema.parse(req.body);
  const payload = verifySignedToken(input.token);
  const now = Math.floor(Date.now() / 1000);
  if (!payload || payload.exp <= now || payload.iat > now + 300) {
    res.status(401).json({ valid: false, error: 'Badge signature is invalid or expired.' });
    return;
  }

  const digest = tokenDigest(input.token.trim());
  const verified = await withTransaction(async (client) => {
    const result = await client.query(
      `SELECT c.id, c.staff_id, c.issued_at, c.expires_at, c.revoked_at,
              c.qr_sha256, c.signing_key_id,
              s.staff_number, s.display_name, s.professional_registration,
              s.employment_status
         FROM staff_badge_credentials c
         JOIN staff_accounts s ON s.id=c.staff_id
        WHERE c.id=$1 AND c.qr_sha256=$2
        LIMIT 1
        FOR UPDATE OF c`,
      [payload.cid, digest],
    );
    const row = result.rows[0];
    if (!row || row.revoked_at || row.employment_status !== 'active') return null;
    if (new Date(row.expires_at).getTime() <= Date.now()) return null;
    if (row.signing_key_id !== payload.kid) return null;

    await client.query(
      'UPDATE staff_badge_credentials SET last_verified_at=now() WHERE id=$1',
      [row.id],
    );
    const permissions = await staffPermissions(client, String(row.staff_id));
    await appendAudit(client, {
      actorId: 'preauth-badge-scan',
      actorRole: 'preauth',
      eventType: 'staff.badge.verified',
      entityType: 'StaffBadgeCredential',
      entityId: String(row.id),
      details: { staffId: row.staff_id, staffNumber: row.staff_number },
    });
    return { row, permissions };
  });

  if (!verified) {
    res.status(401).json({ valid: false, error: 'Badge is revoked, expired or not registered.' });
    return;
  }

  res.json({
    valid: true,
    staff: {
      staffNumber: String(verified.row.staff_number),
      displayName: String(verified.row.display_name),
      professionalRegistration: verified.row.professional_registration == null
        ? ''
        : String(verified.row.professional_registration),
      employmentStatus: String(verified.row.employment_status),
      permissions: verified.permissions,
    },
    credential: {
      id: String(verified.row.id),
      expiresAt: new Date(verified.row.expires_at).toISOString(),
      signingKeyId: String(verified.row.signing_key_id),
    },
  });
});

app.use('/v1', authenticate);

app.get('/v1/staff/me', async (req, res) => {
  const subject = req.auth?.staffId ?? '';
  const result = await withTransaction(async (client) => {
    const worker = await findCurrentStaff(client, subject);
    if (!worker) return null;
    return {
      worker,
      permissions: await staffPermissions(client, worker.id),
    };
  });
  if (!result) {
    res.status(404).json({ error: 'Staff account is not registered.' });
    return;
  }
  res.json({
    staffNumber: result.worker.staff_number,
    displayName: result.worker.display_name,
    professionalRegistration: result.worker.professional_registration ?? '',
    employmentStatus: result.worker.employment_status,
    permissions: result.permissions,
  });
});

app.get('/v1/staff/badge', async (req, res) => {
  const subject = req.auth?.staffId ?? '';
  const result = await withTransaction(async (client) => {
    const worker = await findCurrentStaff(client, subject);
    if (!worker) return null;
    let credential = await client.query(
      `SELECT c.*, s.staff_number
         FROM staff_badge_credentials c
         JOIN staff_accounts s ON s.id=c.staff_id
        WHERE c.staff_id=$1 AND c.revoked_at IS NULL AND c.expires_at > now()
        ORDER BY c.issued_at DESC LIMIT 1`,
      [worker.id],
    );

    if (!credential.rows[0] && config.devAuth) {
      await issueCredential(
        client,
        worker,
        subject || worker.id,
        config.staffBadgeDefaultValidDays,
      );
      credential = await client.query(
        `SELECT c.*, s.staff_number
           FROM staff_badge_credentials c
           JOIN staff_accounts s ON s.id=c.staff_id
          WHERE c.staff_id=$1 AND c.revoked_at IS NULL AND c.expires_at > now()
          ORDER BY c.issued_at DESC LIMIT 1`,
        [worker.id],
      );
    }
    if (!credential.rows[0]) return { worker, presentation: null };
    return {
      worker,
      presentation: await presentationForCredential(credential.rows[0]),
    };
  });

  if (!result) {
    res.status(404).json({ error: 'Staff account is not registered.' });
    return;
  }
  if (!result.presentation) {
    res.status(404).json({ error: 'No active signed badge has been issued for this staff member.' });
    return;
  }
  res.json({ badge: result.presentation });
});

const createStaffSchema = z.object({
  identitySubject: z.string().min(1).optional(),
  staffNumber: sixDigitStaffNumber.optional(),
  displayName: z.string().min(2),
  professionalRegistration: z.string().max(80).optional().default(''),
  roles: z.array(z.object({
    facilityId: z.string().min(1),
    role: roleSchema,
  })).min(1),
});

app.post('/v1/staff/accounts', requireRoles('administrator'), async (req, res) => {
  const input = createStaffSchema.parse(req.body);
  const actorId = req.auth?.staffId ?? 'unknown';
  const created = await withTransaction(async (client) => {
    const staffNumber = input.staffNumber ?? await allocateStaffNumber(client);
    const staffId = input.identitySubject ?? `STAFF-${randomUUID()}`;
    const row = await client.query(
      `INSERT INTO staff_accounts(
         id, staff_number, display_name, professional_registration, employment_status
       ) VALUES ($1,$2,$3,$4,'active') RETURNING *`,
      [staffId, staffNumber, input.displayName, input.professionalRegistration],
    );
    for (const permission of input.roles) {
      await client.query(
        `INSERT INTO staff_facility_roles(staff_id, facility_id, role, active)
         VALUES ($1,$2,$3,true)
         ON CONFLICT (staff_id, facility_id, role) DO UPDATE SET active=true`,
        [staffId, permission.facilityId, permission.role],
      );
    }
    await appendAudit(client, {
      actorId,
      actorRole: 'administrator',
      eventType: 'staff.account.created',
      entityType: 'StaffAccount',
      entityId: staffId,
      details: { staffNumber, roles: input.roles },
    });
    return row.rows[0];
  });
  res.status(201).json({
    staff: {
      id: created.id,
      staffNumber: created.staff_number,
      displayName: created.display_name,
      professionalRegistration: created.professional_registration,
    },
  });
});

const issueBadgeSchema = z.object({
  staffNumber: sixDigitStaffNumber,
  validDays: z.number().int().min(1).max(1095).optional(),
});

app.post('/v1/staff/credentials/issue', requireRoles('administrator'), async (req, res) => {
  const input = issueBadgeSchema.parse(req.body);
  const actorId = req.auth?.staffId ?? 'unknown';
  const badge = await withTransaction(async (client) => {
    const worker = await findStaffByNumber(client, input.staffNumber);
    if (!worker) throw new Error('Staff number is not registered.');
    return issueCredential(
      client,
      worker,
      actorId,
      input.validDays ?? config.staffBadgeDefaultValidDays,
    );
  });
  res.status(201).json({ badge });
});

const revokeSchema = z.object({ reason: z.string().min(3).max(240) });

app.post('/v1/staff/credentials/:credentialId/revoke', requireRoles('administrator'), async (req, res) => {
  const input = revokeSchema.parse(req.body);
  const actorId = req.auth?.staffId ?? 'unknown';
  const credentialId = z.string().uuid().parse(req.params.credentialId);
  const revoked = await withTransaction(async (client) => {
    const result = await client.query(
      `UPDATE staff_badge_credentials
          SET revoked_at=now(), revoked_by=$2, revoke_reason=$3
        WHERE id=$1 AND revoked_at IS NULL
        RETURNING staff_id`,
      [credentialId, actorId, input.reason],
    );
    if (!result.rows[0]) return false;
    await appendAudit(client, {
      actorId,
      actorRole: 'administrator',
      eventType: 'staff.badge.revoked',
      entityType: 'StaffBadgeCredential',
      entityId: credentialId,
      reason: input.reason,
      details: { staffId: result.rows[0].staff_id },
    });
    await emitOutbox(client, {
      topic: 'staff-identity',
      entityType: 'StaffBadgeCredential',
      entityId: credentialId,
      payload: { action: 'revoked', staffId: result.rows[0].staff_id },
    });
    return true;
  });
  if (!revoked) {
    res.status(404).json({ error: 'Active credential not found.' });
    return;
  }
  res.json({ revoked: true, credentialId });
});

app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  if (error instanceof z.ZodError) {
    res.status(400).json({ error: 'Invalid request.', issues: error.issues });
    return;
  }
  console.error(error);
  res.status(400).json({ error: error instanceof Error ? error.message : 'Request failed.' });
});

app.listen(config.identityPort, () => {
  console.log(`Medqur staff identity service listening on :${config.identityPort}`);
  console.log(config.devAuth ? 'WARNING: MEDQUR_DEV_AUTH is enabled.' : 'OIDC authentication required for protected identity routes.');
});
