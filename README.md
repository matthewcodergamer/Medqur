# Medqur

Medqur is a Flutter clinical-workflow prototype for web, Android and iOS with a PostgreSQL/Node service layer. The project explores Jamaican public-health patient identity, triage, secure staff credentials, prescribing, medication safety, pharmacy, clinical orders, diagnostic worklists, wristbands, printing and point-of-care scanning.

> **Prototype / development system only.** This repository is not an official Ministry of Health & Wellness, NIRA, Regional Health Authority, e-Care/SystmOne or regulatory system. Do not use the public prototype with real protected health information or as the sole basis for diagnosis, treatment, identity verification, prescribing, dispensing or medication administration.

## V0.13 — responsive less-is-more clinical UX

V0.13 turns responsiveness into a shared product rule rather than a collection of one-off screen fixes. The same workflow is expected to remain calm, readable and touch-safe from a 320 px phone to a 1440 px desktop browser.

### Responsive foundation

The app now has shared responsive primitives in `lib/widgets/medqur_responsive.dart`:

- `MedqurResponsive` — common phone/tablet/desktop breakpoints and adaptive page padding
- `ResponsiveFields` — form controls that stack before they become cramped
- `ResponsiveActions` — action controls that become full-width rows on narrow screens
- `ResponsiveGrid` — adaptive dashboard/card grids
- `CompactHelperText` — capped secondary helper copy

`MedqurPage`, `MedqurPageHeader`, `SoftCard`, `SectionTitle`, `StatusPill`, patient context, dashboard cards and the clinical shell now consume the shared layout rules rather than assuming a fixed phone or desktop width.

### Less text, stronger hierarchy

Normal workflow screens now favour the action and clinical context first. Secondary explanation is intentionally short and capped so a phone screen is not filled with paragraphs before the user reaches the control they need. Long standards/prototype explanations belong in Help/About or a dedicated detail surface.

Critical clinical information is the exception: patient identity, acuity, allergy/safety status, medication, dose, route and timing must remain available even when secondary copy is reduced.

### Phone, tablet and desktop behavior

- narrow phones stack fields/actions before labels or menus can overflow
- tiny screens reduce decorative or secondary elements rather than shrinking everything
- tablets use compact grids where useful
- desktop pages keep a readable maximum content width instead of stretching forms across the monitor
- large desktop screens use the navigation rail; phone/tablet screens keep bottom navigation
- facility selection and dashboard cards reflow into adaptive grids
- top bars, status chips and headings use bounded text and overflow-safe layouts

The standing responsive contract is documented in `docs/V0.13_RESPONSIVE_UX.md`.

### Responsive regression tests

Widget tests exercise representative widths of 320, 360, 390, 768, 1024 and 1440 px. Core layout primitives, the dashboard and facility picker are checked for Flutter layout exceptions/overflows so future changes cannot silently reintroduce phone-only or desktop-only breakage.

## V0.12.1 — structured medication directions and unambiguous encounter time

V0.12.1 implements the follow-up September 2026 medication-order and timeline voice notes.

### Controlled medication dose

Medication orders no longer use a free-text dose box in the doctor prescription flow or the patient medication-order sheet. The dose is split into two controlled selections:

- **amount:** 1 through 100
- **unit:** grams (`g`), milligrams (`mg`), micrograms (`mcg`), millilitres (`mL`), microlitres (`µL`) or litres (`L`)

When a medication product has a strength that maps exactly into those selectors, Medqur can preselect it. Values outside the configured 1–100 range are not silently coerced.

### Controlled frequency

Frequency is now entered exactly as a structured combination rather than free text:

- **1x through 10x**
- the word **per**
- **hour, day or week**

Examples stored/displayed by the prototype are `1x per day`, `2x per day` and `3x per hour`.

### Due immediately or due on a selected date/time

Every new medication order explicitly chooses one of two due modes:

- **Immediately** — the first dose becomes due at the time the order is signed/sent.
- **On date / time** — the doctor chooses the due date and time using the existing calendar and time picker.

The previous optional schedule control has therefore become an explicit clinical choice rather than an ambiguous empty field.

### Encounter timeline clock

Encounter timeline text now uses an explicit **24-hour `HH:mm` clock**. The patient timeline UI labels this convention so entries such as `06:37` and `18:37` cannot be confused with AM/PM times. Shared `ClinicalClock` formatting is used for new medication/prescription timeline events and due-date displays.

Automated tests cover the 1–100 dose selector, 1x–10x frequency selector, supported dose units, hour/day/week periods, immediate vs scheduled due behavior, strength preset parsing and 24-hour time formatting.

## V0.12 — clinical orders and support-staff worklists

V0.12 implements the workforce workflow described in the September 2026 Medqur voice-note review.

### Responsibility model

