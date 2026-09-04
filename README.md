# Medqur

Medqur is a Flutter clinical-workflow prototype for web, Android and iOS, backed by a PostgreSQL/Node clinical-services layer. The project explores mobile-first patient identity, triage, secure workforce credentials, medication identification, prescribing, pharmacy, wristbands and point-of-care scanning in a Jamaican public-health setting.

> **Prototype / development system only.** This repository is not an official Ministry of Health & Wellness, NIRA, Regional Health Authority, e-Care/SystmOne or regulatory system. Do not use the public prototype with real protected health information or as the sole basis for diagnosis, treatment, identity verification, prescribing, dispensing or medication administration. Production use requires formal governance, clinical validation, approved identity/data integrations, security review and deployment controls.

## V0.11.1 — calmer clinical UI, native biometrics and signed prescriptions

V0.11.1 finishes the V0.11 prescription work and reduces visual overload across the application. The design target is restrained government/hospital software: centered layouts, more whitespace, fewer decorative colors, smaller cards, predictable spacing and clinical color only where it carries meaning.

### Less-is-more design system

- Preferred UI family: `Inter`, with platform fallbacks including SF Pro Text, Segoe UI, Roboto and Arial. No font binaries are bundled in the repository.
- Central clinical content width is capped so desktop/web pages do not stretch across the screen.
- Compact phone spacing, balanced tablet spacing and centered desktop/web layouts.
- White/light-neutral surfaces with dark ink/navy typography.
- Medqur blue is reserved mainly for primary actions; green, amber and red are reserved for verified/safety/acuity meaning.
- Smaller shadows, corner radii, status pills, icons and headings.
- Reduced motion with short fades/slides instead of decorative animation.
- Medication capsule artwork remains limited to low-risk browse surfaces and does not appear in high-risk medication confirmation/administration steps.

The sign-in page has also been simplified to one staff-ID field, one primary authentication action, secure staff-QR scanning and a single optional demo-account entry point.

## Workforce sign-in and device security

Every modeled health worker uses a unique **six-digit staff number**. Signed workforce QR credentials remain separate from person/device authentication.

### iPhone and iPad

The native app uses Flutter `local_auth` and the operating-system biometric prompt. When enrolled and supported, iOS uses **Face ID or Touch ID**. CI-generated iOS configuration adds the Face ID usage description required by iOS.

### Android

Android uses the operating-system biometric prompt for an enrolled **fingerprint or supported face biometric**. CI adds `USE_BIOMETRIC` and uses `FlutterFragmentActivity`, as required by the native authentication plugin.

Medqur never receives a fingerprint or face template; the operating system returns only the authentication result.

### Browser prototype

The public web build cannot truthfully claim native Face ID/fingerprint authentication through Flutter `local_auth`. V0.11.1 therefore replaces the old browser “continue prototype” bypass with a **six-digit browser-session PIN**:

- the user creates/confirm a PIN on first use for that prototype staff profile;
- a random salt is generated;
- only a salted SHA-256 verifier is stored locally;
- comparisons are constant-time;
- five failed attempts trigger a one-minute lockout.

This PIN is only a local prototype guard. It is **not** equivalent to production identity authentication. Production browser access should use an approved OIDC/WebAuthn relying party, preferably passkeys/security keys with server-issued challenges and normal government/Medqur identity policy.

## Real MRH prescription-form renderer

The supplied **Southern Regional Health Authority / Mandeville Regional Hospital** prescription sheet (`SRHA.MRH.CM2013`) is used as the prototype print template. The supplied photograph is cropped/cleaned and embedded so web, Android and iOS render the same form.

Medqur overlays dynamic fields at fixed form coordinates:

- patient name
- sex marker
- age
- date
- clinic/facility
- discharge indicator
- docket/patient ID
- medication and directions
- copy number
- doctor name
- selected doctor signature

Patient/system fields use a clean typed style for legibility. Medication directions use a restrained digital-pen appearance and can be rendered in **blue** or **black** ink. The on-screen preview prefers a handwriting-like font where available; PDF generation uses a dependable built-in italic print font so printing does not fail because a third-party font is missing.

### Prescription workflow

