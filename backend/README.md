# Medqur Pharmacy + Medication Master Backend (V0.9)

This backend is the server-side foundation for Medqur's medication master, pharmacy, inventory, recall, medication-administration, audit, realtime, offline-catalog and FHIR workflows.

It is **not a production clinical knowledge base by itself**. A real deployment must load medication/formulary/provenance data from Ministry/regulatory/procurement/pharmacy-approved sources, use an approved drug-allergy/interaction knowledge source, and complete security/privacy validation before clinical use.

## Local development

```bash
cd backend
docker compose up -d postgres
cp .env.example .env
npm install
MEDQUR_DEV_AUTH=true npm run dev
```

The development authentication bypass is intentionally explicit. Never enable `MEDQUR_DEV_AUTH=true` on an internet-facing or clinical environment.

## Production authentication

Production requests use OIDC/JWT verification through a configured JWKS endpoint. Staff roles and facility assignments are then loaded from PostgreSQL. The application does not trust a role supplied by the mobile client.

Supported backend roles:

- doctor
- nurse
- triage_nurse
- pharmacist
- pharmacy_technician
- administrator

## Core APIs

- `GET /v1/medications/resolve` — authoritative medication/GTIN resolution.
- `GET /v1/medications/search` — medication-master search.
- `POST /v1/medications` — pharmacist/admin product + identifier + ingredient creation.
- `POST /v1/pharmacy/receive` — receiving with lot, expiry, quantity and location.
- `GET /v1/inventory` — facility/lot/location inventory.
- `POST /v1/pharmacy/verify-product` — pharmacist verification/provenance.
- `POST /v1/orders` — signed medication request from a doctor.
- `POST /v1/pharmacy/dispense` — verified dispense and stock decrement.
- `POST /v1/administrations` — scheduled nurse administration with duplicate/window checks.
- `POST /v1/medications/safety-check` — structured ingredient allergy/interactions boundary.
- `GET /v1/recalls/search` — lot/GTIN impact across inventory and administrations.
- `POST /v1/labels/unit-dose` — hospital-internal DataMatrix/ZPL only when a unit lacks a usable manufacturer code.
- `GET /v1/events` — authenticated Server-Sent Events for facility workflow synchronization.
- `GET /v1/catalog/latest` / `POST /v1/catalog/publish` — signed/versioned offline medication catalogue.
- `GET /v1/fhir/medications` and `/v1/fhir/encounters/:encounterId/medications` — FHIR-shaped export boundary.
- `GET /v1/audit` — administrator view of append-only, hash-chained audit events.

## Offline catalogue signing

The server signs the exact JSON payload with an Ed25519 private key configured through `MEDQUR_CATALOG_SIGNING_PRIVATE_KEY_PEM`. Mobile devices should ship only the corresponding public key and reject catalogues whose signature/hash/version cannot be verified.

## Medication identification rule

Manufacturer/GS1 codes are preferred. Medqur does not create a competing code when an individual medication dose already carries a usable manufacturer identifier. Internal unit-dose DataMatrix labels are for controlled hospital repackaging/dispensing gaps and always resolve through the medication master.

## FHIR boundary

The current mapper exports Medication, MedicationRequest, MedicationDispense and MedicationAdministration resources. It deliberately does not push to e-Care/SystmOne automatically. A production connector must use the Ministry/vendor-approved interface, authentication, terminology profiles and conformance requirements.
