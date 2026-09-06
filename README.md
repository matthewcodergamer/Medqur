# Medqur

Medqur is a Flutter clinical-workflow prototype for web, Android and iOS with a PostgreSQL/Node service layer. The project explores Jamaican public-health patient identity, triage, secure staff credentials, prescribing, medication safety, pharmacy, clinical orders, diagnostic worklists, wristbands, printing and point-of-care scanning.

> **Prototype / development system only.** This repository is not an official Ministry of Health & Wellness, NIRA, Regional Health Authority, e-Care/SystmOne or regulatory system. Do not use the public prototype with real protected health information or as the sole basis for diagnosis, treatment, identity verification, prescribing, dispensing or medication administration.

## V0.14 — voice-note prescription workflow

V0.14 implements the September 5 voice-note changes to prescribing and pharmacy while keeping the V0.13 responsive, less-is-more UI rules.

### Reopen signed medication orders

Doctor medication orders are no longer just a one-way action. From **Orders**, a doctor can open a medication order again and review:

- patient and encounter context
- medication, dose, route and frequency
- duration and instructions where recorded
- prescribing doctor name and six-digit staff ID
- signing time and SHA-256 attestation
- saved signature artwork when it is available on the device
- revision history and amendment reasons

The order-detail screen stays compact on phones and centered/readable on tablets and desktop.

### Amend instead of overwrite

A doctor can open an active prescription and choose **Amend prescription**. The composer is prefilled from the existing order. The doctor must state why the order is changing, then sign the new revision.

Medqur keeps the previous signed revision as **superseded** instead of silently overwriting it. The new revision receives its own signature attestation and audit-facing metadata. This preserves a readable history for changes such as moving a medicine from `1x per day` to `3x per day`.

The public Flutter prototype persists this revision ledger locally. The existing connected `/v1/orders` endpoint continues to verify and persist new signed prescriptions; an atomic central amendment endpoint is still required before a connected production deployment can claim server-side prescription revisioning is complete.

### Pharmacy dispensing section

The pharmacist workspace now opens on **Dispense** and shows signed prescriptions waiting to be dispensed. A pharmacist can confirm the prescription and mark it dispensed. The prototype then:

- records the dispense ID, pharmacist and time in the prescription ledger
- links the dispense ID back to the patient's medication order
- adds the dispense event to the patient encounter timeline
- moves the item from pending to recently dispensed

Inventory, receiving and recall functions remain separate tabs so the dispensing queue is not buried under stock-management controls.

The Node backend already contains a verified-inventory `/v1/pharmacy/dispense` endpoint. The current public Flutter dispensing queue is intentionally usable without external infrastructure; full central dispense synchronization still requires the configured facility inventory/location adapter.

### Blue prescription ink only

The old blue/black choice has been removed from the active prescribing and signature UI. Prescription handwriting/signature output is now normalized to **blue**.

- drawing on the device shows blue strokes
- paper-photo signatures are cleaned and normalized to blue on white
- legacy saved black artwork is converted to blue when rendered for prescription use
- no blue/black selector is shown to the doctor

A stored signature remains visual artwork, not an authentication factor. The authenticated staff account, facility, signing time and audit record remain authoritative.

### Signature photo cleanup

For a paper signature, the doctor writes on clean white paper and photographs it. The processor estimates the local paper background, isolates handwriting rather than every dark pixel, removes camera noise, rejects captures that still look like a large filled blob, crops the detected strokes and renders them as reusable blue signature artwork on white.

This directly addresses the previous failure where a photographed signature could turn into a large dark block.

### Frequency 1x–20x

The controlled frequency selector is now exactly **1x through 20x** per hour, day or week. Dose amount remains controlled at 1–100 with the existing supported mass/volume units.

### Expanded alphabetical administration routes

The route list is now alphabetized and substantially broader, including Buccal, enteral/feeding tube, epidural, inhaled, intradermal, IM, intranasal, IO, intrathecal, IV, nebulized, ophthalmic, oral, otic, rectal, subcutaneous, sublingual, topical, transdermal and vaginal routes.

The list lives in a dropdown instead of filling the prescription screen.

### Common directions and warnings

Common directions are now in a searchable picker rather than a large chip wall. Examples include:

- Take with food / before food / after food
- Take on an empty stomach
- Take with water / a full glass of water
- Take with milk / Do not take with milk
- Avoid alcohol
- May cause drowsiness
- Do not drive or operate machinery if drowsy
- Avoid grapefruit or grapefruit juice
- Complete the full course
- Do not crush or chew
- Shake well before use
- Rinse mouth after use
- Use as directed

These are optional prescribing templates only. Medqur does not infer that a template is appropriate for a medicine; the prescriber remains responsible for selecting the correct instruction.

## Responsive less-is-more UI contract

