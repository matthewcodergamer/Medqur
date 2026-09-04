# Medqur

Medqur is a Flutter clinical-workflow prototype for web, Android and iOS, backed by a PostgreSQL/Node clinical-services layer. The project explores mobile-first patient identity, triage, secure workforce credentials, medication identification, prescribing, pharmacy, wristbands and point-of-care scanning in a Jamaican public-health setting.

> **Prototype / development system only.** This repository is not an official Ministry of Health & Wellness, NIRA, Regional Health Authority, e-Care/SystmOne or regulatory system. Do not use the public prototype with real protected health information or as the sole basis for diagnosis, treatment, identity verification, prescribing, dispensing or medication administration. Production use requires formal governance, clinical validation, approved identity/data integrations, security review and deployment controls.

## V0.11.2 — prescription rendering, signature extraction and medication-search fixes

V0.11.2 focuses on the problems found during real device testing of the V0.11 prescription workflow. It keeps the calmer V0.11.1 interface while fixing the prescription preview, preventing photographed signatures from becoming large dark blobs, refining the medication capsule artwork and expanding the development medication catalogue.

### Prescription-template rendering fix

The supplied **Southern Regional Health Authority / Mandeville Regional Hospital** prescription sheet (`SRHA.MRH.CM2013`) remains the print base. Medqur does not substitute a cartoon/redrawn prescription for the hospital form.

The compact embedded template is normalized at runtime into a standard four-channel RGBA PNG before it is given to Flutter or the PDF engine. This removes the browser/iOS decoder edge case that could show a plain grey rectangle instead of the prescription form. The same normalized bytes are used for the on-screen preview and generated PDF, and the rendering path is now covered by an automated image-decode test.

The preview overlays:

- patient name, sex, age and date
- facility/clinic and discharge indicator
- docket/patient ID
- medicine and directions
- copy number
- doctor name
- selected reusable doctor signature

Patient/system fields use clean typed text. Medication directions use a restrained digital-pen appearance and can be rendered in blue or black ink.

### Paper-signature extraction fix

The previous paper-photo processor could treat a shadow, desk edge or generally dark photograph as signature ink. V0.11.2 changes the extraction pipeline to:

- resize oversized camera captures before analysis;
- estimate paper brightness locally in small blocks rather than using one global dark-pixel threshold;
- detect blue-pen colour separately from neutral/black ink;
- require meaningful local contrast from the surrounding paper;
- remove isolated camera/sensor noise;
- retain softer edge pixels around strong pen strokes for smoother transparent artwork;
- reject captures whose dark area still looks like one large filled blob;
- return a clear retake message when shadows, printed material or table edges dominate the frame.

A functional test creates unevenly lit synthetic paper with a broad shadow and signature-like blue strokes, then verifies that the extracted result remains mostly transparent rather than becoming a solid block.

Doctors can still create signatures by drawing with a finger/stylus or photographing a signature written on clean white paper. Multiple signatures, a preferred default, alternate selection, rename/delete controls and per-prescription SHA-256 attestations remain supported.

## Less-is-more design system

The visual target remains restrained government/hospital software rather than a dense prototype or cartoon health app.

- Preferred UI family: `Inter`, with platform fallbacks including SF Pro Text, Segoe UI, Roboto and Arial. No font binaries are bundled in the repository.
- Central clinical content width is capped so desktop/web pages do not stretch across the screen.
- Compact phone spacing, balanced tablet spacing and centered desktop/web layouts.
- White/light-neutral surfaces with dark ink/navy typography.
- Medqur blue is reserved mainly for primary actions; green, amber and red are reserved for verified/safety/acuity meaning.
- Smaller shadows, corner radii, status pills, icons and headings.
- Reduced motion with short fades/slides instead of decorative animation.
- The medication capsule remains a low-risk browse motif only. V0.11.2 makes it shorter and chunkier so it reads as a real capsule rather than a long decorative bar.

The sign-in page is intentionally simple: staff ID, primary authentication action, secure staff-QR scanning and optional prototype/demo access only where explicitly labeled.

## Workforce sign-in and device security

Every modeled health worker uses a unique **six-digit staff number**. Signed workforce QR credentials remain separate from person/device authentication.

