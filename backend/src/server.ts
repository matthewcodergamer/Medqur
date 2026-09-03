import { createHash, createPrivateKey, randomUUID, sign as cryptoSign } from 'node:crypto';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import * as bwipjs from 'bwip-js';
import { z } from 'zod';

import { appendAudit, emitOutbox, realtimeHub } from './audit.js';
import { authenticate, requireFacility, requireRoles } from './auth.js';
import { config } from './config.js';
import { healthCheck, pool, withTransaction } from './db.js';
import {
  bundle,
  medicationAdministrationResource,
  medicationDispenseResource,
  medicationRequestResource,
  medicationResource,
} from './fhir.js';

const app = express();
app.disable('x-powered-by');
app.use(helmet());
app.use(cors({ origin: false }));
app.use(express.json({ limit: '1mb' }));

function gtin14(value: string | undefined): string | null {
  if (!value) return null;
  const digits = value.replace(/\D/g, '');
  if (![8, 12, 13, 14].includes(digits.length)) return null;
  return digits.padStart(14, '0');
}

function role(req: express.Request): string {
  return req.auth?.roles[0] ?? 'unknown';
}

function staff(req: express.Request): string {
  return req.auth?.staffId ?? 'unknown';
}

function parseDate(value?: string | null): string | null {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? null : date.toISOString().slice(0, 10);
}

app.get('/health', async (_req, res) => {
  try {
    res.json({ ok: await healthCheck(), service: 'medqur-pharmacy', version: '0.9.0' });
  } catch (error) {
    res.status(503).json({ ok: false, error: String(error) });
  }
});

app.use('/v1', authenticate);

app.get('/v1/medications/resolve', async (req, res) => {
  const normalized = gtin14(String(req.query.gtin ?? ''));
  const raw = String(req.query.raw ?? '').trim();
  if (!normalized && !raw) {
    res.status(400).json({ error: 'gtin or raw is required.' });
    return;
  }

  const result = await pool.query(
    `SELECT p.*,
            COALESCE(json_agg(DISTINCT jsonb_build_object(
              'scheme', i.scheme,
              'value', i.value,
              'gtin14', i.normalized_gtin14,
              'verified', i.verified
            )) FILTER (WHERE i.id IS NOT NULL), '[]') AS identifiers,
            COALESCE(json_agg(DISTINCT jsonb_build_object(
              'code', ing.ingredient_code,
              'name', ing.ingredient_name,
              'system', ing.coding_system,
              'strength', ing.strength_text
            )) FILTER (WHERE ing.product_id IS NOT NULL), '[]') AS ingredients
       FROM medication_products p
       LEFT JOIN medication_identifiers i ON i.product_id = p.id
       LEFT JOIN medication_ingredients ing ON ing.product_id = p.id
      WHERE p.active = true
        AND (
          ($1::text IS NOT NULL AND i.normalized_gtin14 = $1)
          OR ($2::text <> '' AND i.value = $2)
        )
      GROUP BY p.id
      LIMIT 1`,
    [normalized, raw],
  );

  if (result.rowCount === 0) {
    res.status(404).json({
      found: false,
      verified: false,
      source: 'Medqur medication master',
      message: normalized
        ? `GTIN ${normalized} is not present in the configured medication master.`
        : 'The scanned identifier is not present in the configured medication master.',
    });
    return;
  }

  const p = result.rows[0];
  const verified = p.approval_status === 'verified';
  res.json({
    found: true,
    verified,
    source: p.provenance_source,
    product: {
      id: p.id,
      genericName: p.generic_name,
      brandName: p.brand_name,
      strength: p.strength,
      dosageForm: p.dosage_form,
      manufacturer: p.manufacturer,
      importer: p.importer,
      formularyStatus: p.formulary_status,
      approvalStatus: p.approval_status,
      gtins: (p.identifiers as Array<Record<string, unknown>>)
        .map((item) => item.gtin14)
        .filter(Boolean),
      identifiers: p.identifiers,
      ingredients: p.ingredients,
      verified,
      jamaicaReference: p.provenance_reference,
    },
  });
});

