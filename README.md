# Medqur

Medqur is a Flutter clinical-workflow prototype for web, Android and iOS, backed by a PostgreSQL/Node clinical-services layer. The project explores a mobile-first workflow for patient identity, triage, secure workforce credentials, medication identification, prescribing, pharmacy, wristbands and point-of-care scanning in a Jamaican public-health setting.

> **Prototype / development system only.** This repository is not an official Ministry of Health & Wellness, NIRA, Regional Health Authority, e-Care/SystmOne or regulatory system. Do not use the public prototype with real protected health information or as the sole basis for diagnosis, treatment, identity verification, prescribing, dispensing or medication administration. Production use requires formal governance, clinical validation, approved identity/data integrations, security review and deployment controls.

## V0.11 — less-is-more clinical UX + prescription printing

V0.11 moves Medqur away from a dense prototype UI toward a restrained clinical interface: more whitespace, smaller information surfaces, stronger hierarchy and fewer technical details shown by default. The goal is modern government/hospital software that remains calm and understandable during long clinical shifts.

### Design direction

- Material 3 with an Apple-simple, government/clinical visual language.
- Preferred UI family: `Inter`, with platform fallbacks including SF Pro Text, Segoe UI, Roboto and Arial. No font binaries are bundled in the repository.
- Smaller, more consistent title/body/metadata scales.
- Compact responsive spacing for phones, tablets and desktop/web.
- White/light-neutral surfaces, deep navy text, Medqur blue primary actions, Ministry/clinical green for verified states and reserved red/amber for clinical risk.
- Minimal shadows and restrained rounded corners; less “bubble/card” density.
- Medication capsule artwork is intentionally limited to low-risk browse surfaces and is not shown during high-risk medication confirmation/administration.

### Real MRH prescription-form renderer

The supplied **Southern Regional Health Authority / Mandeville Regional Hospital** prescription sheet (`SRHA.MRH.CM2013`) is now used as the prototype print template. The uploaded photograph was cropped to the paper, cleaned for contrast and converted to a compact monochrome embedded template so the same form renders on web, Android and iOS.

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
- stored doctor signature

Patient/system fields use a clean typed style for legibility. Medication directions are rendered with a restrained digital-pen appearance and can use **blue** or **black** ink. The preview UI prefers a handwriting-like family such as Kalam when available; the generated PDF intentionally uses a dependable built-in italic print font so printing never depends on a missing third-party font file.

### Prescription workflow

Doctor workflow:

1. Select the patient encounter.
2. Search the medication catalogue/registry or scan the package.
3. Enter dose, route, frequency, duration and instructions.
4. Optionally schedule the first dose.
5. Choose blue or black prescription ink.
6. Use the default saved signature or select an alternate signature.
7. **Sign & preview** the completed hospital prescription.
8. Print through the operating-system print service or save/share the generated PDF.

Medication search and barcode resolution remain linked to the medication-master trust model. An observed/public product match is not automatically treated as a Jamaica-approved clinical product.

### Doctor signature vault

Doctors can maintain multiple reusable signature assets from the Profile → Signatures screen.

Supported creation paths:

- **Draw on device** using a finger or stylus. Medqur stores normalized vector strokes and renders a transparent signature image.
- **Photo from paper** using the phone camera. The doctor signs clean white paper; Medqur detects pen strokes, crops them, removes the paper background and normalizes them to blue or black transparent artwork.

Signature features:

- multiple signatures per doctor
- one default signature
- alternate signature selection per prescription
- rename/delete/default controls
- reusable transparent signature preview
- per-prescription SHA-256 attestation payload

A stored signature image is **not authentication by itself**. The authoritative signer identity remains the authenticated Medqur health-worker account, six-digit staff ID, role/facility authorization, timestamp and audit event. A production deployment should protect reusable signature assets in an encrypted server-side vault or hardware-backed device storage according to approved policy.

## Workforce identity

Medqur models a unique **six-digit staff number** for health workers and supports an opaque signed workforce badge credential. Production-style staff QR credentials are designed so the QR itself does not expose the employee’s name, licence, profession or facility permissions.

The identity service can verify:

- credential signature
- expiry
- revocation state
- active staff account
- current role
- authorized facility

The badge identifies the account; device biometric/passkey authentication verifies the person using the device.

Current development fixtures include a doctor, nurse and pharmacist. Fixture data is synthetic and is not an official healthcare-worker registry.

## NIDS / NIC workflow

The app supports camera scanning and a Medqur **test-only** NIDS credential loop for synthetic patient-registration testing. A test QR can prefill fictional name/date-of-birth/test NIN information.

Unknown/opaque NIC data can be captured and fingerprinted, but Medqur does not label a real Jamaican NIC as verified without the authorized NIRA verification boundary. The public repository does not guess or reverse-engineer a production NIRA QR/API contract.

