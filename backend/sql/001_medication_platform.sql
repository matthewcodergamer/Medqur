CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS facilities (
  id text PRIMARY KEY,
  name text NOT NULL,
  parish text NOT NULL DEFAULT '',
  classification text NOT NULL DEFAULT 'other',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staff_accounts (
  id text PRIMARY KEY,
  display_name text NOT NULL,
  professional_registration text,
  employment_status text NOT NULL DEFAULT 'active' CHECK (employment_status IN ('active','suspended','ended')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS staff_facility_roles (
  staff_id text NOT NULL REFERENCES staff_accounts(id) ON DELETE CASCADE,
  facility_id text NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('doctor','nurse','triage_nurse','pharmacist','pharmacy_technician','administrator')),
  active boolean NOT NULL DEFAULT true,
  PRIMARY KEY (staff_id, facility_id, role)
);

CREATE TABLE IF NOT EXISTS medication_products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  generic_name text NOT NULL,
  brand_name text NOT NULL DEFAULT '',
  strength text NOT NULL DEFAULT '',
  dosage_form text NOT NULL DEFAULT '',
  manufacturer text NOT NULL DEFAULT '',
  importer text NOT NULL DEFAULT '',
  formulary_status text NOT NULL DEFAULT 'unreviewed' CHECK (formulary_status IN ('unreviewed','approved','restricted','non_formulary','withdrawn')),
  approval_status text NOT NULL DEFAULT 'unverified' CHECK (approval_status IN ('unverified','verified','suspended','withdrawn')),
  provenance_source text NOT NULL,
  provenance_reference text,
  provenance_verified_at timestamptz,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS medication_identifiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES medication_products(id) ON DELETE CASCADE,
  scheme text NOT NULL CHECK (scheme IN ('GTIN','EAN','UPC','NDC','RXCUI','INTERNAL')),
  value text NOT NULL,
  normalized_gtin14 text,
  primary_identifier boolean NOT NULL DEFAULT false,
  verified boolean NOT NULL DEFAULT false,
  provenance_source text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (scheme, value)
);
CREATE INDEX IF NOT EXISTS medication_identifiers_gtin_idx ON medication_identifiers(normalized_gtin14);

CREATE TABLE IF NOT EXISTS medication_ingredients (
  product_id uuid NOT NULL REFERENCES medication_products(id) ON DELETE CASCADE,
  ingredient_code text NOT NULL,
  ingredient_name text NOT NULL,
  coding_system text NOT NULL DEFAULT 'local',
  strength_text text,
  PRIMARY KEY(product_id, ingredient_code)
);
CREATE INDEX IF NOT EXISTS medication_ingredients_code_idx ON medication_ingredients(ingredient_code);

CREATE TABLE IF NOT EXISTS medication_lots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES medication_products(id),
  lot_number text NOT NULL,
  manufacture_date date,
  expiry_date date,
  serial_number text NOT NULL DEFAULT '',
  supplier text NOT NULL DEFAULT '',
  provenance_source text NOT NULL DEFAULT 'pharmacy_receiving',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(product_id, lot_number, serial_number)
);

CREATE TABLE IF NOT EXISTS inventory_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id text NOT NULL REFERENCES facilities(id),
  code text NOT NULL,
  name text NOT NULL,
  location_type text NOT NULL DEFAULT 'pharmacy' CHECK (location_type IN ('pharmacy','ward','emergency','theatre','clinic','quarantine','other')),
  active boolean NOT NULL DEFAULT true,
  UNIQUE(facility_id, code)
);

CREATE TABLE IF NOT EXISTS pharmacy_receipts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id text NOT NULL REFERENCES facilities(id),
  location_id uuid NOT NULL REFERENCES inventory_locations(id),
  product_id uuid NOT NULL REFERENCES medication_products(id),
  lot_id uuid REFERENCES medication_lots(id),
  quantity numeric(14,3) NOT NULL CHECK (quantity > 0),
  unit text NOT NULL DEFAULT 'unit',
  raw_scan text,
  scan_format text,
  received_by text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  verification_status text NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending','verified','quarantined','rejected')),
  verified_by text,
  verified_at timestamptz
);