app.get('/v1/medications/search', async (req, res) => {
  const query = String(req.query.q ?? '').trim();
  if (query.length < 2) {
    res.json({ results: [] });
    return;
  }
  const result = await pool.query(
    `SELECT p.id, p.generic_name, p.brand_name, p.strength, p.dosage_form,
            p.manufacturer, p.formulary_status, p.approval_status,
            p.provenance_source
       FROM medication_products p
      WHERE p.active = true
        AND (p.generic_name ILIKE $1 OR p.brand_name ILIKE $1)
      ORDER BY
        CASE WHEN lower(p.generic_name) = lower($2) THEN 0 ELSE 1 END,
        p.generic_name
      LIMIT 25`,
    [`%${query}%`, query],
  );
  res.json({ results: result.rows });
});

const productUpsertSchema = z.object({
  genericName: z.string().min(1),
  brandName: z.string().default(''),
  strength: z.string().default(''),
  dosageForm: z.string().default(''),
  manufacturer: z.string().default(''),
  importer: z.string().default(''),
  formularyStatus: z.enum(['unreviewed', 'approved', 'restricted', 'non_formulary', 'withdrawn']).default('unreviewed'),
  approvalStatus: z.enum(['unverified', 'verified', 'suspended', 'withdrawn']).default('unverified'),
  provenanceSource: z.string().min(1),
  provenanceReference: z.string().optional(),
  identifiers: z.array(z.object({
    scheme: z.enum(['GTIN', 'EAN', 'UPC', 'NDC', 'RXCUI', 'INTERNAL']),
    value: z.string().min(1),
    verified: z.boolean().default(false),
  })).default([]),
  ingredients: z.array(z.object({
    code: z.string().min(1),
    name: z.string().min(1),
    system: z.string().default('local'),
    strength: z.string().optional(),
  })).default([]),
});

app.post(
  '/v1/medications',
  requireRoles('pharmacist', 'administrator'),
  async (req, res) => {
    const input = productUpsertSchema.parse(req.body);
    const product = await withTransaction(async (client) => {
      const inserted = await client.query(
        `INSERT INTO medication_products(
          generic_name, brand_name, strength, dosage_form, manufacturer, importer,
          formulary_status, approval_status, provenance_source, provenance_reference,
          provenance_verified_at
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
        RETURNING *`,
        [
          input.genericName,
          input.brandName,
          input.strength,
          input.dosageForm,
          input.manufacturer,
          input.importer,
          input.formularyStatus,
          input.approvalStatus,
          input.provenanceSource,
          input.provenanceReference ?? null,
          input.approvalStatus === 'verified' ? new Date().toISOString() : null,
        ],
      );
      const row = inserted.rows[0];
      for (const identifier of input.identifiers) {
        const normalized = identifier.scheme === 'GTIN' || identifier.scheme === 'EAN' || identifier.scheme === 'UPC'
          ? gtin14(identifier.value)
          : null;
        await client.query(
          `INSERT INTO medication_identifiers(product_id, scheme, value, normalized_gtin14, verified, provenance_source)
           VALUES ($1,$2,$3,$4,$5,$6)
           ON CONFLICT (scheme, value) DO UPDATE SET
             product_id = EXCLUDED.product_id,
             normalized_gtin14 = EXCLUDED.normalized_gtin14,
             verified = EXCLUDED.verified,
             provenance_source = EXCLUDED.provenance_source`,
          [row.id, identifier.scheme, identifier.value, normalized, identifier.verified, input.provenanceSource],
        );
      }
      for (const ingredient of input.ingredients) {
        await client.query(
          `INSERT INTO medication_ingredients(product_id, ingredient_code, ingredient_name, coding_system, strength_text)
           VALUES ($1,$2,$3,$4,$5)
           ON CONFLICT (product_id, ingredient_code) DO UPDATE SET
             ingredient_name = EXCLUDED.ingredient_name,
             coding_system = EXCLUDED.coding_system,
             strength_text = EXCLUDED.strength_text`,
          [row.id, ingredient.code, ingredient.name, ingredient.system, ingredient.strength ?? null],
        );
      }
      await appendAudit(client, {
        actorId: staff(req),
        actorRole: role(req),
        eventType: 'medication.product.created',
        entityType: 'Medication',
        entityId: String(row.id),
        details: { approvalStatus: input.approvalStatus, provenance: input.provenanceSource },
      });
      await emitOutbox(client, {
        topic: 'medication-master',
        entityType: 'Medication',
        entityId: String(row.id),
        payload: { action: 'created', productId: row.id },
      });
      return row;
    });
    res.status(201).json({ product });
  },
);

