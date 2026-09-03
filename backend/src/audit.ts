import { createHash } from 'node:crypto';
import type pg from 'pg';
import { pool } from './db.js';

export interface AuditInput {
  actorId: string;
  actorRole: string;
  facilityId?: string | null;
  deviceId?: string | null;
  eventType: string;
  entityType: string;
  entityId: string;
  reason?: string | null;
  details?: Record<string, unknown>;
}

function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.entries(value as Record<string, unknown>)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, item]) => `${JSON.stringify(key)}:${stableJson(item)}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
}

export async function appendAudit(client: pg.PoolClient, input: AuditInput): Promise<string> {
  const previous = await client.query(
    'SELECT event_hash FROM audit_events ORDER BY sequence DESC LIMIT 1 FOR UPDATE',
  );
  const previousHash = previous.rows[0]?.event_hash ? String(previous.rows[0].event_hash) : '';
  const occurredAt = new Date().toISOString();
  const payload = {
    occurredAt,
    actorId: input.actorId,
    actorRole: input.actorRole,
    facilityId: input.facilityId ?? null,
    deviceId: input.deviceId ?? null,
    eventType: input.eventType,
    entityType: input.entityType,
    entityId: input.entityId,
    reason: input.reason ?? null,
    details: input.details ?? {},
  };
  const eventHash = createHash('sha256')
    .update(previousHash)
    .update(stableJson(payload))
    .digest('hex');

  await client.query(
    `INSERT INTO audit_events(
       occurred_at, actor_id, actor_role, facility_id, device_id,
       event_type, entity_type, entity_id, reason, details,
       previous_hash, event_hash
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb,$11,$12)`,
    [
      occurredAt,
      input.actorId,
      input.actorRole,
      input.facilityId ?? null,
      input.deviceId ?? null,
      input.eventType,
      input.entityType,
      input.entityId,
      input.reason ?? null,
      JSON.stringify(input.details ?? {}),
      previousHash || null,
      eventHash,
    ],
  );
  return eventHash;
}

export async function emitOutbox(
  client: pg.PoolClient,
  input: {
    topic: string;
    facilityId?: string | null;
    entityType: string;
    entityId: string;
    payload: Record<string, unknown>;
  },
): Promise<void> {
  const result = await client.query(
    `INSERT INTO outbox_events(topic, facility_id, entity_type, entity_id, payload)
     VALUES ($1,$2,$3,$4,$5::jsonb)
     RETURNING id, created_at`,
    [input.topic, input.facilityId ?? null, input.entityType, input.entityId, JSON.stringify(input.payload)],
  );
  const event = {
    id: result.rows[0]?.id,
    createdAt: result.rows[0]?.created_at,
    ...input,
  };
  await client.query('SELECT pg_notify($1, $2)', ['medqur_events', JSON.stringify(event)]);
}

export class RealtimeHub {
  private listeners = new Set<(event: string) => void>();
  private started = false;

  async start(): Promise<void> {
    if (this.started) return;
    this.started = true;
    const client = await pool.connect();
    await client.query('LISTEN medqur_events');
    client.on('notification', (message) => {
      if (!message.payload) return;
      for (const listener of this.listeners) listener(message.payload);
    });
    client.on('error', (error) => {
      console.error('PostgreSQL realtime listener error', error);
      this.started = false;
      client.release();
    });
  }

  subscribe(listener: (event: string) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}

export const realtimeHub = new RealtimeHub();