1. Select the patient encounter.
2. Search the medication catalogue/registry or scan the package.
3. Enter dose, route, frequency, duration and instructions.
4. Optionally schedule the first dose.
5. Choose blue or black prescription ink.
6. Use the default saved signature or select an alternate signature.
7. Sign and preview the completed hospital prescription.
8. Print through the operating-system print service or save/share the PDF.

Medication search and barcode resolution remain linked to the medication-master trust model. An observed/public product match is not automatically treated as a Jamaica-approved clinical product.

## Doctor signature vault

Doctors can maintain multiple reusable signature assets from Profile → Signatures.

Supported creation paths:

- **Draw on device** with a finger or stylus. Medqur stores normalized vector strokes and renders transparent signature artwork.
- **Photo from paper** with the phone camera. The doctor signs clean white paper; Medqur detects the pen strokes, crops them, removes the paper background and normalizes the result to blue or black transparent artwork.

The vault supports multiple signatures, one default, alternate selection per prescription, rename/delete/default controls and reusable previews.

A saved signature picture is not authentication by itself. Every submitted prescription remains bound to the authenticated six-digit staff account, facility, role, time and audit record.

### Server-side prescription integrity

V0.11.1 completes the backend signing boundary. The `/v1/orders` service now requires the signature payload, digest, signing time and method. Before storing an order, the server:

- recomputes SHA-256 over the submitted signature payload;
- rejects a mismatched digest;
- validates the signature payload JSON;
- checks the payload prescriber ID against the authenticated doctor;
- checks the supplied signing time;
- stores the payload, digest, time, method and signature version in PostgreSQL;
- records the signature digest/method/version in the audit event.

This protects the visual-attestation record from silent client-side alteration. A production deployment should additionally keep reusable signature assets in an encrypted server-side vault or hardware-backed device storage according to approved policy.

## Secure staff QR credentials

Medqur supports opaque signed staff credentials. Production-style QR credentials are designed so the QR itself does not expose the employee’s name, licence, profession, facility permissions or patient information.

The identity service can check credential signature, expiry, revocation, active staff account, current role and authorized facility. The badge identifies the account; device biometric/passkey authentication verifies the person using the device.

Current development fixtures are synthetic and are not an official healthcare-worker registry.

## NIDS / NIC workflow

The app supports camera scanning and a Medqur **test-only** NIDS credential loop for synthetic patient-registration testing. A test QR can prefill fictional name/date-of-birth/test NIN information.

Unknown/opaque NIC data can be captured and fingerprinted, but Medqur does not label a real Jamaican NIC as verified without an authorized NIRA verification boundary. The public repository does not guess or reverse-engineer a production NIRA QR/API contract.

A production flow should use NIRA-approved identity verification and return only the minimum authorized identity attributes needed for patient matching.

## Medication identification and pharmacy

Medication scanning accepts supported real package formats including GS1 DataMatrix, EAN/UPC, Code 128 and QR where applicable. The parser can extract/normalize GTIN, lot/batch, manufacture/best-before/expiry dates and serial information when encoded.

Resolution is trust-aware: configured medication registry/master first, then local approved/cache data, observed/public reference data where appropriate, and pharmacist verification when unresolved. Unknown products remain unknown rather than being guessed.

The PostgreSQL pharmacy backend supports medication products/identifiers/ingredients, receiving, lot/expiry inventory, product verification, dispensing, recall-impact queries, administration records, unit-dose DataMatrix labels, audit/outbox events, signed offline catalog releases and FHIR-shaped medication endpoints.

The public repository still does not claim an authoritative Jamaica formulary, official regulator feed or approved clinical interaction knowledge base.

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

V0.11.1 generates the SRHA/MRH prescription form as a print-ready PDF with dynamic patient/prescriber information, medication directions and the selected stored signature.

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

## Build

GitHub Actions is the release gate on `main` and performs backend TypeScript validation, PostgreSQL schema startup, medication-registry/staff-ID smoke tests, Flutter analysis/tests, Android APK build, web release/Pages publication and unsigned iOS build/package.

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
- `lib/generated/prescription_template_data.dart` — cleaned embedded MRH prescription form
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
