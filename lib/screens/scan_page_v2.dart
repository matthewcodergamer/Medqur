import 'package:flutter/material.dart';
import '../models.dart';
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
  String? message;

  Future<void> _scan() async {
    final result = await Navigator.of(context).push<ScanCapture>(MaterialPageRoute(builder: (_) => LiveScannerPage(purpose: purpose)));
    if (result == null || !mounted) return;
    Patient? match;
    NidsTestCredential? nidsTest;
    String status;
    if (purpose == ScanPurpose.patientWristband) {
      match = _findEncounter(result.value);
      status = match == null ? 'Encounter token not found in this device workspace.' : 'Patient wristband matched.';
    } else if (purpose == ScanPurpose.medication) {
      match = _findMedication(result.value);
      status = match == null ? 'Barcode captured. It is not mapped to an active medication order here.' : 'Medication barcode matched an active order.';
    } else if (purpose == ScanPurpose.nidsCard) {
      nidsTest = NidsTestCredential.tryParse(result.value);
      status = nidsTest == null
          ? 'Identity code captured, but it is not a Medqur NIDS TEST credential. NIRA verification is not connected.'
          : 'Medqur NIDS TEST credential decoded successfully.';
    } else {
      status = 'Staff credential captured.';
    }
    setState(() {
      capture = result;
      matchedPatient = match;
      nidsTestCredential = nidsTest;
      message = status;
    });
  }

  Patient? _findEncounter(String raw) {
    for (final patient in widget.patients) {
      if (raw == patient.encounterToken || raw == patient.id) return patient;
    }
    return null;
  }

  Patient? _findMedication(String raw) {
    for (final patient in widget.patients) {
      for (final medication in patient.medications) {
        if (medication.productCode != null && medication.productCode == raw) return patient;
      }
    }
    return null;
  }

  Future<void> _openGenerator() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NidsTestCredentialPage()));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('Scan', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('One camera for patient, identity, staff, QR, and medication barcode workflows.'),
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _choice('Wristband', ScanPurpose.patientWristband),
          _choice('NIDS / NIC', ScanPurpose.nidsCard),
          _choice('Medication', ScanPurpose.medication),
          _choice('Staff ID', ScanPurpose.staffBadge),
        ]),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: _scan, icon: const Icon(Icons.camera_alt_rounded), label: Text(purpose.title)),
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
            highlighted: matchedPatient != null || nidsTestCredential != null,
            onTap: matchedPatient == null ? null : () => widget.onOpenPatient(matchedPatient!),
            child: Row(children: [
              Icon(
                matchedPatient != null || nidsTestCredential != null ? Icons.verified_rounded : Icons.qr_code_rounded,
                color: matchedPatient != null || nidsTestCredential != null ? medqurGreen : medqurBlue,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  message ?? 'Captured',
                  style: TextStyle(
                    color: matchedPatient != null || nidsTestCredential != null ? medqurGreen : medqurInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                if (nidsTestCredential != null) ...[
                  Text(nidsTestCredential!.fullName, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    'DOB ${nidsTestCredential!.dateOfBirth} • ${nidsTestCredential!.nationalIdNumber}',
                    style: const TextStyle(color: Color(0xFF65748A), fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  const Text('TEST ONLY • not NIRA verified', style: TextStyle(color: medqurRed, fontSize: 10, fontWeight: FontWeight.w800)),
                ] else
                  Text(matchedPatient?.name ?? capture!.value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF65748A), fontSize: 12)),
                const SizedBox(height: 3),
                Text(capture!.format.name, style: const TextStyle(color: Color(0xFF8793A4), fontSize: 11)),
              ])),
              if (matchedPatient != null) const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        const SizedBox(height: 18),
        const SoftCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, color: medqurBlue), SizedBox(width: 12), Expanded(child: Text('The scanner accepts QR codes and standard package barcodes. NIDS TEST QRs are self-contained prototype data only; production identity must be verified by an approved NIRA integration. Medication matches must use an approved drug/product master.'))])),
      ],
    );
  }

  Widget _choice(String label, ScanPurpose value) => ChoiceChip(label: Text(label), selected: purpose == value, onSelected: (_) => setState(() {
        purpose = value;
        capture = null;
        matchedPatient = null;
        nidsTestCredential = null;
        message = null;
      }));
}