const receiveSchema = z.object({
  facilityId: z.string().min(1),
  locationCode: z.string().min(1).default('MAIN-PHARM'),
  productId: z.string().uuid().optional(),
  gtin: z.string().optional(),
  lotNumber: z.string().min(1),
  manufactureDate: z.string().optional(),
  expiryDate: z.string().optional(),
  serialNumber: z.string().default(''),
  supplier: z.string().default(''),
  quantity: z.number().positive(),
  unit: z.string().default('unit'),
  rawScan: z.string().optional(),
  scanFormat: z.string().optional(),
});

app.post(
  '/v1/pharmacy/receive',
  requireRoles('pharmacist', 'pharmacy_technician', 'administrator'),
  async (req, res) => {
    const input = receiveSchema.parse(req.body);
    if (!requireFacility(req, res, input.facilityId)) return;
    const normalized = gtin14(input.gtin);

    const receipt = await withTransaction(async (client) => {
      let productId = input.productId ?? null;
      if (!productId && normalized) {
        const matched = await client.query(
          `SELECT product_id FROM medication_identifiers WHERE normalized_gtin14 = $1 LIMIT 1`,
          [normalized],
        );
        productId = matched.rows[0]?.product_id ?? null;
      }
      if (!productId) throw new Error('Product is not in the medication master. Pharmacist verification is required before receiving stock.');

      const location = await client.query(
        `SELECT id FROM inventory_locations WHERE facility_id = $1 AND code = $2 AND active = true LIMIT 1`,
        [input.facilityId, input.locationCode],
      );
      if (!location.rows[0]?.id) throw new Error('Inventory location was not found.');

      const lot = await client.query(
        `INSERT INTO medication_lots(product_id, lot_number, manufacture_date, expiry_date, serial_number, supplier)
         VALUES ($1,$2,$3,$4,$5,$6)
         ON CONFLICT (product_id, lot_number, serial_number) DO UPDATE SET
           manufacture_date = COALESCE(EXCLUDED.manufacture_date, medication_lots.manufacture_date),
           expiry_date = COALESCE(EXCLUDED.expiry_date, medication_lots.expiry_date),
           supplier = CASE WHEN EXCLUDED.supplier <> '' THEN EXCLUDED.supplier ELSE medication_lots.supplier END
         RETURNING id`,
        [
          productId,
          input.lotNumber,
          parseDate(input.manufactureDate),
          parseDate(input.expiryDate),
          input.serialNumber,
          input.supplier,
        ],
      );
      const lotId = lot.rows[0].id;
      const created = await client.query(
        `INSERT INTO pharmacy_receipts(
           facility_id, location_id, product_id, lot_id, quantity, unit,
           raw_scan, scan_format, received_by
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
         RETURNING *`,
        [
          input.facilityId,
          location.rows[0].id,
          productId,
          lotId,
          input.quantity,
          input.unit,
          input.rawScan ?? null,
          input.scanFormat ?? null,
          staff(req),
        ],
      );
      await client.query(
        `INSERT INTO inventory_balances(facility_id, location_id, product_id, lot_id, quantity, unit)
         VALUES ($1,$2,$3,$4,$5,$6)
         ON CONFLICT (facility_id, location_id, product_id, COALESCE(lot_id, '00000000-0000-0000-0000-000000000000'::uuid))
         DO UPDATE SET quantity = inventory_balances.quantity + EXCLUDED.quantity, updated_at = now()`,
        [input.facilityId, location.rows[0].id, productId, lotId, input.quantity, input.unit],
      );
      const row = created.rows[0];
      await appendAudit(client, {
        actorId: staff(req),
        actorRole: role(req),
        facilityId: input.facilityId,
        eventType: 'pharmacy.stock.received',
        entityType: 'MedicationLot',
        entityId: String(lotId),
        details: { receiptId: row.id, quantity: input.quantity, unit: input.unit, gtin: normalized },
      });
      await emitOutbox(client, {
        topic: 'inventory',
        facilityId: input.facilityId,
        entityType: 'MedicationLot',
        entityId: String(lotId),
        payload: { action: 'received', quantity: input.quantity, productId, receiptId: row.id },
      });
      return row;
    });
    res.status(201).json({ receipt });
  },
);

