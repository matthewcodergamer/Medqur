# Medqur

Medqur is a Flutter clinical-workflow prototype for web, iOS and Android. V0.5 adds a safe, test-only NIDS QR workflow on top of the V0.4 Jamaica public-facility directory, V0.3 P1–P4 triage, and V0.2 camera/biometric/wristband/medication-scanning foundation.

> **Prototype only:** Do not use this repository for real patient identification, NIRA/NIDS verification, diagnosis, treatment decisions, triage, referral acceptance, medication administration or storage of protected health information. Production identity, facility, triage and clinical workflows must be formally validated and governed by Jamaica's Ministry of Health & Wellness, NIRA, the Regional Health Authorities and participating facilities.

## V0.5 — NIDS test credential loop

V0.5 adds a complete physical testing path for a **clearly fictional Medqur NIDS integration test card**. It does not reproduce or authenticate Jamaica's real National Identification Card.

### Test credential generator

- New **NIDS test QR generator** under the Scan workflow.
- Staff can enter a fictional given name, surname, ISO date of birth and **TEST-** National ID number.
- Medqur serializes those test fields into a versioned `medqur://nids-test/v1/...` QR payload.
- The QR is rendered by Flutter's QR library, not by an image-generation model, so the code is genuinely machine-readable.
- The generator visibly labels the output **TEST ONLY / NOT VALID / NOT GOVERNMENT IDENTIFICATION**.
- The prototype intentionally forces the test National ID number to use a `TEST-` prefix.
- Base64URL is only transport encoding; it is not encryption, signing or NIRA authentication.

### Registration by scan

- New Encounter → NIDS / NIC opens the real camera scanner.
- When a Medqur NIDS TEST QR is scanned, Medqur decodes the same fictional **name, date of birth and TEST NIN** from the code.
- Patient name and age are automatically prefilled from the scanned test credential.
- Date of birth and TEST National ID number are stored with the prototype patient record.
- The encounter timeline explicitly records that the test QR was decoded and that **NIRA verification was not performed**.
- Unknown codes can still be captured, but they are not treated as verified identity.

### Scanner positioning

- Staff-ID and NIDS scanning now show a full landscape card outline plus a smaller blue machine-code guide on the back-of-card region.
- Wristband scanning uses a wide horizontal scan area.
- Medication scanning remains optimized for QR, Data Matrix and common linear package barcodes.

### Production boundary

The V0.5 self-contained QR is for synthetic prototype testing only. A production Medqur deployment should **not place a person's complete identity record or sensitive NIDS data into a client-generated QR code**. Production should use an approved NIRA verification interface and/or an opaque server-issued credential that resolves to authorized identity data after authentication and consent checks.

## V0.4 — Jamaica public-facility tiers

Medqur models the public health-service hierarchy directly instead of treating every workplace as a generic hospital or clinic.

### Hospital classes

- **Type A hospital** — comprehensive tertiary and secondary care, major specialties/subspecialties, advanced diagnostics and the highest general referral tier.
- **Type B hospital** — standard secondary care across the core clinical disciplines, with escalation to Type A or specialist care when required.
- **Type C hospital** — district secondary care with stabilisation and transfer for cases beyond local capability.
- **Specialist hospital** — focused institutions such as paediatric, maternity, respiratory, mental-health, rehabilitation and oncology services.

### Health-centre classes

- **Type 1** — community preventive and maternal/child health outpost, typically serving under 4,000 people.
- **Type 2** — standard community primary care, typically serving up to 12,000 people.
- **Type 3** — full-service district primary-care hub, typically serving up to 20,000 people.
- **Type 4** — parish-level comprehensive primary-care and programme-coordination centre, typically serving 20,000–30,000 people.
- **Type 5** — comprehensive urban primary-care hub, typically serving more than 30,000 people with multidisciplinary services, diagnostics and specialised clinics.

### Facility-directory implementation

- A data-driven Jamaica public-facility catalogue contains the supplied Type A/B/C hospitals, national specialist institutions and the named Type 1–5 health centres across the parishes.
- Facility records carry a structured classification, parish, care level, typical capability summary, population band where relevant, specialist focus and referral-role description.
- Shift selection shows the authorized site's tier and care level instead of a generic facility label.
- The **Jamaica facility directory** lets staff search by name, town or specialty, filter by A/B/C, specialist or Type 1–5 classification, and filter by parish/service area.
- Facility detail sheets explain the typical role, capability envelope and referral position of each tier.
- The staff profile and active clinical shell show the current facility tier.
- Starting a shift remains restricted to the staff profile's authorized facilities; browsing the directory does not grant access.

