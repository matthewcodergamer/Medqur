# Medqur

Medqur is a mobile-first **clinical workflow concept** for Jamaica. This repository contains a Flutter prototype designed to run from one Dart codebase on the web, Android, and iOS.

> **Important:** the public demo uses mock identities, mock patients, mock medication orders, and simulated NIDS / biometric / scanning behavior. It is not connected to NIRA, NIDS, the Ministry of Health & Wellness, e-Care/SystmOne, or any production healthcare system.

## What the V0.1 prototype demonstrates

- Secure staff sign-in concept with staff ID + device biometric/passkey model
- Doctor and nurse role views
- Facility/shift selection with a location suggestion
- Patient queue and triage priority
- NIDS-ready identity verification concept with consent and minimum-data linkage
- Temporary emergency encounters for unidentified patients
- Patient wristband / staff badge / medication scan workflows
- Doctor medication order → nursing medication queue
- Closed-loop medication administration concept
- Digital staff ID
- Human-readable audit trail
- Responsive UI for phones, tablets, and desktop browsers

## Run locally

This repo intentionally keeps the Flutter source small. If platform scaffolding is missing, generate it once:

```bash
flutter create . --org com.herbcure --project-name medqur --platforms=web,android,ios
flutter pub get
flutter run
```

## Build

```bash
flutter build web --release
flutter build apk --release
flutter build ios --release --no-codesign
```

A signed iOS IPA still requires Apple signing credentials and provisioning. The GitHub Actions workflow produces an **unsigned iOS Runner.app** artifact for build verification.

## GitHub Actions

- `Medqur app builds` builds and tests Flutter, then creates Web, Android APK, and unsigned iOS artifacts.
- `Deploy Medqur web` builds the Flutter web release and deploys it to GitHub Pages when Pages is enabled for GitHub Actions.

Expected Pages URL after the deployment succeeds:

`https://matthewcodergamer.github.io/Medqur/`

## Architecture direction

The prototype is intentionally front-end only. Production deployment should use an authenticated backend and standards-based healthcare interoperability (for example FHIR/HL7 where supported), with NIRA/NIDS and e-Care/SystmOne integrations added only through authorized government/vendor interfaces.

The application should not copy the entire NIDS identity database, store biometric templates, or place confidential medical data directly inside wristband QR codes.
