-- V0.12 clinical-order / support-staff workflow.
-- Doctors originate investigations; clinical-support disciplines perform the
-- routed work and return structured results/attachments to the patient record.

ALTER TABLE staff_facility_roles
  DROP CONSTRAINT IF EXISTS staff_facility_roles_role_check;
ALTER TABLE staff_facility_roles
  ADD CONSTRAINT staff_facility_roles_role_check CHECK (role IN (
    'doctor',
    'nurse',
    'triage_nurse',
    'pharmacist',
    'pharmacy_technician',
    'radiology_technologist',
    'ct_technologist',
    'mri_technologist',
    'lab_technologist',
    'ecg_technician',
    'respiratory_therapist',
    'sonographer',
    'clinical_support',
    'administrator'
  ));

CREATE TABLE IF NOT EXISTS diagnostic_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id text NOT NULL REFERENCES patients(id),
  encounter_id text NOT NULL,
  facility_id text NOT NULL REFERENCES facilities(id),
  order_type text NOT NULL CHECK (order_type IN (
    'xray','ct_scan','mri','ultrasound','laboratory','ecg','respiratory','other'
  )),
  study_name text NOT NULL,
  instructions text NOT NULL DEFAULT '',
  priority text NOT NULL DEFAULT 'routine' CHECK (priority IN ('routine','urgent','stat')),
  assigned_discipline text NOT NULL,
  status text NOT NULL DEFAULT 'ordered' CHECK (status IN ('ordered','in_progress','completed','cancelled')),
  ordered_by text NOT NULL,
  ordered_at timestamptz NOT NULL DEFAULT now(),
  started_by text,
  started_at timestamptz,
  completed_by text,
  completed_at timestamptz,
  result_summary text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS diagnostic_orders_facility_status_idx
  ON diagnostic_orders(facility_id, status, priority, ordered_at);
CREATE INDEX IF NOT EXISTS diagnostic_orders_encounter_idx
  ON diagnostic_orders(encounter_id, ordered_at);
CREATE INDEX IF NOT EXISTS diagnostic_orders_discipline_idx
  ON diagnostic_orders(facility_id, assigned_discipline, status);

CREATE TABLE IF NOT EXISTS diagnostic_order_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES diagnostic_orders(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  mime_type text NOT NULL,
  content bytea NOT NULL,
  content_sha256 text NOT NULL,
  uploaded_by text NOT NULL,
  uploaded_at timestamptz NOT NULL DEFAULT now(),
  note text NOT NULL DEFAULT '',
  CHECK (octet_length(content) <= 3145728)
);
CREATE INDEX IF NOT EXISTS diagnostic_order_attachments_order_idx
  ON diagnostic_order_attachments(order_id, uploaded_at);

-- Synthetic development workers used to exercise the routed worklists.
INSERT INTO staff_accounts(id, staff_number, display_name, professional_registration, employment_status)
VALUES
  ('246810', '246810', 'Alexis Clarke', 'RAD-DEMO-3102', 'active'),
  ('357912', '357912', 'Jordan Blake', 'CT-DEMO-4421', 'active'),
  ('468135', '468135', 'Naomi Lewis', 'LAB-DEMO-8840', 'active'),
  ('579246', '579246', 'Samuel Grant', 'ECG-DEMO-1934', 'active')
ON CONFLICT (id) DO UPDATE SET
  staff_number = EXCLUDED.staff_number,
  display_name = EXCLUDED.display_name,
  professional_registration = EXCLUDED.professional_registration,
  employment_status = EXCLUDED.employment_status,
  updated_at = now();

INSERT INTO staff_facility_roles(staff_id, facility_id, role, active)
VALUES
  ('246810', 'MRH', 'radiology_technologist', true),
  ('357912', 'MRH', 'ct_technologist', true),
  ('468135', 'MRH', 'lab_technologist', true),
  ('579246', 'MRH', 'ecg_technician', true)
ON CONFLICT (staff_id, facility_id, role) DO UPDATE SET active = true;