- **Doctors** can open patient records, prescribe medication, create diagnostic/procedure orders, review returned results, assign patients and administer medication when clinically appropriate.
- **Nurses / clinical support** can open patient records and read doctor orders. They cannot originate prescriptions or diagnostic orders. Work is routed according to discipline.
- **Radiography / X-ray staff** receive X-ray orders and return the completed result.
- **CT staff** receive CT orders.
- **MRI staff** receive MRI orders.
- **Laboratory staff** receive laboratory orders and return results.
- **ECG staff** receive ECG/EKG orders. Registered nurses are also allowed to complete bedside ECG capture in the prototype workflow.
- **Respiratory / ultrasound / other clinical-support roles** have their own routing categories.
- **Pharmacy** remains separated from doctor ordering and clinical-support worklists. Pharmacists can access the patient information needed for prescription fulfilment and medication safety but cannot prescribe or originate diagnostic investigations.

All modeled workers still use a stable six-digit Medqur staff number. The existing Flutter `StaffRole` enum stays backward-compatible while the worker title/authoritative role resolves the more specific clinical discipline.

### Doctor Orders workspace

The doctor workspace now combines:

- new prescription
- new test/procedure
- open diagnostic orders
- active medication orders
- recently completed diagnostic results

Supported diagnostic order types include X-ray, CT, MRI, ultrasound, laboratory, ECG/EKG, respiratory testing and a generic clinical investigation route. Each order includes patient/encounter, facility, study name, instructions, priority, requesting doctor, destination discipline and status.

### Clinical-support Worklist

Clinical-support users now see a role-specific **Worklist** rather than the doctor prescription interface. Work is filtered/routed by discipline and keeps unrelated investigations read-only. Nursing users also continue to see medication-administration tasks.

A routed order can move through:

`Ordered → In progress → Completed`

The performing worker can enter a structured result summary and attach an image/file from the phone camera or photo library.

For the prototype, this supports workflows such as photographing an existing paper ECG printout and attaching it to the encounter so the doctor can review it. Production X-ray/CT/MRI imaging should use approved PACS/DICOM integration or an approved clinical document/object store rather than photographing diagnostic images.

### Diagnostic result persistence

The Flutter prototype persists diagnostic orders/results locally with `SharedPreferences` so the complete doctor → support worklist → result → doctor review loop works without external infrastructure.

The backend migration `006_clinical_orders_and_support_staff.sql` adds:

- expanded clinical workforce role values
- `diagnostic_orders`
- `diagnostic_order_attachments`
- discipline/status indexes
- synthetic radiography, CT, laboratory and ECG demo workers

The attachment table limits individual prototype payloads to 3 MB. Production imaging must move to approved large-object/PACS storage.

### Doctor medication administration

Doctors are now explicitly allowed to administer medication in both the Flutter access policy and the backend authorization compatibility boundary. This does **not** turn doctors into a general nurse role; the backend exception is intentionally narrow to the existing nurse-only medication-administration endpoint.

### Synthetic V0.12 staff

These identities are development fixtures only:

| Staff ID | Role |
|---|---|
| `482731` | Medical Officer / doctor |
| `615204` | Registered Nurse |
| `739182` | Hospital Pharmacist |
| `246810` | Radiography Technologist |
| `357912` | CT Technologist |
| `468135` | Medical Laboratory Technologist |
| `579246` | ECG Technician |

The role-aware sign-in screen preserves native biometric authentication and the browser PIN boundary while allowing these synthetic identities to exercise the new workflow.

## Staff authentication and security

Every modeled health worker uses a unique six-digit staff number plus a separate machine-readable staff credential.

- **iOS native app:** Flutter `local_auth` uses the operating-system Face ID / Touch ID prompt when enrolled and supported.
- **Android native app:** uses the operating-system fingerprint / supported biometric prompt.
- **Browser prototype:** uses a six-digit local session PIN. This is only a prototype guard; production web authentication should use approved OIDC/WebAuthn/passkeys.
- Signed workforce QR credentials identify the account; the QR is not treated as proof that the person holding the device is the employee.

## Patient and NIDS/NIC workflow

The prototype supports:

- NIDS/NIC test credential scanning
- emergency / unknown-patient encounters
- patient record and encounter persistence
- P1–P4 clinician-entered triage
- patient queues
- patient wristband generation/scanning
- patient files visible to authorized clinical/pharmacy staff

The public prototype does not guess or reverse-engineer a production NIRA QR/API contract. A production system must use an authorized NIRA verification boundary.

## Medication, prescribing and pharmacy

Medication scanning supports common machine-readable package formats including GS1 DataMatrix, EAN/UPC, Code 128 and QR where applicable. The parser can extract/normalize GTIN, lot/batch, expiry/manufacture information and serial data when encoded.

The medication/pharmacy system includes:

- medication master and search
- observed-package fixtures plus an explicitly unverified development catalogue
- doctor prescriptions and reusable signature workflow
- SRHA/Mandeville Regional Hospital prescription-form printing
- pharmacy receiving, verification, lot/expiry inventory and dispensing
- patient wristband + medication package checks
- duplicate-dose/time-window protections
- recall-impact queries
- unit-dose DataMatrix generation when no suitable manufacturer unit code exists
- FHIR-shaped Medication, MedicationRequest, MedicationDispense and MedicationAdministration resources