app.get('/v1/inventory', requireRoles('pharmacist', 'pharmacy_technician', 'administrator', 'nurse'), async (req, res) => {
  const facilityId = String(req.query.facilityId ?? '');
  if (!facilityId || !requireFacility(req, res, facilityId)) return;
  const result = await pool.query(
    `SELECT i.id, i.quantity, i.unit, i.updated_at,
            l.code AS location_code, l.name AS location_name,
            p.id AS product_id, p.generic_name, p.brand_name, p.strength, p.dosage_form,
            p.approval_status, p.formulary_status,
            lot.id AS lot_id, lot.lot_number, lot.expiry_date, lot.serial_number
       FROM inventory_balances i
       JOIN inventory_locations l ON l.id = i.location_id
       JOIN medication_products p ON p.id = i.product_id
       LEFT JOIN medication_lots lot ON lot.id = i.lot_id
      WHERE i.facility_id = $1 AND i.quantity <> 0
      ORDER BY p.generic_name, lot.expiry_date NULLS LAST, l.code`,
    [facilityId],
  );
  res.json({ facilityId, items: result.rows });
});

const verifySchema = z.object({
  facilityId: z.string().min(1),
  productId: z.string().uuid(),
  formularyStatus: z.enum(['approved', 'restricted', 'non_formulary', 'withdrawn']),
  approvalStatus: z.enum(['verified', 'suspended', 'withdrawn']),
  provenanceSource: z.string().min(1),
  provenanceReference: z.string().min(1),
});

app.post('/v1/pharmacy/verify-product', requireRoles('pharmacist', 'administrator'), async (req, res) => {
  const input = verifySchema.parse(req.body);
  if (!requireFacility(req, res, input.facilityId)) return;
  const row = await withTransaction(async (client) => {
    const updated = await client.query(
      `UPDATE medication_products SET
         formulary_status = $2,
         approval_status = $3,
         provenance_source = $4,
         provenance_reference = $5,
         provenance_verified_at = now(),
         updated_at = now()
       WHERE id = $1
       RETURNING *`,
      [input.productId, input.formularyStatus, input.approvalStatus, input.provenanceSource, input.provenanceReference],
    );
    if (!updated.rows[0]) throw new Error('Medication product not found.');
    await appendAudit(client, {
      actorId: staff(req),
      actorRole: role(req),
      facilityId: input.facilityId,
      eventType: 'medication.product.verified',
      entityType: 'Medication',
      entityId: input.productId,
      details: { formularyStatus: input.formularyStatus, approvalStatus: input.approvalStatus, source: input.provenanceSource },
    });
    await emitOutbox(client, {
      topic: 'medication-master',
      facilityId: input.facilityId,
      entityType: 'Medication',
      entityId: input.productId,
      payload: { action: 'verified', approvalStatus: input.approvalStatus },
    });
    return updated.rows[0];
  });
  res.json({ product: row });
});

const orderSchema = z.object({
  patientId: z.string().min(1),
  encounterId: z.string().min(1),
  facilityId: z.string().min(1),
  productId: z.string().uuid().optional(),
  medicationText: z.string().min(1),
  dose: z.string().min(1),
  route: z.string().min(1),
  frequency: z.string().min(1),
  dueAt: z.string().datetime().optional(),
  earlyGraceMinutes: z.number().int().nonnegative().default(30),
  lateGraceMinutes: z.number().int().nonnegative().default(60),
});

app.post('/v1/orders', requireRoles('doctor'), async (req, res) => {
  const input = orderSchema.parse(req.body);
  if (!requireFacility(req, res, input.facilityId)) return;
  const order = await withTransaction(async (client) => {
    await client.query(
      `INSERT INTO patients(id, encounter_id, facility_id)
       VALUES ($1,$2,$3)
       ON CONFLICT (id) DO UPDATE SET encounter_id = EXCLUDED.encounter_id, facility_id = EXCLUDED.facility_id, updated_at = now()`,
      [input.patientId, input.encounterId, input.facilityId],
    );
    const result = await client.query(
      `INSERT INTO medication_orders(
         patient_id, encounter_id, facility_id, product_id, medication_text,
         dose, route, frequency, ordered_by, due_at, early_grace_minutes, late_grace_minutes
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
       RETURNING *`,
      [
        input.patientId,
        input.encounterId,
        input.facilityId,
        input.productId ?? null,
        input.medicationText,
        input.dose,
        input.route,
        input.frequency,
        staff(req),
        input.dueAt ?? null,
        input.earlyGraceMinutes,
        input.lateGraceMinutes,
      ],
    );
    const row = result.rows[0];
    await appendAudit(client, {
      actorId: staff(req), actorRole: role(req), facilityId: input.facilityId,
      eventType: 'medication.order.signed', entityType: 'MedicationRequest', entityId: String(row.id),
      details: { patientId: input.patientId, productId: input.productId ?? null, dueAt: input.dueAt ?? null },
    });
    await emitOutbox(client, {
      topic: 'medication-orders', facilityId: input.facilityId,
      entityType: 'MedicationRequest', entityId: String(row.id),
      payload: { action: 'ordered', orderId: row.id, patientId: input.patientId },
    });
    return row;
  });
  res.status(201).json({ order });
});

