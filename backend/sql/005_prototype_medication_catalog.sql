-- Expanded Medqur development medication catalogue.
--
-- These rows exist so search/prescription/pharmacy workflows can be exercised
-- against a realistic range of dosage forms while an authoritative national
-- formulary/regulatory feed is not connected. They are deliberately marked
-- UNVERIFIED and UNREVIEWED and must never be presented as Jamaica-approved.

INSERT INTO medication_products(
  id, generic_name, brand_name, strength, dosage_form, manufacturer, importer,
  formulary_status, approval_status, provenance_source, provenance_reference,
  active
) VALUES
  ('11111111-1111-4111-8111-111111111101','Paracetamol','','500 mg','Tablet','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111102','Amoxicillin','','500 mg','Capsule','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111103','Amoxicillin / Clavulanic acid','','875 mg / 125 mg','Tablet','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111104','Ibuprofen','','400 mg','Tablet','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111105','Azithromycin','','500 mg','Tablet','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111106','Doxycycline','','100 mg','Capsule','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111107','Ceftriaxone','','1 g','Powder for injection vial','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111108','Metformin','','500 mg','Tablet','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111109','Amlodipine','','5 mg','Tablet','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111110','Lisinopril','','10 mg','Tablet','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111111','Omeprazole','','20 mg','Delayed-release capsule','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111112','Cetirizine','','10 mg','Tablet','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111113','Salbutamol','','100 micrograms/actuation','Metered-dose inhaler','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111114','Fluconazole','','150 mg','Capsule','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true),
  ('11111111-1111-4111-8111-111111111115','Oral rehydration salts','','WHO-type sachet','Powder for oral solution','Prototype catalogue','','unreviewed','unverified','medqur_prototype_catalogue','Development search fixture',true)
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
  ('11111111-1111-4111-8111-111111111101','INTERNAL','MEDQUR-DEMO-PARA-500',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111102','INTERNAL','MEDQUR-DEMO-AMOX-500',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111103','INTERNAL','MEDQUR-DEMO-AMOXCLAV-875-125',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111104','INTERNAL','MEDQUR-DEMO-IBUPROFEN-400',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111105','INTERNAL','MEDQUR-DEMO-AZITHRO-500',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111106','INTERNAL','MEDQUR-DEMO-DOXY-100',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111107','INTERNAL','MEDQUR-DEMO-CEFTRIAXONE-1G',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111108','INTERNAL','MEDQUR-DEMO-METFORMIN-500',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111109','INTERNAL','MEDQUR-DEMO-AMLODIPINE-5',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111110','INTERNAL','MEDQUR-DEMO-LISINOPRIL-10',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111111','INTERNAL','MEDQUR-DEMO-OMEPRAZOLE-20',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111112','INTERNAL','MEDQUR-DEMO-CETIRIZINE-10',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111113','INTERNAL','MEDQUR-DEMO-SALBUTAMOL-100',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111114','INTERNAL','MEDQUR-DEMO-FLUCONAZOLE-150',NULL,true,false,'medqur_prototype_catalogue'),
  ('11111111-1111-4111-8111-111111111115','INTERNAL','MEDQUR-DEMO-ORS',NULL,true,false,'medqur_prototype_catalogue')
ON CONFLICT (scheme, value) DO UPDATE SET
  product_id = EXCLUDED.product_id,
  verified = EXCLUDED.verified,
  provenance_source = EXCLUDED.provenance_source;

INSERT INTO medication_ingredients(
  product_id, ingredient_code, ingredient_name, coding_system, strength_text
) VALUES
  ('11111111-1111-4111-8111-111111111101','DEMO-PARACETAMOL','Paracetamol','medqur-demo','500 mg'),
  ('11111111-1111-4111-8111-111111111102','DEMO-AMOXICILLIN','Amoxicillin','medqur-demo','500 mg'),
  ('11111111-1111-4111-8111-111111111103','DEMO-AMOXICILLIN','Amoxicillin','medqur-demo','875 mg'),
  ('11111111-1111-4111-8111-111111111103','DEMO-CLAVULANATE','Clavulanic acid','medqur-demo','125 mg'),
  ('11111111-1111-4111-8111-111111111104','DEMO-IBUPROFEN','Ibuprofen','medqur-demo','400 mg'),
  ('11111111-1111-4111-8111-111111111105','DEMO-AZITHROMYCIN','Azithromycin','medqur-demo','500 mg'),
  ('11111111-1111-4111-8111-111111111106','DEMO-DOXYCYCLINE','Doxycycline','medqur-demo','100 mg'),
  ('11111111-1111-4111-8111-111111111107','DEMO-CEFTRIAXONE','Ceftriaxone','medqur-demo','1 g'),
  ('11111111-1111-4111-8111-111111111108','DEMO-METFORMIN','Metformin','medqur-demo','500 mg'),
  ('11111111-1111-4111-8111-111111111109','DEMO-AMLODIPINE','Amlodipine','medqur-demo','5 mg'),
  ('11111111-1111-4111-8111-111111111110','DEMO-LISINOPRIL','Lisinopril','medqur-demo','10 mg'),
  ('11111111-1111-4111-8111-111111111111','DEMO-OMEPRAZOLE','Omeprazole','medqur-demo','20 mg'),
  ('11111111-1111-4111-8111-111111111112','DEMO-CETIRIZINE','Cetirizine','medqur-demo','10 mg'),
  ('11111111-1111-4111-8111-111111111113','DEMO-SALBUTAMOL','Salbutamol','medqur-demo','100 micrograms/actuation'),
  ('11111111-1111-4111-8111-111111111114','DEMO-FLUCONAZOLE','Fluconazole','medqur-demo','150 mg')
ON CONFLICT (product_id, ingredient_code) DO UPDATE SET
  ingredient_name = EXCLUDED.ingredient_name,
  coding_system = EXCLUDED.coding_system,
  strength_text = EXCLUDED.strength_text;
