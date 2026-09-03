import 'package:flutter/material.dart';

import '../models.dart';
import '../services/medication_identifier.dart';
import '../services/medication_master.dart';
import '../services/medication_registry.dart';
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
  final MedicationRegistryClient _medicationRegistry = MedicationRegistryClient();

  ScanPurpose purpose = ScanPurpose.patientWristband;
  ScanCapture? capture;
  Patient? matchedPatient;
  NidsTestCredential? nidsTestCredential;
  NidsScanEnvelope? nidsEnvelope;
  MedicationIdentifier? medicationIdentifier;
  MedicationResolution? medicationResolution;
  String? message;
  bool resolvingMedication = false;

  @override
  void dispose() {
    _medicationRegistry.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final result = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(builder: (_) => LiveScannerPage(purpose: purpose)),
    );
    if (result == null || !mounted) return;

    if (purpose == ScanPurpose.medication) {
      final parsed = MedicationIdentifierParser.parse(
        result.value,
        formatName: result.format.name,
      );
      setState(() {
        capture = result;
        medicationIdentifier = parsed;
        medicationResolution = null;
        matchedPatient = _findMedication(parsed);
        nidsEnvelope = null;
        nidsTestCredential = null;
        resolvingMedication = true;
        message = parsed.gtin == null
            ? 'Code captured. Trying medication lookup…'
            : 'GTIN captured. Identifying medication…';
      });
      final resolved = await _medicationRegistry.resolve(parsed);
      if (!mounted) return;
      setState(() {
        medicationResolution = resolved;
        resolvingMedication = false;
        message = matchedPatient != null
            ? 'Medication identified and linked to an active patient order.'
            : resolved.message;
      });
      return;
    }

    Patient? match;
    NidsTestCredential? nidsTest;
    NidsScanEnvelope? identityEnvelope;
    String status;

    if (purpose == ScanPurpose.patientWristband) {
      match = _findEncounter(result.value);
      status = match == null
          ? 'Encounter token not found in this device workspace.'
          : 'Patient wristband matched.';
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
      medicationIdentifier = null;
      medicationResolution = null;
      resolvingMedication = false;
      message = status;
    });
  }

  Future<void> _manualMedicationCode() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter medication code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'GTIN / UPC / barcode value',
            hintText: 'e.g. 363824050287',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Look up'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    final parsed = MedicationIdentifierParser.parse(value);
    setState(() {
      capture = null;
      medicationIdentifier = parsed;
      medicationResolution = null;
      matchedPatient = _findMedication(parsed);
      resolvingMedication = true;
      message = 'Checking medication catalogue…';
    });
    final resolved = await _medicationRegistry.resolve(parsed);
    if (!mounted) return;
    setState(() {
      medicationResolution = resolved;
      resolvingMedication = false;
      message = resolved.message;
    });
  }

  Future<void> _searchMedicationName() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search medicine'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Brand, generic name or type',
            hintText: 'e.g. pregabalin, CEFUR, antibiotic',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query == null || query.isEmpty || !mounted) return;

    final local = MedicationMasterCatalog.search(query);
    final references = await _medicationRegistry.searchByName(query);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Medication results', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                const Text(
                  'Package/catalogue matches are shown first. Public terminology results are reference-only until a package or approved product record is verified.',
                  style: TextStyle(color: Color(0xFF65748A), fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (local.isNotEmpty) ...[
                        const _SearchSectionLabel('PACKAGE / LOCAL CATALOGUE'),
                        for (final product in local)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEAF1FF),
                              foregroundColor: medqurBlue,
                              child: Icon(Icons.medication_outlined),
                            ),
                            title: Text(product.displayName),
                            subtitle: Text(
                              [
                                if (product.therapeuticCategory?.isNotEmpty == true)
                                  product.therapeuticCategory!,
                                product.sourceLabel,
                              ].join(' • '),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _selectLocalMedication(product);
                            },
                          ),
                        const Divider(height: 24),
                      ],
                      const _SearchSectionLabel('PUBLIC TERMINOLOGY REFERENCE'),
                      if (references.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No additional public terminology matches were returned.'),
                        )
                      else
                        for (final item in references)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.menu_book_outlined, color: Color(0xFF65748A)),
                            title: Text(item.name),
                            subtitle: Text(
                              item.rxcui.isEmpty
                                  ? item.source
                                  : 'RxCUI ${item.rxcui} • ${item.source}',
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectLocalMedication(MedicationProduct product) {
    if (!mounted) return;
    final raw = product.gtin ??
        (product.rawAliases.isNotEmpty ? product.rawAliases.first : product.id);
    final identifier = MedicationIdentifierParser.parse(raw);
    final trust = switch (product.source) {
      MedicationProductSource.jamaicaApproved => MedicationResolutionTrust.jamaicaApproved,
      MedicationProductSource.publicReference => MedicationResolutionTrust.publicReference,
      MedicationProductSource.observedPackage => MedicationResolutionTrust.observedPackage,
      MedicationProductSource.prototype => MedicationResolutionTrust.prototype,
    };
    setState(() {
      capture = null;
      medicationIdentifier = identifier;
      medicationResolution = MedicationResolution(
        identifier: identifier,
        product: product,
        trust: trust,
        source: product.sourceLabel,
        message: 'Medication selected from the searchable catalogue.',
      );
      matchedPatient = _findMedication(identifier);
      resolvingMedication = false;
      message = 'Medication selected from the searchable catalogue.';
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
    final resolution = medicationResolution;
    final medicationApproved = resolution?.approvedForClinicalAutomation == true;
    final verified = matchedPatient != null || nidsTestCredential != null || medicationApproved;
    final resultColor = medicationIdentifier != null && !medicationApproved
        ? (resolution?.found == true ? medqurBlue : medqurAmber)
        : verified
            ? medqurGreen
            : medqurBlue;

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('Scan', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'Scan patient, identity, staff and medication codes.',
          style: TextStyle(color: Color(0xFF65748A)),
        ),
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
        if (purpose == ScanPurpose.medication) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _manualMedicationCode,
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('Enter code'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _searchMedicationName,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Search'),
              ),
            ),
          ]),
        ],
        if (purpose == ScanPurpose.nidsCard) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openGenerator,
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('Create a NIDS test QR'),
          ),
        ],
        const SizedBox(height: 18),
        if (resolvingMedication)
          const SoftCard(
            child: Row(children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Identifying medication…',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          ),
        if (capture != null || medicationIdentifier != null)
          Padding(
            padding: EdgeInsets.only(top: resolvingMedication ? 10 : 0),
            child: SoftCard(
              highlighted: verified,
              onTap: matchedPatient == null ? null : () => widget.onOpenPatient(matchedPatient!),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(
                  verified ? Icons.verified_rounded : Icons.qr_code_scanner_rounded,
                  color: resultColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message ?? 'Captured',
                        style: TextStyle(
                          color: resultColor,
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                        _MedicationResult(
                          identifier: medicationIdentifier!,
                          resolution: medicationResolution,
                        ),
                      ] else
                        Text(
                          matchedPatient?.name ?? capture!.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF65748A), fontSize: 12),
                        ),
                      if (capture != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Scanner: ${capture!.format.name}',
                          style: const TextStyle(color: Color(0xFF8793A4), fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                if (matchedPatient != null) const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
        if (purpose == ScanPurpose.medication) ...[
          const SizedBox(height: 14),
          const Text(
            'Manufacturer code first • searchable fallback available • unknown products require pharmacy verification.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF748297), fontSize: 11, height: 1.35),
          ),
        ],
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
          medicationResolution = null;
          resolvingMedication = false;
          message = null;
        }),
      );
}

class _SearchSectionLabel extends StatelessWidget {
  const _SearchSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF8793A4),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
      );
}