const dispenseSchema = z.object({
  orderId: z.string().uuid(),
  facilityId: z.string().min(1),
  locationId: z.string().uuid(),
  productId: z.string().uuid(),
  lotId: z.string().uuid().optional(),
  quantity: z.number().positive(),
  unit: z.string().default('unit'),
});

app.post('/v1/pharmacy/dispense', requireRoles('pharmacist', 'pharmacy_technician'), async (req, res) => {
  const input = dispenseSchema.parse(req.body);
  if (!requireFacility(req, res, input.facilityId)) return;
  const dispense = await withTransaction(async (client) => {
    const product = await client.query('SELECT approval_status, formulary_status FROM medication_products WHERE id = $1', [input.productId]);
    if (product.rows[0]?.approval_status !== 'verified') {
      throw new Error('Medication is not verified in the approved medication master.');
    }
    const balance = await client.query(
      `SELECT id, quantity FROM inventory_balances
        WHERE facility_id=$1 AND location_id=$2 AND product_id=$3
          AND (($4::uuid IS NULL AND lot_id IS NULL) OR lot_id=$4)
        FOR UPDATE`,
      [input.facilityId, input.locationId, input.productId, input.lotId ?? null],
    );
    if (!balance.rows[0] || Number(balance.rows[0].quantity) < input.quantity) {
      throw new Error('Insufficient verified inventory for this dispense.');
    }
    await client.query('UPDATE inventory_balances SET quantity=quantity-$2, updated_at=now() WHERE id=$1', [balance.rows[0].id, input.quantity]);
    const result = await client.query(
      `INSERT INTO medication_dispenses(order_id, facility_id, product_id, lot_id, quantity, unit, dispensed_by, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,'verified') RETURNING *`,
      [input.orderId, input.facilityId, input.productId, input.lotId ?? null, input.quantity, input.unit, staff(req)],
    );
    const row = result.rows[0];
    await appendAudit(client, {
      actorId: staff(req), actorRole: role(req), facilityId: input.facilityId,
      eventType: 'medication.dispensed', entityType: 'MedicationDispense', entityId: String(row.id),
      details: { orderId: input.orderId, productId: input.productId, lotId: input.lotId ?? null, quantity: input.quantity },
    });
    await emitOutbox(client, {
      topic: 'medication-tasks', facilityId: input.facilityId,
      entityType: 'MedicationDispense', entityId: String(row.id),
      payload: { action: 'ready-for-administration', orderId: input.orderId, dispenseId: row.id },
    });
    return row;
  });
  res.status(201).json({ dispense });
});

app.get('/v1/recalls/search', requireRoles('pharmacist', 'administrator'), async (req, res) => {
  const normalized = gtin14(String(req.query.gtin ?? ''));
  const lot = String(req.query.lot ?? '').trim();
  if (!normalized && !lot) {
    res.status(400).json({ error: 'gtin or lot is required.' });
    return;
  }
  const result = await pool.query(
    `SELECT * FROM active_recall_impact
      WHERE ($1::text IS NULL OR gtin14 = $1)
        AND ($2::text = '' OR lot_number = $2)
      ORDER BY severity DESC, administered_at DESC NULLS LAST`,
    [normalized, lot],
  );
  res.json({ gtin: normalized, lot: lot || null, impacts: result.rows });
});

const safetySchema = z.object({
  patientId: z.string().min(1),
  productId: z.string().uuid(),
  currentProductIds: z.array(z.string().uuid()).default([]),
});