A production flow should use NIRA-approved identity verification and return only the minimum authorized identity attributes needed for patient matching.

## Medication identification and pharmacy

Medication scanning accepts common real package formats including:

- GS1 DataMatrix
- EAN / UPC
- Code 128 and other supported linear barcodes
- QR where relevant

The parser can extract/normalize GTIN, lot/batch, manufacture/best-before/expiry dates and serial information when encoded. It also handles bracket/colon representations observed from some pharmaceutical DataMatrix scanners.

Resolution order is designed around trust:

1. configured Medqur/Jamaica medication registry
2. approved/local medication master/cache
3. observed-package fixture/reference data
4. public terminology/reference sources where appropriate
5. pharmacist verification when unresolved

The PostgreSQL pharmacy backend supports medication products/identifiers/ingredients, receiving, lot/expiry inventory, product verification, dispensing, recall impact queries, administration records, unit-dose DataMatrix labels, audit/outbox events, signed offline catalog releases and FHIR-shaped medication endpoints.

Unknown products remain unknown rather than being guessed.

## Triage and patient workflow

- P1–P4 triage categories.
- NIDS/NIC test scan or emergency/unknown patient registration.
- Editable patient identity/encounter state.
- Patient wristband generation and scanning.
- Patient queue ordered by acuity.
- Doctor order / prescription workflow.
- Pharmacy and nurse medication-task workflow.
- Closed-loop patient-wristband + medication-package checks.
- Local prototype persistence and an integration boundary for realtime/backend synchronization.

Triage remains clinician-entered. The prototype does not automatically diagnose a patient or assign a priority from symptoms alone.

## Printing

### Wristbands

The prototype generates a dynamic wristband PDF from patient/encounter data and opens the OS print service. It can be tested with an HP LaserJet P2035n using normal print/PDF workflows. A future facility Print Bridge/Zebra adapter can route jobs directly to configured healthcare wristband printers.

### Prescriptions

V0.11 generates the SRHA/MRH prescription form as a print-ready PDF with dynamic patient/prescriber information, medication directions and the selected stored signature. The print action uses the native/system print flow on supported Flutter platforms.

A production deployment must validate the legal/clinical requirements for electronic/printed prescriptions, signature policy, controlled medicines and pharmacy acceptance before use.

## Backend and security boundaries

The backend uses Node/TypeScript and PostgreSQL and includes:

- role/facility authorization boundaries
- medication master and pharmacy tables
- append-only audit/event patterns
- realtime event stream boundary
- signed staff credential service
- signed/versioned medication catalog support
- FHIR-shaped medication resources
- prescription-signature database columns and integrity constraints

The public prototype still requires authorized external infrastructure for production-grade NIRA, Ministry/RHA workforce, OIDC/passkeys, e-Care/SystmOne, authoritative Jamaican formulary/regulatory feeds and approved drug-interaction knowledge.

## Build

GitHub Actions is the release gate on `main` and performs:

- backend dependency install and TypeScript typecheck
- PostgreSQL schema startup/validation
- live medication-registry smoke test
- signed staff-ID smoke test
- Flutter dependency install
- `flutter analyze`
- functional Flutter tests
- Android release APK build
- Flutter web release build and `gh-pages` publication
- unsigned iOS release build/package

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

The unsigned iOS artifact is a build-validation artifact; normal iPhone distribution requires Apple signing/provisioning or TestFlight/App Store deployment.

## Repository structure

- `lib/screens/` — clinical, pharmacy, scan, identity and prescription workflows
- `lib/services/` — medication registry, pharmacy API, NIDS, persistence, signature vault and print document generation
- `lib/widgets/` — design system, scanner helpers, signature pad and prescription-form preview
- `lib/generated/prescription_template_data.dart` — cleaned embedded MRH prescription form used for prototype printing
- `backend/` — PostgreSQL/Node medication, pharmacy, identity, audit and FHIR-shaped service layer
- `.github/workflows/build.yml` — cross-platform CI/release validation

## Next production stages

Priority work after V0.11:

- server-side encrypted signature-vault synchronization and retention policy
- complete server-side signature-payload digest verification on prescription submission
- authoritative Jamaica medication/formulary/regulatory feed
- approved structured drug-allergy/interaction knowledge base
- production OIDC/passkey sessions and device management
- NIRA test/production integration under authorized specifications
- e-Care/SystmOne integration under Ministry/vendor-approved interfaces
- realtime multi-device patient/order/pharmacy synchronization
- offline conflict-safe medication workflows
- Print Bridge plus Zebra healthcare wristband/label integration
- accessibility, usability and clinical human-factors validation

Medqur’s architecture intentionally keeps these external integrations behind adapters so the public prototype does not impersonate an official government service.