### iPhone and iPad

The native app uses Flutter `local_auth` and the operating-system biometric prompt. When enrolled and supported, iOS uses **Face ID or Touch ID**. CI-generated iOS configuration adds the Face ID usage description required by iOS.

### Android

Android uses the operating-system biometric prompt for an enrolled **fingerprint or supported face biometric**. CI adds `USE_BIOMETRIC` and uses `FlutterFragmentActivity`, as required by the native authentication plugin.

Medqur never receives a fingerprint or face template; the operating system returns only the authentication result.

### Browser prototype

The public web build does not claim native Face ID/fingerprint authentication through Flutter `local_auth`. The browser fallback is a **six-digit local session PIN** with a random salt, salted SHA-256 verifier, constant-time comparison, and lockout after repeated failed attempts.

This PIN is a development guard, not production identity authentication. Production browser access should use an approved OIDC/WebAuthn relying party, preferably passkeys/security keys with server-issued challenges and government/Medqur identity policy.

## Prescription workflow

1. Select the patient encounter.
2. Search the medication catalogue/registry or scan the package.
3. Enter dose, route, frequency, duration and instructions.
4. Optionally schedule the first dose.
5. Choose blue or black prescription ink.
6. Use the default saved signature or select an alternate signature.
7. Sign and preview the completed hospital prescription.
8. Print through the operating-system print service or save/share the PDF.

A saved signature picture is not authentication by itself. Every submitted prescription remains bound to the authenticated six-digit staff account, facility, role, time and audit record.

### Server-side prescription integrity

The `/v1/orders` service validates the prescription-signature boundary before storage. The server recomputes SHA-256 over the submitted signature payload, rejects mismatched digests, validates the payload and authenticated prescriber ID, checks signing time, persists the signature metadata and includes digest/method/version information in the audit event.

A production deployment should additionally keep reusable signature assets in an encrypted server-side vault or hardware-backed device storage according to approved policy.

## Secure staff QR credentials

Medqur supports opaque signed staff credentials. Production-style QR credentials are designed so the QR itself does not expose the employee’s name, licence, profession, facility permissions or patient information.

The identity service can check credential signature, expiry, revocation, active staff account, current role and authorized facility. The badge identifies the account; device biometric/passkey authentication verifies the person using the device.

Current development fixtures are synthetic and are not an official healthcare-worker registry.

## NIDS / NIC workflow

The app supports camera scanning and a Medqur **test-only** NIDS credential loop for synthetic patient-registration testing. A test QR can prefill fictional name/date-of-birth/test NIN information.

Unknown/opaque NIC data can be captured and fingerprinted, but Medqur does not label a real Jamaican NIC as verified without an authorized NIRA verification boundary. The public repository does not guess or reverse-engineer a production NIRA QR/API contract.

A production flow should use NIRA-approved identity verification and return only the minimum authorized identity attributes needed for patient matching.

## Medication identification, search and pharmacy

Medication scanning accepts supported real package formats including GS1 DataMatrix, EAN/UPC, Code 128 and QR where applicable. The parser can extract/normalize GTIN, lot/batch, manufacture/best-before/expiry dates and serial information when encoded.

Resolution is trust-aware: configured medication registry/master first, then local cache/observed package data and public reference data where appropriate, with pharmacist verification when unresolved. Unknown products remain unknown rather than being guessed.

V0.11.2 expands the **unverified development catalogue** so prescription/search screens can exercise more realistic forms and therapeutic categories while an authoritative Jamaica feed is unavailable. Development fixtures now include, among others, paracetamol, amoxicillin, amoxicillin/clavulanic acid, ibuprofen, azithromycin, doxycycline, ceftriaxone, metformin, amlodipine, lisinopril, omeprazole, cetirizine, salbutamol, fluconazole and oral rehydration salts, in addition to the observed-package scanner fixtures.

These added rows are explicitly `unreviewed` / `unverified`, use `medqur_prototype_catalogue` provenance and are **not** represented as Jamaica-approved products or prescribing recommendations.

