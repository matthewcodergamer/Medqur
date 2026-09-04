# Medqur

Medqur is a Flutter clinical-workflow prototype for web, Android and iOS, backed by a PostgreSQL/Node clinical-services layer. The project explores mobile-first patient identity, triage, secure workforce credentials, medication identification, prescribing, pharmacy, wristbands and point-of-care scanning in a Jamaican public-health setting.

> **Prototype / development system only.** This repository is not an official Ministry of Health & Wellness, NIRA, Regional Health Authority, e-Care/SystmOne or regulatory system. Do not use the public prototype with real protected health information or as the sole basis for diagnosis, treatment, identity verification, prescribing, dispensing or medication administration. Production use requires formal governance, clinical validation, approved identity/data integrations, security review and deployment controls.

## V0.11.3 — iPhone browser viewport and prescription-signature hardening

V0.11.3 continues the V0.11.2 prescription and medication work, with two device-level fixes found during iPhone Safari testing: the web app no longer remains visually zoomed after text-field/keyboard interactions, and stored signatures are rendered on prescription-safe pure white instead of relying on transparent PNG compositing that could appear as a dark or grey block in some browser/PDF paths.

### iPhone / Safari browser viewport fix

The generated Flutter web shell now writes a hardened mobile viewport specifically for iPhone/iPad browser use:

- `width=device-width` with a fixed initial scale and `viewport-fit=cover`;
- 100% / dynamic-viewport sizing for the Flutter host rather than a stale visual viewport;
- iOS text-size adjustment locked to 100%;
- underlying browser editing controls held at 16px so Safari does not auto-zoom when a field receives focus;
- a small runtime zoom guard that re-applies the viewport after focus/keyboard dismissal, page restoration and orientation changes;
- a reset to the top-left visual origin after the iOS keyboard closes so the whole Flutter interface does not remain magnified or offset.

The CI platform-generation step checks that these protections are actually present in the generated `web/index.html`, so a future Flutter template change cannot silently remove them.

### Prescription-template rendering fix

The supplied **Southern Regional Health Authority / Mandeville Regional Hospital** prescription sheet (`SRHA.MRH.CM2013`) remains the print base. Medqur does not substitute a cartoon/redrawn prescription for the hospital form.

The compact embedded template is normalized at runtime into a standard four-channel RGBA PNG before it is given to Flutter or the PDF engine. This removes the browser/iOS decoder edge case that could show a plain grey rectangle instead of the prescription form. The same normalized bytes are used for the on-screen preview and generated PDF, and the rendering path is covered by automated image-decode tests.

The preview overlays:

- patient name, sex, age and date
- facility/clinic and discharge indicator
- docket/patient ID
- medicine and directions
- copy number
- doctor name
- selected reusable doctor signature

Patient/system fields use clean typed text. Medication directions use a restrained digital-pen appearance and can be rendered in blue or black ink.

### Paper-signature extraction and rendering fix

The paper-photo processor estimates paper brightness locally in small blocks rather than treating every dark pixel as signature ink. It detects blue-pen colour separately from neutral/black ink, requires meaningful local contrast, removes isolated camera noise, keeps softer edge pixels around real strokes and rejects captures that still resemble one large filled region.

V0.11.3 adds a second rendering stage designed around the actual hospital form. After the signature strokes are isolated and cropped, Medqur composites the cleaned artwork onto **pure white paper** before storing/displaying a photographed signature. Because the prescription form itself is white, this safely blends into the form and avoids browser/PDF alpha-transparency failures that can turn transparent image data into one large block.

Existing stored signatures are also normalized onto white at preview/print time. If an old stored image is overwhelmingly dark or does not resemble usable handwriting, Medqur displays a recapture warning rather than pasting the bad block onto the prescription. Printing is blocked until a usable signature is selected.

Doctors can create signatures by drawing with a finger/stylus or photographing a signature written on clean white paper. Multiple signatures, a preferred default, alternate selection, rename/delete controls and per-prescription SHA-256 attestations remain supported.

## Less-is-more design system

The visual target remains restrained government/hospital software rather than a dense prototype or cartoon health app.

- Preferred UI family: `Inter`, with platform fallbacks including SF Pro Text, Segoe UI, Roboto and Arial. No font binaries are bundled in the repository.
- Central clinical content width is capped so desktop/web pages do not stretch across the screen.
- Compact phone spacing, balanced tablet spacing and centered desktop/web layouts.
- White/light-neutral surfaces with dark ink/navy typography.
- Medqur blue is reserved mainly for primary actions; green, amber and red are reserved for verified/safety/acuity meaning.
- Smaller shadows, corner radii, status pills, icons and headings.
- Reduced motion with short fades/slides instead of decorative animation.
- The medication capsule remains a low-risk browse motif only and uses the shorter, fuller shape introduced in V0.11.2.

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

The iPhone/iPad browser shell now includes the Safari viewport/keyboard protections described above so focusing fields does not leave the clinical workspace permanently zoomed or offset.

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

The **unverified development catalogue** lets prescription/search screens exercise realistic forms and therapeutic categories while an authoritative Jamaica feed is unavailable. Development fixtures include, among others, paracetamol, amoxicillin, amoxicillin/clavulanic acid, ibuprofen, azithromycin, doxycycline, ceftriaxone, metformin, amlodipine, lisinopril, omeprazole, cetirizine, salbutamol, fluconazole and oral rehydration salts, in addition to observed-package scanner fixtures.

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

Medqur generates the SRHA/MRH prescription form as a print-ready PDF with dynamic patient/prescriber information, medication directions and the selected stored signature. The prescription image is normalized for Flutter/PDF rendering, and photographed signatures are flattened onto pure white before being inserted into the white hospital form.

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

V0.11.3 validates the full-width MRH form, signature extraction under uneven paper lighting, signature white-paper compositing, medication identification/safety behavior and the generated iPhone web-shell viewport protections.

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
- `lib/services/` — medication registry, pharmacy API, NIDS, biometric/browser session guards, persistence, signature vault/rendering and print generation
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