The V0.4 catalogue is intentionally replaceable. In production, the seed data must be replaced by an authoritative Ministry/RHA registry with live service availability, staffing, opening hours, bed state and transfer-acceptance data. Medqur does not automatically choose a transfer destination based only on static classification.

## V0.3 — P1–P4 emergency triage

Medqur presents the emergency priority levels directly in the encounter workflow and patient queue:

- **P1 • Critical** — life-threatening emergency requiring immediate life-saving intervention; route directly to resuscitation.
- **P2 • Emergent** — severe or potentially life-threatening condition requiring rapid medical assessment and urgent treatment; route to a priority treatment area.
- **P3 • Intermediate** — stable, more complicated condition requiring medical care that can be delayed safely for a reasonable period, with reassessment while waiting.
- **P4 • Fast track** — minor, non-acute or routine presentation appropriate for fast-track care and the lowest emergency queue priority.

### Triage workflow changes

- New encounters use four large P1–P4 selection cards instead of generic Critical/Urgent/Moderate/Routine chips.
- Each priority shows a short acuity description and routing action before the nurse confirms it.
- P1 and P2 selections produce a prominent routing warning so they are not treated like routine waiting cases.
- Patient wristbands show the P-level and clinical label.
- Patient cards throughout the app inherit P1–P4 labels from the central triage helpers.
- The active patient queue is ordered **P1 → P2 → P3 → P4**.
- The queue dashboard shows a live count for every P-level and an additional P1/P2 urgency notice when high-priority patients are active.
- Existing stored V0.2 prototype records remain compatible because the internal persisted enum names were intentionally left unchanged.

Triage classification remains a clinician-entered decision. The prototype does not attempt to diagnose a patient or automatically assign a P-level from symptoms or vital signs.

## V0.2 foundation retained

### Real device functionality

- Live camera scanner on Android, iOS and the HTTPS web build.
- Camera permission request handled by the scanner/browser/OS.
- QR, Data Matrix and common linear barcode capture for staff, identity, wristband and medication workflows.
- Staff badge camera overlay, NIDS/NIC card overlay, wristband frame and medication barcode frame.
- Native Android/iOS fingerprint/Face ID authentication through `local_auth`.
- Scannable staff badge and patient encounter QR tokens.
- Local prototype persistence so demo patients/orders survive restarts/refreshes.
- Doctor/nurse role policy boundary.
- Patient assignment.
- Doctor medication orders with an optional mapped package barcode.
- Nurse closed-loop flow: scan patient wristband, scan medication package, require both to match, then record administration.
- FHIR-shaped integration adapter boundary.

### Not connected yet

- NIRA/NIDS production verification
- Ministry of Health production identity/services
- authoritative Ministry/RHA facility registry
- live hospital capacity / bed-state / transfer-acceptance service
- e-Care / SystmOne
- secure browser passkey relying-party server
- production cross-device realtime backend
- production clinical database or audit service
- production printer bridge / Zebra wristband output

The browser build can use the camera, but secure browser passkeys require a server-generated WebAuthn challenge. The public web build does not fake that security step.

## Medication identification

Medqur does **not** require every medicine to receive a custom Medqur QR. The scanner accepts both 2D and linear codes. In production, a scanned GTIN/GS1 DataMatrix or other approved package code (or a hospital-generated unit-dose code where necessary) would resolve against an approved medication/product master before it can match an active order.

## Demo staff IDs

- Doctor: `MQ-7K4P-92XF`
- Nurse: `MQ-2N8R-41KD`

The ID field starts empty. Use **Use demo ID** for quick public-prototype access.

## Branding

The Medqur wordmark is drawn as vector UI instead of the old raster image, eliminating the grey rectangle visible in some browsers. `assets/medqur_app_icon.svg` is the canonical high-quality app/favicon artwork: blue Medqur mark on white. CI generates Android, iOS and web raster icon sizes from the same geometry.

## Build

GitHub Actions regenerates the Flutter platform scaffolding, adds camera/biometric permissions, creates branded icons, runs analysis, and builds:

- Android release APK
- Flutter web release + `gh-pages`
- unsigned iOS release app

The workflow is the release gate for every push to `main`.

See `.github/workflows/build.yml`.

## Architecture

See [`docs/V0.2_ARCHITECTURE.md`](docs/V0.2_ARCHITECTURE.md) for the backend, FHIR, role, realtime and security boundaries.