app.post('/v1/medications/safety-check', async (req, res) => {
  const input = safetySchema.parse(req.body);
  const allergy = await pool.query(
    `SELECT a.*, i.ingredient_code, i.ingredient_name
       FROM patient_allergies a
       JOIN medication_ingredients i
         ON a.substance_code IS NOT NULL AND i.ingredient_code = a.substance_code
      WHERE a.patient_id=$1 AND a.status='active' AND i.product_id=$2`,
    [input.patientId, input.productId],
  );
  const ingredientResult = await pool.query(
    'SELECT ingredient_code, ingredient_name FROM medication_ingredients WHERE product_id=$1',
    [input.productId],
  );
  const currentIngredients = input.currentProductIds.length === 0
    ? { rows: [] as Array<Record<string, unknown>> }
    : await pool.query(
        'SELECT product_id, ingredient_code, ingredient_name FROM medication_ingredients WHERE product_id = ANY($1::uuid[])',
        [input.currentProductIds],
      );
  const candidateCodes = ingredientResult.rows.map((row) => row.ingredient_code);
  const currentCodes = currentIngredients.rows.map((row) => row.ingredient_code);
  const interactions = candidateCodes.length === 0 || currentCodes.length === 0
    ? { rows: [] as Array<Record<string, unknown>> }
    : await pool.query(
        `SELECT * FROM drug_interaction_rules
          WHERE active=true
            AND ((ingredient_a = ANY($1::text[]) AND ingredient_b = ANY($2::text[]))
              OR (ingredient_b = ANY($1::text[]) AND ingredient_a = ANY($2::text[])))`,
        [candidateCodes, currentCodes],
      );
  const approvedSevere = interactions.rows.filter((row) => row.clinically_approved && ['major', 'contraindicated'].includes(row.severity));
  res.json({
    allowed: allergy.rows.length === 0 && approvedSevere.length === 0,
    allergies: allergy.rows,
    interactions: interactions.rows,
    note: 'Interaction rules only become blocking clinical knowledge when clinically_approved=true and carry an approved source/version.',
  });
});

const administrationSchema = z.object({
  orderId: z.string().uuid(),
  dispenseId: z.string().uuid().optional(),
  patientId: z.string().min(1),
  encounterId: z.string().min(1),
  facilityId: z.string().min(1),
  productId: z.string().uuid(),
  lotId: z.string().uuid().optional(),
  patientScan: z.string().min(1),
  medicationScan: z.string().min(1),
  overrideReason: z.string().optional(),
});

app.post('/v1/administrations', requireRoles('nurse'), async (req, res) => {
  const input = administrationSchema.parse(req.body);
  if (!requireFacility(req, res, input.facilityId)) return;
  const result = await withTransaction(async (client) => {
    const orderResult = await client.query('SELECT * FROM medication_orders WHERE id=$1 FOR UPDATE', [input.orderId]);
    const order = orderResult.rows[0];
    if (!order || order.status !== 'active') throw new Error('Medication order is not active.');
    if (order.patient_id !== input.patientId || order.encounter_id !== input.encounterId) throw new Error('Patient/encounter does not match the medication order.');
    if (order.product_id && String(order.product_id) !== input.productId) throw new Error('Scanned medication does not match the ordered product.');

    const duplicate = await client.query(
      `SELECT id FROM medication_administrations
        WHERE order_id=$1 AND status='completed'
          AND administered_at > now() - interval '4 hours'
        LIMIT 1`,
      [input.orderId],
    );
    if (duplicate.rowCount && duplicate.rowCount > 0) throw new Error('Duplicate administration protection: this order was already administered recently.');

    if (order.due_at) {
      const due = new Date(order.due_at).getTime();
      const now = Date.now();
      const earliest = due - Number(order.early_grace_minutes) * 60_000;
      const latest = due + Number(order.late_grace_minutes) * 60_000;
      if (now < earliest && !input.overrideReason) throw new Error('Medication is earlier than the configured administration window.');
      if (now > latest && !input.overrideReason) throw new Error('Medication is outside the configured late administration window.');
    }

    const created = await client.query(
      `INSERT INTO medication_administrations(
         order_id, dispense_id, patient_id, encounter_id, facility_id, product_id, lot_id,
         administered_by, scheduled_for, raw_medication_scan, raw_patient_scan, override_reason
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
       RETURNING *`,
      [
        input.orderId, input.dispenseId ?? null, input.patientId, input.encounterId,
        input.facilityId, input.productId, input.lotId ?? null, staff(req), order.due_at,
        input.medicationScan, input.patientScan, input.overrideReason ?? null,
      ],
    );
    const row = created.rows[0];
    await appendAudit(client, {
      actorId: staff(req), actorRole: role(req), facilityId: input.facilityId,
      eventType: 'medication.administered', entityType: 'MedicationAdministration', entityId: String(row.id),
      reason: input.overrideReason ?? null,
      details: { orderId: input.orderId, patientId: input.patientId, productId: input.productId, lotId: input.lotId ?? null },
    });
    await emitOutbox(client, {
      topic: 'medication-administrations', facilityId: input.facilityId,
      entityType: 'MedicationAdministration', entityId: String(row.id),
      payload: { action: 'administered', orderId: input.orderId, patientId: input.patientId },
    });
    return row;
  });
  res.status(201).json({ administration: result });
});