Unknown medication packages remain unresolved rather than being guessed. Public/development catalogue data is not represented as an official Jamaica formulary.

## Prescription and signature workflow

Doctors can create a prescription, select medication, controlled dose amount/unit, route, controlled frequency, duration/instructions, choose immediate or scheduled due time, choose blue or black pen styling, select a saved signature, preview the hospital prescription and print/share the resulting PDF.

Photographed signatures are isolated from clean white paper and normalized onto prescription-safe white. A saved signature picture is not authentication by itself; prescription submissions remain bound to the authenticated staff account, facility, signing time and server-side SHA-256 attestation.

## Printing

- Patient wristbands: dynamic PDF → system print service → configured printer.
- Prescriptions: dynamic SRHA/MRH form → system print service / save PDF.
- Future production path: facility Print Bridge plus Zebra healthcare wristband/label adapters.

## Less-is-more clinical UI

The interface follows the restrained Medqur design direction:

- phone-first responsive layout with regression coverage down to 320 px
- Inter-first typography with platform fallbacks
- capped central content width and useful whitespace on desktop
- compact phone spacing and adaptive tablet/desktop grids
- controls stack instead of squeezing or creating horizontal overflow
- secondary helper copy is capped; detail uses progressive disclosure
- white/light-neutral surfaces with dark navy text
- blue mainly for actions
- semantic green/amber/red only for safety/status/acuity
- short, low-distraction transitions
- no cartoon clinical workflow styling

See `docs/V0.13_RESPONSIVE_UX.md` for the standing responsive contract.

## Backend/security foundation

The Node/TypeScript/PostgreSQL layer includes:

- OIDC/JWT authorization boundary
- facility-scoped role assignments
- six-digit workforce identities and signed badge credentials
- medication master, pharmacy and inventory tables
- diagnostic order/result schema
- append-only audit events and outbox/realtime patterns
- signed prescription integrity checks
- signed/versioned offline medication catalogue support

Production still requires authoritative external infrastructure for NIRA, Ministry/RHA workforce identity, OIDC/passkeys, e-Care/SystmOne, PACS/DICOM, medication/formulary/regulatory feeds and approved structured allergy/interaction knowledge.

## Validation

GitHub Actions is the release gate on `main` and validates the backend TypeScript/PostgreSQL foundation, Flutter analysis/tests, Android APK, web release/Pages and unsigned iOS build/package.

V0.13 adds automated responsive checks for:

- core cards/headers/forms at 320, 360, 390, 768, 1024 and 1440 px
- dashboard reflow at phone, tablet and desktop widths
- facility-picker reflow at phone, tablet and desktop widths
- Flutter layout exceptions/overflow regressions in the tested surfaces

V0.12.1 adds automated tests for:

- dose amounts 1–100
- dose-unit vocabulary
- frequency counts 1x–10x
- hour/day/week frequency periods
- immediate and scheduled due modes
- product-strength preset parsing without coercing out-of-range values
- explicit 24-hour encounter time

V0.12 adds automated tests for:

- doctor prescribing/test-order permissions
- doctor medication administration permission
- nurse/support restrictions
- discipline-routed diagnostic work
- pharmacist restrictions
- diagnostic-order serialization
- diagnostic attachment persistence

## Repository structure

- `lib/widgets/medqur_responsive.dart` — shared breakpoints, stacking, grids and compact helper text
- `docs/V0.13_RESPONSIVE_UX.md` — standing responsive/less-is-more UX contract
- `test/responsive_layout_test.dart` — multi-viewport layout regression tests
- `lib/clinical_clock.dart` — explicit 24-hour clinical timestamp formatting
- `lib/medication_order_options.dart` — controlled dose/frequency/due option model
- `lib/clinical_models.dart` — workforce categories, support disciplines and diagnostic order/result models
- `lib/screens/clinical_shell_v3.dart` — role-aware responsive doctor/support/pharmacy application shell
- `lib/screens/doctor_orders_hub_page.dart` — doctor prescriptions, investigations and results
- `lib/screens/clinical_worklist_page.dart` — clinical-support task routing
- `lib/screens/clinical_order_composer_page.dart` — doctor test/procedure ordering
- `lib/screens/clinical_order_detail_page.dart` — task execution/result upload/review
- `lib/services/clinical_order_store.dart` — local prototype persistence
- `backend/sql/006_clinical_orders_and_support_staff.sql` — server data model and workforce roles
- `backend/` — identity, medication, pharmacy, audit and interoperability services

## Next production integrations

- synchronize diagnostic orders/results through authenticated backend endpoints
- PACS/DICOM imaging integration for X-ray/CT/MRI
- approved laboratory/LIS interface
- structured ECG device/digital report interface
- production workforce directory for all support disciplines
- e-Care/SystmOne integration under Ministry/vendor-approved interfaces
- conflict-safe offline/realtime synchronization
- accessibility and formal clinical human-factors validation

Medqur keeps authoritative external systems behind adapters so the public prototype does not impersonate an official government system.
