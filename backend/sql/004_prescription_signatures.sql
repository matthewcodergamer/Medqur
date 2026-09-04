ALTER TABLE medication_orders
  ADD COLUMN IF NOT EXISTS signature_payload text,
  ADD COLUMN IF NOT EXISTS signature_sha256 char(64),
  ADD COLUMN IF NOT EXISTS signature_signed_at timestamptz,
  ADD COLUMN IF NOT EXISTS signature_method text,
  ADD COLUMN IF NOT EXISTS signature_version integer NOT NULL DEFAULT 1;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'medication_orders_signature_digest_format'
  ) THEN
    ALTER TABLE medication_orders
      ADD CONSTRAINT medication_orders_signature_digest_format
      CHECK (
        signature_sha256 IS NULL
        OR signature_sha256 ~ '^[0-9a-f]{64}$'
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'medication_orders_signature_bundle'
  ) THEN
    ALTER TABLE medication_orders
      ADD CONSTRAINT medication_orders_signature_bundle
      CHECK (
        (signature_payload IS NULL
          AND signature_sha256 IS NULL
          AND signature_signed_at IS NULL
          AND signature_method IS NULL)
        OR
        (signature_payload IS NOT NULL
          AND signature_sha256 IS NOT NULL
          AND signature_signed_at IS NOT NULL
          AND signature_method IS NOT NULL)
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS medication_orders_signature_sha256_idx
  ON medication_orders(signature_sha256)
  WHERE signature_sha256 IS NOT NULL;

COMMENT ON COLUMN medication_orders.signature_payload IS
  'Normalized vector signature JSON supplied by the authenticated prescriber client. The server verifies its SHA-256 digest before storage.';
COMMENT ON COLUMN medication_orders.signature_method IS
  'Presentation method for the optional visual attestation, e.g. handwritten-vector. Authentication/audit identity remains the authenticated staff account.';