The PostgreSQL pharmacy backend supports medication products/identifiers/ingredients, receiving, lot/expiry inventory, product verification, dispensing, recall-impact queries, administration records, unit-dose DataMatrix labels, audit/outbox events, signed offline catalog releases and FHIR-shaped medication endpoints.

## Triage and patient workflow

- P1–P4 clinician-entered triage categories.
- NIDS/NIC test scan or emergency/unknown patient registration.
- Editable patient identity/encounter state.
- Patient wristband generation and scanning.
- Patient queue ordered by acuity.
- Doctor order/prescription workflow.
- Pharmacy and nurse medication-task workflow.
- Closed-loop patient-wristband + medication-package checks.
- Local prototype persistence and an integration boundary for realtime/backend synchronization.

The prototype does not automatically diagnose a patient or assign a triage priority from symptoms alone.

## Printing

### Wristbands

The prototype generates a dynamic wristband PDF and opens the system print service. A future facility Print Bridge/Zebra adapter can route jobs directly to configured healthcare wristband printers.

### Prescriptions

V0.11.2 generates the SRHA/MRH prescription form as a print-ready PDF with dynamic patient/prescriber information, medication directions and the selected stored signature. Preview and PDF generation consume the same normalized form image to reduce platform differences.

A production deployment must validate legal/clinical requirements for electronic/printed prescriptions, signature policy, controlled medicines and pharmacy acceptance before use.

## Backend and security boundaries

The Node/TypeScript/PostgreSQL backend includes:

- role/facility authorization boundaries
- medication master and pharmacy tables
- append-only audit/event patterns
- realtime event-stream boundary
- signed staff credential service
- signed/versioned medication catalog support
- FHIR-shaped medication resources
- prescription-signature database integrity constraints
- server-side prescription signature digest and signer verification

Production still requires authorized external infrastructure for NIRA, Ministry/RHA workforce identity, OIDC/passkeys, e-Care/SystmOne, authoritative Jamaican medication/formulary/regulatory feeds and approved drug-interaction/allergy knowledge.

## Build and validation

GitHub Actions is the release gate on `main` and performs backend TypeScript validation, PostgreSQL schema startup, medication-registry/staff-ID smoke tests, Flutter analysis/tests, Android APK build, web release/Pages publication and unsigned iOS build/package.

V0.11.2 adds a prescription-rendering test that verifies the embedded hospital form decodes into a non-empty RGBA image and a signature-processing test that verifies uneven paper lighting does not become one opaque signature blob.

Local Flutter development:

```bash
flutter pub get
flutter run
```

Build examples:

```bash
flutter build apk --release
flutter build web --release --base-href "/Medqur/"
flutter build ios --release --no-codesign
```

The unsigned iOS artifact is only build validation; normal iPhone distribution requires Apple code signing/provisioning or TestFlight/App Store deployment.

## Repository structure

- `lib/screens/` — clinical, pharmacy, scan, identity and prescription workflows
- `lib/services/` — medication registry, pharmacy API, NIDS, biometric/browser session guards, persistence, signature vault and print generation
- `lib/widgets/` — shared design system, scanner helpers, signature pad and prescription-form preview
- `lib/generated/prescription_template_data.dart` — embedded/normalized MRH prescription form
- `backend/sql/005_prototype_medication_catalog.sql` — expanded unverified development medication seed
- `backend/` — PostgreSQL/Node medication, pharmacy, identity, audit and FHIR-shaped service layer
- `.github/workflows/build.yml` — cross-platform CI/release validation

## Next production stages

- server-side encrypted reusable-signature vault synchronization and retention policy
- authoritative Jamaica medication/formulary/regulatory feed
- approved structured drug-allergy/interaction knowledge base
- production OIDC/WebAuthn/passkey sessions and managed-device policy
- NIRA test/production integration under authorized specifications
- e-Care/SystmOne integration under Ministry/vendor-approved interfaces
- realtime multi-device patient/order/pharmacy synchronization
- offline conflict-safe medication workflows
- Print Bridge plus Zebra healthcare wristband/label integration
- accessibility, usability and clinical human-factors validation

Medqur’s architecture intentionally keeps external authoritative integrations behind adapters so the public prototype does not impersonate an official government service.