V0.13 established the responsive design contract and V0.14 keeps it:

- no horizontal overflow
- stack/reflow controls before they become cramped
- compact phone layouts instead of tiny text
- capped central content width on desktop
- secondary descriptions kept short
- long option libraries opened only when requested
- semantic color reserved for action, status, acuity and safety
- readable touch targets on small screens
- responsive regression checks at phone, tablet and desktop widths

Shared layout primitives live in `lib/widgets/medqur_responsive.dart`.

## Staff authentication and security

Every modeled health worker uses a unique six-digit Medqur staff number plus a separate machine-readable staff credential.

- **iOS native app:** Flutter `local_auth` uses the operating-system Face ID / Touch ID prompt when enrolled and supported.
- **Android native app:** uses the operating-system supported biometric prompt.
- **Browser prototype:** uses a six-digit local session PIN. Production web access should move to approved OIDC/WebAuthn/passkeys.
- Signed workforce QR credentials identify the account; the QR is not treated as proof that the person holding the device is the employee.

## Patient and NIDS/NIC workflow

The prototype supports test NIDS/NIC credential scanning, emergency/unknown-patient encounters, P1–P4 clinician-entered triage, patient queues, wristband generation/scanning and patient records visible to authorized clinical/pharmacy roles.

The public prototype does not guess or reverse-engineer a production NIRA QR/API contract. A production deployment must use an authorized NIRA verification boundary.

## Medication and pharmacy foundation

Medication scanning supports common machine-readable package formats including GS1 DataMatrix, EAN/UPC, Code 128 and QR where applicable. The parser can extract/normalize GTIN, lot/batch, expiry/manufacture information and serial data when encoded.

The broader medication system includes:

- searchable medication master
- observed-package fixtures plus explicitly unverified development catalogue data
- doctor prescriptions and reusable signatures
- Mandeville Regional Hospital prescription-form printing
- signed prescription revision ledger
- pharmacist dispensing queue
- pharmacy receiving and lot/expiry inventory
- patient wristband + medication checks
- duplicate-dose/time-window protections
- recall-impact queries
- unit-dose DataMatrix generation where appropriate
- FHIR-shaped Medication, MedicationRequest, MedicationDispense and MedicationAdministration resources

Unknown medication packages remain unresolved rather than being guessed. Public/development catalogue data is not represented as an official Jamaica formulary.

## Clinical orders and support worklists

Doctors can create diagnostic/procedure orders. X-ray, CT, MRI, laboratory, ECG and other clinical-support disciplines receive role-routed worklists and can return result summaries/attachments. Doctors can review completed results. Production imaging should use approved PACS/DICOM integration rather than phone photographs.

## Backend/security foundation

The Node/TypeScript/PostgreSQL layer includes:

- OIDC/JWT authorization boundary
- facility-scoped role assignments
- six-digit workforce identities and signed badge credentials
- medication master, pharmacy and inventory tables
- signed prescription digest verification/persistence
- medication dispense and administration endpoints
- append-only audit events and outbox/realtime patterns
- diagnostic order/result schema
- signed/versioned offline medication catalogue support

Production still requires authoritative external infrastructure for NIRA, Ministry/RHA workforce identity, OIDC/passkeys, e-Care/SystmOne, PACS/DICOM, medication/formulary/regulatory feeds and approved structured allergy/interaction knowledge.

## Validation

GitHub Actions is the release gate on `main` and validates backend TypeScript/PostgreSQL, medication and staff-identity smoke tests, Flutter analysis/tests, Android APK, web release/Pages and unsigned iOS build/package.

V0.14 tests cover:

- frequency values 1x–20x
- alphabetical expanded route vocabulary
- requested common instruction/warning examples
- prescription revision preservation
- superseding an older signed revision instead of overwriting it
- local dispense audit state
- phone/tablet/desktop responsive clinical surfaces

## Key V0.14 files

- `lib/medication_order_options.dart` — controlled dose/frequency/due model
- `lib/medication_prescribing_options.dart` — alphabetical routes and searchable common instructions
- `lib/screens/prescription_composer_page_v2.dart` — blue-only prescribing and signed amendments
- `lib/screens/prescription_order_detail_page.dart` — reopen order, signer/signature and revision history
- `lib/services/prescription_record_store.dart` — local signed revision/dispense ledger
- `lib/screens/pharmacy_page_v2.dart` — dispensing-first pharmacist workspace
- `lib/screens/signature_vault_page_v2.dart` — blue-only draw/photo signature workflow
- `lib/services/signature_rendering.dart` — blue-on-white signature normalization
- `lib/screens/clinical_shell_v14.dart` — doctor → pharmacy workflow wiring

Medqur keeps authoritative external systems behind adapters so the public prototype does not impersonate an official government system.