class _MedicationResult extends StatelessWidget {
  const _MedicationResult({required this.identifier, required this.resolution});

  final MedicationIdentifier identifier;
  final MedicationResolution? resolution;

  @override
  Widget build(BuildContext context) {
    final product = resolution?.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product?.displayName ?? 'Medication code captured',
          style: const TextStyle(
            color: medqurInk,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        if (product != null) ...[
          const SizedBox(height: 6),
          if (product.therapeuticCategory?.isNotEmpty == true)
            _DetailLine('Type', product.therapeuticCategory!),
          if (product.ingredients.isNotEmpty)
            _DetailLine('Ingredient', product.ingredients.join(' + ')),
          if (product.dosageForm.isNotEmpty)
            _DetailLine('Form', product.dosageForm),
          if (product.manufacturer.isNotEmpty)
            _DetailLine('Manufacturer', product.manufacturer),
          if (product.prescriptionStatus?.isNotEmpty == true)
            _DetailLine('Status', product.prescriptionStatus!),
        ],
        const SizedBox(height: 7),
        Text(
          identifier.summary,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF65748A), fontSize: 11, height: 1.35),
        ),
        if (resolution != null) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            StatusPill(
              label: resolution!.trustLabel,
              color: resolution!.approvedForClinicalAutomation
                  ? medqurGreen
                  : resolution!.found
                      ? medqurBlue
                      : medqurAmber,
            ),
            if (resolution!.onlineLookup)
              const StatusPill(label: 'Online lookup', color: medqurBlue),
          ]),
          const SizedBox(height: 6),
          Text(
            'Source: ${resolution!.source}',
            style: const TextStyle(color: Color(0xFF8793A4), fontSize: 10),
          ),
          if (product?.jamaicaReference?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              product!.jamaicaReference!,
              style: const TextStyle(color: medqurBlue, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(color: Color(0xFF65748A), fontSize: 11, height: 1.3),
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}