CREATE TABLE IF NOT EXISTS inventory_balances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id text NOT NULL REFERENCES facilities(id),
  location_id uuid NOT NULL REFERENCES inventory_locations(id),
  product_id uuid NOT NULL REFERENCES medication_products(id),
  lot_id uuid REFERENCES medication_lots(id),
  quantity numeric(14,3) NOT NULL DEFAULT 0,
  unit text NOT NULL DEFAULT 'unit',
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS inventory_balances_unique_idx
  ON inventory_balances(facility_id, location_id, product_id, COALESCE(lot_id, '00000000-0000-0000-0000-000000000000'::uuid));

CREATE TABLE IF NOT EXISTS patients (
  id text PRIMARY KEY,
  encounter_id text,
  display_name text NOT NULL DEFAULT '',
  date_of_birth date,
  sex text NOT NULL DEFAULT '',
  facility_id text REFERENCES facilities(id),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patient_allergies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id text NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
  substance_code text,
  substance_display text NOT NULL,
  reaction text,
  severity text CHECK (severity IS NULL OR severity IN ('mild','moderate','severe')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','entered_in_error')),
  source text NOT NULL,
  verified boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS medication_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id text NOT NULL REFERENCES patients(id),
  encounter_id text NOT NULL,
  facility_id text NOT NULL REFERENCES facilities(id),
  product_id uuid REFERENCES medication_products(id),
  medication_text text NOT NULL,
  dose text NOT NULL,
  route text NOT NULL,
  frequency text NOT NULL,
  ordered_by text NOT NULL,
  ordered_at timestamptz NOT NULL DEFAULT now(),
  due_at timestamptz,
  early_grace_minutes integer NOT NULL DEFAULT 30 CHECK (early_grace_minutes >= 0),
  late_grace_minutes integer NOT NULL DEFAULT 60 CHECK (late_grace_minutes >= 0),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','active','on_hold','cancelled','completed')),
  version integer NOT NULL DEFAULT 1,
  fhir_id text,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS medication_orders_due_idx ON medication_orders(facility_id, due_at) WHERE status = 'active';

CREATE TABLE IF NOT EXISTS medication_dispenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES medication_orders(id),
  facility_id text NOT NULL REFERENCES facilities(id),
  product_id uuid NOT NULL REFERENCES medication_products(id),
  lot_id uuid REFERENCES medication_lots(id),
  quantity numeric(14,3) NOT NULL CHECK (quantity > 0),
  unit text NOT NULL DEFAULT 'unit',
  dispensed_by text NOT NULL,
  verified_by text,
  status text NOT NULL DEFAULT 'prepared' CHECK (status IN ('prepared','verified','released','cancelled')),
  dispensed_at timestamptz NOT NULL DEFAULT now(),
  fhir_id text
);

CREATE TABLE IF NOT EXISTS medication_administrations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES medication_orders(id),
  dispense_id uuid REFERENCES medication_dispenses(id),
  patient_id text NOT NULL REFERENCES patients(id),
  encounter_id text NOT NULL,
  facility_id text NOT NULL REFERENCES facilities(id),
  product_id uuid REFERENCES medication_products(id),
  lot_id uuid REFERENCES medication_lots(id),
  administered_by text NOT NULL,
  administered_at timestamptz NOT NULL DEFAULT now(),
  scheduled_for timestamptz,
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('completed','held','refused','not_done','entered_in_error')),
  raw_medication_scan text,
  raw_patient_scan text,
  override_reason text,
  fhir_id text
);
CREATE INDEX IF NOT EXISTS medication_administrations_order_idx ON medication_administrations(order_id, administered_at DESC);

CREATE TABLE IF NOT EXISTS drug_interaction_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_a text NOT NULL,
  ingredient_b text NOT NULL,
  severity text NOT NULL CHECK (severity IN ('info','minor','moderate','major','contraindicated')),
  description text NOT NULL,
  action text NOT NULL,
  knowledge_source text NOT NULL,
  source_version text NOT NULL,
  clinically_approved boolean NOT NULL DEFAULT false,
  active boolean NOT NULL DEFAULT true,
  UNIQUE(ingredient_a, ingredient_b, knowledge_source, source_version)
);

CREATE TABLE IF NOT EXISTS medication_recalls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  gtin14 text,
  product_id uuid REFERENCES medication_products(id),
  lot_number text,
  serial_number text,
  severity text NOT NULL DEFAULT 'notice' CHECK (severity IN ('notice','urgent','critical')),
  reason text NOT NULL,
  source text NOT NULL,
  source_reference text,
  active boolean NOT NULL DEFAULT true,
  effective_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);
