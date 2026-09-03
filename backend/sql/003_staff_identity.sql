ALTER TABLE staff_accounts
  ADD COLUMN IF NOT EXISTS staff_number char(6);

-- Every health worker gets one human-readable six-digit identifier. Existing
-- prototype rows are migrated without deriving the identifier from role,
-- parish, facility or profession so it stays stable when a worker moves.
DO $$
DECLARE
  worker record;
  candidate text;
BEGIN
  FOR worker IN SELECT id FROM staff_accounts WHERE staff_number IS NULL LOOP
    LOOP
      candidate := (100000 + floor(random() * 900000))::int::text;
      EXIT WHEN NOT EXISTS (
        SELECT 1 FROM staff_accounts WHERE staff_number = candidate
      );
    END LOOP;
    UPDATE staff_accounts SET staff_number = candidate WHERE id = worker.id;
  END LOOP;
END $$;

ALTER TABLE staff_accounts
  ALTER COLUMN staff_number SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS staff_accounts_staff_number_uidx
  ON staff_accounts(staff_number);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'staff_accounts_staff_number_format'
  ) THEN
    ALTER TABLE staff_accounts
      ADD CONSTRAINT staff_accounts_staff_number_format
      CHECK (staff_number ~ '^[0-9]{6}$');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS staff_badge_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id text NOT NULL REFERENCES staff_accounts(id) ON DELETE CASCADE,
  credential_version integer NOT NULL DEFAULT 1,
  issued_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  revoked_by text,
  revoke_reason text,
  qr_sha256 text NOT NULL UNIQUE,
  signing_key_id text NOT NULL,
  created_by text NOT NULL,
  last_verified_at timestamptz,
  CHECK (expires_at > issued_at)
);
CREATE INDEX IF NOT EXISTS staff_badge_credentials_staff_idx
  ON staff_badge_credentials(staff_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS staff_badge_credentials_active_idx
  ON staff_badge_credentials(staff_id, expires_at)
  WHERE revoked_at IS NULL;

-- Development identities used by the public prototype and CI. These are not
-- real Jamaican health-worker identities or professional registrations.
INSERT INTO staff_accounts(id, staff_number, display_name, professional_registration, employment_status)
VALUES
  ('482731', '482731', 'Dr. Maya Brown', 'MCR-204781', 'active'),
  ('615204', '615204', 'Nurse Aaliyah Grant', 'NCR-109388', 'active'),
  ('739182', '739182', 'Pharmacist Jordan Reid', 'PHR-DEMO-2049', 'active')
ON CONFLICT (id) DO UPDATE SET
  staff_number = EXCLUDED.staff_number,
  display_name = EXCLUDED.display_name,
  professional_registration = EXCLUDED.professional_registration,
  employment_status = EXCLUDED.employment_status,
  updated_at = now();

INSERT INTO staff_facility_roles(staff_id, facility_id, role, active)
VALUES
  ('482731', 'MRH', 'doctor', true),
  ('615204', 'MRH', 'nurse', true),
  ('739182', 'MRH', 'pharmacist', true)
ON CONFLICT (staff_id, facility_id, role) DO UPDATE SET active = true;