const unitDoseSchema = z.object({
  facilityId: z.string().min(1),
  productId: z.string().uuid(),
  lotId: z.string().uuid().optional(),
  dispenseId: z.string().uuid().optional(),
  existingUnitCode: z.string().optional(),
});

app.post('/v1/labels/unit-dose', requireRoles('pharmacist', 'pharmacy_technician'), async (req, res) => {
  const input = unitDoseSchema.parse(req.body);
  if (!requireFacility(req, res, input.facilityId)) return;
  if (input.existingUnitCode?.trim()) {
    res.status(409).json({
      error: 'The individual dose already has a machine-readable manufacturer code. Use the existing code instead of creating a competing Medqur label.',
    });
    return;
  }

  const token = `MQUD|${randomUUID()}`;
  const created = await withTransaction(async (client) => {
    const result = await client.query(
      `INSERT INTO unit_dose_labels(facility_id, product_id, lot_id, dispense_id, internal_token, generated_by)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [input.facilityId, input.productId, input.lotId ?? null, input.dispenseId ?? null, token, staff(req)],
    );
    await appendAudit(client, {
      actorId: staff(req), actorRole: role(req), facilityId: input.facilityId,
      eventType: 'medication.unit-dose-label.created', entityType: 'Medication', entityId: input.productId,
      details: { labelId: result.rows[0].id, lotId: input.lotId ?? null },
    });
    return result.rows[0];
  });

  const dataMatrixSvg = bwipjs.toSVG({
    bcid: 'datamatrix',
    text: token,
    scale: 4,
    includetext: false,
    padding: 2,
  });
  const zpl = `^XA^PW600^LL260^FO30,25^BXN,8,200^FD${token}^FS^FO230,35^A0N,30,30^FDMEDQUR UNIT DOSE^FS^FO230,78^A0N,22,22^FDProduct ${input.productId}^FS^FO230,112^A0N,20,20^FDLot ${input.lotId ?? 'N/A'}^FS^FO30,215^A0N,18,18^FDInternal hospital code - verify against medication master^FS^XZ`;
  res.status(201).json({ label: created, codeValue: token, codeType: 'DataMatrix', dataMatrixSvg, zpl });
});

app.get('/v1/recalls/:recallId/impact', requireRoles('pharmacist', 'administrator'), async (req, res) => {
  const result = await pool.query('SELECT * FROM active_recall_impact WHERE recall_id=$1', [req.params.recallId]);
  res.json({ recallId: req.params.recallId, impacts: result.rows });
});

app.get('/v1/fhir/medications', async (_req, res) => {
  const result = await pool.query('SELECT * FROM medication_products WHERE active=true ORDER BY generic_name');
  res.json(bundle(result.rows.map(medicationResource)));
});

app.get('/v1/fhir/encounters/:encounterId/medications', async (req, res) => {
  const orders = await pool.query('SELECT * FROM medication_orders WHERE encounter_id=$1 ORDER BY ordered_at', [req.params.encounterId]);
  const dispenses = await pool.query(
    `SELECT d.* FROM medication_dispenses d JOIN medication_orders o ON o.id=d.order_id WHERE o.encounter_id=$1 ORDER BY d.dispensed_at`,
    [req.params.encounterId],
  );
  const administrations = await pool.query('SELECT * FROM medication_administrations WHERE encounter_id=$1 ORDER BY administered_at', [req.params.encounterId]);
  res.json(bundle([
    ...orders.rows.map(medicationRequestResource),
    ...dispenses.rows.map(medicationDispenseResource),
    ...administrations.rows.map(medicationAdministrationResource),
  ]));
});

app.get('/v1/events', async (req, res) => {
  const facilityId = String(req.query.facilityId ?? '');
  if (facilityId && !requireFacility(req, res, facilityId)) return;
  res.status(200);
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();
  res.write(`event: ready\ndata: ${JSON.stringify({ facilityId: facilityId || null })}\n\n`);
  const unsubscribe = realtimeHub.subscribe((event) => {
    try {
      const parsed = JSON.parse(event) as { facilityId?: string | null };
      if (facilityId && parsed.facilityId && parsed.facilityId !== facilityId) return;
    } catch {
      // If an event cannot be parsed, do not leak it to clients.
      return;
    }
    res.write(`event: medqur\ndata: ${event}\n\n`);
  });
  const keepAlive = setInterval(() => res.write(': keep-alive\n\n'), 25_000);
  req.on('close', () => {
    clearInterval(keepAlive);
    unsubscribe();
  });
});

app.get('/v1/catalog/latest', async (_req, res) => {
  const result = await pool.query(
    `SELECT version, payload, payload_sha256, signature_base64, signing_key_id, published_at
       FROM catalog_releases WHERE status='published' ORDER BY version DESC LIMIT 1`,
  );
  if (!result.rows[0]) {
    res.status(404).json({ error: 'No published offline catalog exists.' });
    return;
  }
  res.json(result.rows[0]);
});

app.post('/v1/catalog/publish', requireRoles('administrator'), async (req, res) => {
  if (!config.catalogSigningPrivateKeyPem) {
    res.status(503).json({ error: 'Catalog signing key is not configured.' });
    return;
  }
  const productResult = await pool.query(
    `SELECT p.*, COALESCE(json_agg(jsonb_build_object(
        'scheme', i.scheme, 'value', i.value, 'gtin14', i.normalized_gtin14, 'verified', i.verified
      )) FILTER (WHERE i.id IS NOT NULL), '[]') AS identifiers
       FROM medication_products p
       LEFT JOIN medication_identifiers i ON i.product_id=p.id
      WHERE p.active=true
      GROUP BY p.id ORDER BY p.generic_name`,
  );
  const versionResult = await pool.query('SELECT COALESCE(MAX(version),0)+1 AS version FROM catalog_releases');
  const version = Number(versionResult.rows[0].version);
  const payload = {
    schema: 'medqur.medication-catalog.v1',
    version,
    generatedAt: new Date().toISOString(),
    products: productResult.rows,
  };
  const canonical = JSON.stringify(payload);
  const hash = createHash('sha256').update(canonical).digest('hex');
  const key = createPrivateKey(config.catalogSigningPrivateKeyPem.replace(/\\n/g, '\n'));
  const signature = cryptoSign(null, Buffer.from(canonical), key).toString('base64');
  const release = await withTransaction(async (client) => {
    const result = await client.query(
      `INSERT INTO catalog_releases(version, payload, payload_sha256, signature_base64, signing_key_id, status, created_by, published_at)
       VALUES ($1,$2::jsonb,$3,$4,$5,'published',$6,now()) RETURNING *`,
      [version, canonical, hash, signature, config.catalogSigningKeyId, staff(req)],
    );
    await appendAudit(client, {
      actorId: staff(req), actorRole: role(req), eventType: 'medication.catalog.published',
      entityType: 'MedicationCatalog', entityId: String(version), details: { sha256: hash, signingKeyId: config.catalogSigningKeyId },
    });
    await emitOutbox(client, {
      topic: 'catalog', entityType: 'MedicationCatalog', entityId: String(version),
      payload: { action: 'published', version, sha256: hash },
    });
    return result.rows[0];
  });
  res.status(201).json({ release });
});

app.get('/v1/audit', requireRoles('administrator'), async (req, res) => {
  const limit = Math.min(500, Math.max(1, Number(req.query.limit ?? 100)));
  const result = await pool.query('SELECT * FROM audit_events ORDER BY sequence DESC LIMIT $1', [limit]);
  res.json({ events: result.rows });
});

app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  if (error instanceof z.ZodError) {
    res.status(400).json({ error: 'Invalid request.', issues: error.issues });
    return;
  }
  console.error(error);
  res.status(400).json({ error: error instanceof Error ? error.message : 'Request failed.' });
});

await realtimeHub.start();
app.listen(config.port, () => {
  console.log(`Medqur pharmacy backend listening on :${config.port}`);
  console.log(config.devAuth ? 'WARNING: MEDQUR_DEV_AUTH is enabled.' : 'OIDC authentication required.');
});