CREATE INDEX IF NOT EXISTS medication_recalls_lookup_idx ON medication_recalls(gtin14, lot_number) WHERE active;

CREATE TABLE IF NOT EXISTS unit_dose_labels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id text NOT NULL REFERENCES facilities(id),
  product_id uuid NOT NULL REFERENCES medication_products(id),
  lot_id uuid REFERENCES medication_lots(id),
  dispense_id uuid REFERENCES medication_dispenses(id),
  internal_token text NOT NULL UNIQUE,
  code_type text NOT NULL DEFAULT 'DataMatrix',
  generated_by text NOT NULL,
  generated_at timestamptz NOT NULL DEFAULT now(),
  voided_at timestamptz
);

CREATE TABLE IF NOT EXISTS catalog_releases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version bigint NOT NULL UNIQUE,
  payload jsonb NOT NULL,
  payload_sha256 text NOT NULL,
  signature_base64 text,
  signing_key_id text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','revoked')),
  created_by text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz
);

CREATE TABLE IF NOT EXISTS registered_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id text NOT NULL REFERENCES facilities(id),
  device_name text NOT NULL,
  device_type text NOT NULL CHECK (device_type IN ('mobile','tablet','workstation','handheld_scanner','print_bridge')),
  scanner_profile text,
  public_key text,
  active boolean NOT NULL DEFAULT true,
  last_seen_at timestamptz,
  UNIQUE(facility_id, device_name)
);

CREATE TABLE IF NOT EXISTS print_destinations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id text NOT NULL REFERENCES facilities(id),
  name text NOT NULL,
  printer_type text NOT NULL CHECK (printer_type IN ('laser_pdf','zebra_zpl','windows_queue','airprint','other')),
  queue_name text,
  network_address text,
  media_type text NOT NULL DEFAULT 'label',
  active boolean NOT NULL DEFAULT true,
  UNIQUE(facility_id, name)
);

CREATE TABLE IF NOT EXISTS audit_events (
  sequence bigserial PRIMARY KEY,
  id uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  actor_id text NOT NULL,
  actor_role text NOT NULL,
  facility_id text,
  device_id uuid,
  event_type text NOT NULL,
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  reason text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  previous_hash text,
  event_hash text NOT NULL
);

CREATE OR REPLACE FUNCTION prevent_audit_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'audit_events is append-only';
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS audit_events_no_update ON audit_events;
CREATE TRIGGER audit_events_no_update BEFORE UPDATE OR DELETE ON audit_events
FOR EACH ROW EXECUTE FUNCTION prevent_audit_mutation();

CREATE TABLE IF NOT EXISTS outbox_events (
  id bigserial PRIMARY KEY,
  topic text NOT NULL,
  facility_id text,
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS outbox_events_created_idx ON outbox_events(created_at DESC);

CREATE OR REPLACE VIEW active_recall_impact AS
SELECT
  r.id AS recall_id,
  r.severity,
  r.reason,
  r.gtin14,
  r.lot_number,
  p.id AS product_id,
  p.generic_name,
  p.brand_name,
  i.facility_id,
  i.location_id,
  i.quantity AS inventory_quantity,
  a.patient_id,
  a.encounter_id,
  a.administered_at
FROM medication_recalls r
LEFT JOIN medication_identifiers mi
  ON r.gtin14 IS NOT NULL AND mi.normalized_gtin14 = r.gtin14
LEFT JOIN medication_products p
  ON p.id = COALESCE(r.product_id, mi.product_id)
LEFT JOIN medication_lots l
  ON l.product_id = p.id AND (r.lot_number IS NULL OR l.lot_number = r.lot_number)
LEFT JOIN inventory_balances i
  ON i.product_id = p.id AND (l.id IS NULL OR i.lot_id = l.id)
LEFT JOIN medication_administrations a
  ON a.product_id = p.id AND (l.id IS NULL OR a.lot_id = l.id)
WHERE r.active = true;

INSERT INTO facilities(id, name, parish, classification)
VALUES ('MRH', 'Mandeville Regional Hospital', 'Manchester', 'type_b_hospital')
ON CONFLICT (id) DO NOTHING;

INSERT INTO inventory_locations(facility_id, code, name, location_type)
VALUES ('MRH', 'MAIN-PHARM', 'Main Pharmacy', 'pharmacy')
ON CONFLICT (facility_id, code) DO NOTHING;
