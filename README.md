# Medqur

Medqur is a Flutter clinical-workflow prototype for web, iOS and Android. V0.2 focuses on real device interaction while keeping government/EHR integrations explicitly simulated until approved backend interfaces exist.

> **Prototype only:** Do not use this repository for real patient identification, diagnosis, treatment decisions, medication administration or storage of protected health information.

## V0.2

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
- e-Care / SystmOne
- secure browser passkey relying-party server
- production cross-device realtime backend
- production clinical database or audit service

The browser build can use the camera, but secure browser passkeys require a server-generated WebAuthn challenge. V0.2 does not fake that security step; the web sign-in is clearly marked as prototype access.

## Medication identification

Medqur does **not** require every medicine to receive a custom Medqur QR. The scanner accepts both 2D and linear codes. In a production deployment, a scanned GTIN/GS1 code (or a hospital-generated unit-dose code where necessary) would resolve against an approved medication/product master before it can match an active order.

## Demo staff IDs

- Doctor: `MQ-7K4P-92XF`
- Nurse: `MQ-2N8R-41KD`

The ID field starts empty. Use **Use demo ID** for quick public-prototype access.

## Branding

The Medqur wordmark is drawn as vector UI instead of the old raster image, eliminating the grey rectangle visible in some browsers. `assets/medqur_app_icon.svg` is the canonical high-quality app/favicon artwork: blue Medqur mark on white, matching the supplied icon. CI generates Android, iOS and web raster icon sizes from the same geometry.

## Build

GitHub Actions regenerates the Flutter platform scaffolding, adds camera/biometric permissions, creates branded icons, runs analysis, and builds:

- Android release APK
- Flutter web release + `gh-pages`
- unsigned iOS release app

See `.github/workflows/build.yml`.

## Architecture

See [`docs/V0.2_ARCHITECTURE.md`](docs/V0.2_ARCHITECTURE.md) for the backend, FHIR, role, realtime and security boundaries.
