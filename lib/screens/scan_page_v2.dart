import 'package:flutter/material.dart';

import '../models.dart';
import '../services/medication_identifier.dart';
import '../services/medication_master.dart';
import '../services/nids_identity_gateway.dart';
import '../services/nids_test_credential.dart';
import '../widgets/common.dart';
import 'live_scanner_page.dart';
import 'nids_test_credential_page.dart';

class ScanPageV2 extends StatefulWidget {
  const ScanPageV2({super.key, required this.patients, required this.onOpenPatient});
  final List<Patient> patients;
  final ValueChanged<Patient> onOpenPatient;

  @override
  State<ScanPageV2> createState() => _ScanPageV2State();
}

class _ScanPageV2State extends State<ScanPageV2> {
  ScanPurpose purpose = ScanPurpose.patientWristband;
  ScanCapture? capture;
  Patient? matchedPatient;
  NidsTestCredential? nidsTestCredential;
  NidsScanEnvelope? nidsEnvelope;
  MedicationIdentifier? medicationIdentifier;
  MedicationProduct? medicationProduct;
  String? message;

  Future<void> _scan() async {
    final result = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(builder: (_) => LiveScannerPage(purpose: purpose)),
    );
    if (result == null || !mounted) return;

    Patient? match;
    NidsTestCredential? nidsTest;
    NidsScanEnvelope? identityEnvelope;
    MedicationIdentifier? medication;
    MedicationProduct? product;
    String status;

    if (purpose == ScanPurpose.patientWristband) {
      match = _findEncounter(result.value);
      status = match == null
          ? 'Encounter token not found in this device workspace.'
          : 'Patient wristband matched.';
    } else if (purpose == ScanPurpose.medication) {
      medication = MedicationIdentifierParser.parse(
        result.value,
        formatName: result.format.name,
      );
      product = MedicationMasterCatalog.lookup(medication);
      match = _findMedication(medication);
      if (match != null) {
        status = 'Medication identifier matched an active patient order.';
      } else if (product != null) {
        status = 'Medication identified in the prototype product master.';
      } else if (medication.gtin != null) {
        status = 'GS1 product captured. GTIN parsed, but the product is not in the approved medication master yet.';
      } else {
        status = 'Medication code captured. Product identity requires approved master-data verification.';
      }
    } else if (purpose == ScanPurpose.nidsCard) {
      identityEnvelope = NidsIdentityDecoder.decode(result.value);
      nidsTest = identityEnvelope.testCredential;
      status = nidsTest != null
          ? 'Medqur NIDS TEST credential decoded successfully.'
          : 'NIC QR captured successfully. Real patient autofill is locked until an approved NIRA verification gateway confirms this credential.';
    } else {
      status = 'Staff credential captured.';
    }

    setState(() {
      capture = result;
      matchedPatient = match;
      nidsTestCredential = nidsTest;
      nidsEnvelope = identityEnvelope;
      medicationIdentifier = medication;
      medicationProduct = product;
      message = status;
    });
  }

  Patient? _findEncounter(String raw) {
    for (final patient in widget.patients) {
      if (raw == patient.encounterToken ||
          raw == patient.effectiveEncounterId ||
          raw == patient.id) {
        return patient;
      }
    }
    return null;
  }

  Patient? _findMedication(MedicationIdentifier scanned) {
    for (final patient in widget.patients) {
      for (final medication in patient.medications) {
        final mappedRaw = medication.productCode;
        if (mappedRaw == null || mappedRaw.isEmpty) continue;
        final mapped = MedicationIdentifierParser.parse(mappedRaw);
        if (mapped.gtin != null && scanned.gtin != null) {
          if (mapped.gtin == scanned.gtin) return patient;
        } else if (mapped.rawValue == scanned.rawValue) {
          return patient;
        }
      }
    }
    return null;
  }

  Future<void> _openGenerator() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NidsTestCredentialPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final verified = matchedPatient != null || nidsTestCredential != null;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('Scan', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('One camera for patient, identity, staff, QR, GS1 DataMatrix, and medication barcode workflows.'),
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _choice('Wristband', ScanPurpose.patientWristband),
          _choice('NIDS / NIC', ScanPurpose.nidsCard),
          _choice('Medication', ScanPurpose.medication),
          _choice('Staff ID', ScanPurpose.staffBadge),
        ]),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _scan,
          icon: const Icon(Icons.camera_alt_rounded),
          label: Text(purpose.title),
        ),
        if (purpose == ScanPurpose.nidsCard) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openGenerator,
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('Create a NIDS test QR'),
          ),
        ],
        const SizedBox(height: 18),
        if (capture != null)
          SoftCard(
            highlighted: verified,
            onTap: matchedPatient == null ? null : () => widget.onOpenPatient(matchedPatient!),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                verified ? Icons.verified_rounded : Icons.qr_code_rounded,
                color: verified ? medqurGreen : medqurBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message ?? 'Captured',
                      style: TextStyle(
                        color: verified ? medqurGreen : medqurInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (nidsTestCredential != null) ...[
                      Text(
                        nidsTestCredential!.fullName,
                        style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'DOB ${nidsTestCredential!.dateOfBirth} • ${nidsTestCredential!.nationalIdNumber}',
                        style: const TextStyle(color: Color(0xFF65748A), fontSize: 12),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'TEST ONLY • not NIRA verified',
                        style: TextStyle(color: medqurRed, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ] else if (nidsEnvelope != null) ...[
                      Text(
                        nidsEnvelope!.safeLabel,
                        style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Credential fingerprint ${nidsEnvelope!.fingerprint}',
                        style: const TextStyle(color: Color(0xFF65748A), fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Raw NIC data is not trusted for patient autofill until verified by NIRA.',
                        style: TextStyle(color: medqurAmber, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ] else if (medicationIdentifier != null) ...[
                      Text(
                        medicationProduct?.displayName ?? medicationIdentifier!.summary,
                        style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800),
                      ),
                      if (medicationIdentifier!.gtin != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          medicationIdentifier!.summary,
                          style: const TextStyle(color: Color(0xFF65748A), fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        medicationProduct != null
                            ? 'Prototype master-data match'
                            : 'Pharmacist/master-data verification required before clinical use',
                        style: TextStyle(
                          color: medicationProduct != null ? medqurGreen : medqurAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ] else
                      Text(
                        matchedPatient?.name ?? capture!.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF65748A), fontSize: 12),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      capture!.format.name,
                      style: const TextStyle(color: Color(0xFF8793A4), fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (matchedPatient != null) const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        const SizedBox(height: 18),
        const SoftCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: medqurBlue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Medication scanning now parses common GS1 identifiers, including GTIN, lot, expiry and serial data when present. Real NIC QR codes can be captured by the camera, but production autofill must use an approved NIRA verification interface instead of trusting unverified QR contents.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _choice(String label, ScanPurpose value) => ChoiceChip(
        label: Text(label),
        selected: purpose == value,
        onSelected: (_) => setState(() {
          purpose = value;
          capture = null;
          matchedPatient = null;
          nidsTestCredential = null;
          nidsEnvelope = null;
          medicationIdentifier = null;
          medicationProduct = null;
          message = null;
        }),
      );
}
