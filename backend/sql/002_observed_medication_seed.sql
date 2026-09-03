-- Medqur prototype medication seed.
--
-- These records are grounded in physical packages supplied during prototype
-- testing. They make the local PostgreSQL medication registry immediately
-- usable for scanner demonstrations, but they are deliberately NOT marked as
-- clinically verified or Jamaica formulary-approved. A pharmacist/authorized
-- national medication-master process must promote records before production use.

INSERT INTO medication_products(
  id, generic_name, brand_name, strength, dosage_form, manufacturer, importer,
  formulary_status, approval_status, provenance_source, provenance_reference,
  active
) VALUES
  (
    '11111111-1111-4111-8111-111111111001',
    'Pregabalin',
    'Neurobalin-75',
    '75 mg',
    'Capsule',
    'Indus Life Sciences Pvt. Ltd.',
    '',
    'unreviewed',
    'unverified',
    'prototype_observed_package',
    'Physical Neurobalin-75 package supplied for Medqur scanner testing',
    true
  ),
  (
    '11111111-1111-4111-8111-111111111002',
    'Cefuroxime axetil',
    'CEFUR',
    '500 mg',
    'Tablet',
    'Ryvis Pharma',
    '',
    'unreviewed',
    'unverified',
    'prototype_observed_package',
    'Physical CEFUR 500 mg package supplied for Medqur scanner testing',
    true
  ),
  (
    '11111111-1111-4111-8111-111111111003',
    'Guaifenesin / Dextromethorphan HBr',
    'Mucinex DM Maximum Strength',
    '1200 mg / 60 mg',
    'Extended-release tablet',
    '',
    '',
    'unreviewed',
    'unverified',
    'prototype_observed_package',
    'Physical Mucinex DM Maximum Strength package supplied for Medqur scanner testing',
    true
  )
ON CONFLICT (id) DO UPDATE SET
  generic_name = EXCLUDED.generic_name,
  brand_name = EXCLUDED.brand_name,
  strength = EXCLUDED.strength,
  dosage_form = EXCLUDED.dosage_form,
  manufacturer = EXCLUDED.manufacturer,
  provenance_source = EXCLUDED.provenance_source,
  provenance_reference = EXCLUDED.provenance_reference,
  updated_at = now();

INSERT INTO medication_identifiers(
  product_id, scheme, value, normalized_gtin14, primary_identifier,
  verified, provenance_source
) VALUES
  (
    '11111111-1111-4111-8111-111111111001',
    'GTIN',
    '18904215101509',
    '18904215101509',
    true,
    false,
    'prototype_observed_package'
  ),
  (
    '11111111-1111-4111-8111-111111111002',
    'GTIN',
    '18906102700512',
    '18906102700512',
    true,
    false,
    'prototype_observed_package'
  ),
  (
    '11111111-1111-4111-8111-111111111002',
    'EAN',
    '8906102700515',
    '08906102700515',
    false,
    false,
    'prototype_observed_package'
  ),
  (
    '11111111-1111-4111-8111-111111111003',
    'UPC',
    '363824050287',
    '00363824050287',
    true,
    false,
    'prototype_observed_package'
  )
ON CONFLICT (scheme, value) DO UPDATE SET
  product_id = EXCLUDED.product_id,
  normalized_gtin14 = EXCLUDED.normalized_gtin14,
  primary_identifier = EXCLUDED.primary_identifier,
  verified = EXCLUDED.verified,
  provenance_source = EXCLUDED.provenance_source;

INSERT INTO medication_ingredients(
  product_id, ingredient_code, ingredient_name, coding_system, strength_text
) VALUES
  (
    '11111111-1111-4111-8111-111111111001',
    'LOCAL-PREGABALIN',
    'Pregabalin',
    'prototype-local',
    '75 mg'
  ),
  (
    '11111111-1111-4111-8111-111111111002',
    'LOCAL-CEFUROXIME-AXETIL',
    'Cefuroxime axetil',
    'prototype-local',
    '500 mg'
  ),
  (
    '11111111-1111-4111-8111-111111111003',
    'LOCAL-GUAIFENESIN',
    'Guaifenesin',
    'prototype-local',
    '1200 mg'
  ),
  (
    '11111111-1111-4111-8111-111111111003',
    'LOCAL-DEXTROMETHORPHAN-HBR',
    'Dextromethorphan HBr',
    'prototype-local',
    '60 mg'
  )
ON CONFLICT (product_id, ingredient_code) DO UPDATE SET
  ingredient_name = EXCLUDED.ingredient_name,
  coding_system = EXCLUDED.coding_system,
  strength_text = EXCLUDED.strength_text;
