import 'package:flutter/material.dart';

import '../models.dart';
import '../services/medication_identifier.dart';
import '../services/medication_master.dart';
import '../services/medication_registry.dart';
import '../services/nids_identity_gateway.dart';
import '../services/nids_test_credential.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
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
        message = 'Identifying medication…';
      });
      final resolved = await _medicationRegistry.resolve(parsed);
      if (!mounted) return;
      setState(() {
        medicationResolution = resolved;
        resolvingMedication = false;
        message = matchedPatient != null
            ? 'Matched to an active patient order.'
            : _friendlyMedicationMessage(parsed, resolved);
      });
      return;
    }

    Patient? match;
    NidsTestCredential? nidsTest;
    NidsScanEnvelope? identityEnvelope;
    String status;

    if (purpose == ScanPurpose.patientWristband) {
      match = _findEncounter(result.value);
      status = match == null ? 'No matching encounter found.' : 'Patient wristband matched.';
    } else if (purpose == ScanPurpose.nidsCard) {
      identityEnvelope = NidsIdentityDecoder.decode(result.value);
      nidsTest = identityEnvelope.testCredential;
      status = nidsTest != null
          ? 'Test identity decoded.'
          : 'NIC credential captured. NIRA verification is required before patient autofill.';
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

  String _friendlyMedicationMessage(
    MedicationIdentifier identifier,
    MedicationResolution resolution,
  ) {
    if (resolution.found) {
      return resolution.approvedForClinicalAutomation
          ? 'Medication verified.'
          : 'Medication identified. Pharmacy verification may still be required.';
    }
    if (identifier.gtinCheckDigitValid == false) {
      return 'This scan looks like a GTIN, but its check digit is invalid. Re-scan the clearest manufacturer barcode.';
    }
    final value = identifier.rawValue.toLowerCase();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return 'A web/retail QR link was detected, not a GS1 product identifier. Scan the UPC, EAN or DataMatrix on the package instead.';
    }
    if (identifier.gtin == null) {
      return 'Code captured, but no product identifier was found. Try another package code or search by medication name.';
    }
    return 'Product code captured but not found in the configured medication registry.';
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
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Look up')),
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
      message = 'Checking medication registry…';
    });
    final resolved = await _medicationRegistry.resolve(parsed);
    if (!mounted) return;
    setState(() {
      medicationResolution = resolved;
      resolvingMedication = false;
      message = _friendlyMedicationMessage(parsed, resolved);
    });
  }

  Future<void> _searchMedicationName() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search medication'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Brand, generic name, ingredient or type',
            hintText: 'e.g. pregabalin, CEFUR, antibiotic',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Search')),
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
          heightFactor: .80,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Medication results', style: TextStyle(color: medqurInk, fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Verified registry and package matches are prioritized. Public terminology is reference-only.',
                  style: TextStyle(color: Color(0xFF718095), fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (local.isNotEmpty) ...[
                        const _SearchSectionLabel('PACKAGE / LOCAL CATALOGUE'),
                        for (final product in local)
                          _MedicationSearchTile(
                            title: product.displayName,
                            subtitle: [
                              if (product.therapeuticCategory?.isNotEmpty == true) product.therapeuticCategory!,
                              product.sourceLabel,
                            ].join(' • '),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _selectLocalMedication(product);
                            },
                          ),
                        const Divider(height: 24),
                      ],
                      const _SearchSectionLabel('CONNECTED / PUBLIC REFERENCE'),
                      if (references.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('No additional medication matches were returned.'),
                        )
                      else
                        for (final item in references)
                          _MedicationSearchTile(
                            title: item.name,
                            subtitle: item.rxcui.isEmpty ? item.source : 'RxCUI ${item.rxcui} • ${item.source}',
                            icon: item.product == null ? Icons.menu_book_outlined : Icons.cloud_done_outlined,
                            onTap: item.product == null
                                ? null
                                : () {
                                    Navigator.pop(sheetContext);
                                    _selectLocalMedication(item.product!);
                                  },
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
    final raw = product.gtin ?? (product.rawAliases.isNotEmpty ? product.rawAliases.first : product.id);
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
      message = 'Medication selected.';
    });
  }

  Patient? _findEncounter(String raw) {
    for (final patient in widget.patients) {
      if (raw == patient.encounterToken || raw == patient.effectiveEncounterId || raw == patient.id) return patient;
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
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NidsTestCredentialPage()));
  }

  void _selectPurpose(ScanPurpose value) {
    setState(() {
      purpose = value;
      capture = null;
      matchedPatient = null;
      nidsTestCredential = null;
      nidsEnvelope = null;
      medicationIdentifier = null;
      medicationResolution = null;
      resolvingMedication = false;
      message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolution = medicationResolution;
    final medicationApproved = resolution?.approvedForClinicalAutomation == true;
    final verified = matchedPatient != null || nidsTestCredential != null || medicationApproved;

    return MedqurPage(
      children: [
        MedqurPageHeader(
          eyebrow: 'Universal scanner',
          title: 'Scan',
          subtitle: _subtitleForPurpose(purpose),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _choice('Wristband', Icons.watch_outlined, ScanPurpose.patientWristband),
              const SizedBox(width: 7),
              _choice('NIDS / NIC', Icons.credit_card_outlined, ScanPurpose.nidsCard),
              const SizedBox(width: 7),
              _choice('Medication', Icons.medication_outlined, ScanPurpose.medication),
              const SizedBox(width: 7),
              _choice('Staff ID', Icons.badge_outlined, ScanPurpose.staffBadge),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: purpose == ScanPurpose.medication ? const Color(0xFFF0F5FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: purpose == ScanPurpose.medication ? const Color(0xFFDCE7FB) : medqurLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: medqurBlue.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)),
                    child: Icon(_iconForPurpose(purpose), color: medqurBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(purpose.title, style: const TextStyle(color: medqurInk, fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(_helperForPurpose(purpose), style: const TextStyle(color: Color(0xFF718095), fontSize: 11.5, height: 1.3)),
                      ],
                    ),
                  ),
                  if (purpose == ScanPurpose.medication) const CapsuleIllustration(width: 76),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.camera_alt_rounded),
                label: Text(purpose.title),
              ),
              if (purpose == ScanPurpose.medication) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: _manualMedicationCode, icon: const Icon(Icons.keyboard_alt_outlined), label: const Text('Enter code'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: _searchMedicationName, icon: const Icon(Icons.search_rounded), label: const Text('Search'))),
                  ],
                ),
              ],
              if (purpose == ScanPurpose.nidsCard) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: _openGenerator, icon: const Icon(Icons.qr_code_2_rounded), label: const Text('Create test credential')),
              ],
            ],
          ),
        ),
        if (resolvingMedication) ...[
          const SizedBox(height: 12),
          const SoftCard(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2.2)),
                SizedBox(width: 11),
                Text('Identifying medication…', style: TextStyle(color: medqurInk, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
        if (capture != null || medicationIdentifier != null) ...[
          const SizedBox(height: 12),
          if (medicationIdentifier != null)
            _MedicationResultCard(
              identifier: medicationIdentifier!,
              resolution: medicationResolution,
              message: message ?? 'Medication captured.',
              matchedPatient: matchedPatient,
              onOpenPatient: matchedPatient == null ? null : () => widget.onOpenPatient(matchedPatient!),
            )
          else
            _GeneralScanResult(
              message: message ?? 'Captured',
              verified: verified,
              patient: matchedPatient,
              nidsTest: nidsTestCredential,
              nidsEnvelope: nidsEnvelope,
              capture: capture!,
              onOpenPatient: matchedPatient == null ? null : () => widget.onOpenPatient(matchedPatient!),
            ),
        ],
      ],
    );
  }

  Widget _choice(String label, IconData icon, ScanPurpose value) {
    final selected = purpose == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 17, color: selected ? medqurBlue : const Color(0xFF69788B)),
      label: Text(label),
      selected: selected,
      onSelected: (_) => _selectPurpose(value),
    );
  }

  String _subtitleForPurpose(ScanPurpose value) => switch (value) {
        ScanPurpose.patientWristband => 'Identify the active patient encounter from the wristband.',
        ScanPurpose.nidsCard => 'Capture the NIC credential for approved identity verification.',
        ScanPurpose.medication => 'Read GS1 DataMatrix, EAN/UPC, linear barcode or medication QR data.',
        ScanPurpose.staffBadge => 'Read the secure Medqur workforce credential.',
      };

  String _helperForPurpose(ScanPurpose value) => switch (value) {
        ScanPurpose.patientWristband => 'Center the patient code inside the frame.',
        ScanPurpose.nidsCard => 'Turn the card over and align the rear QR code.',
        ScanPurpose.medication => 'Prefer the manufacturer GS1/UPC code over retail marketing QR links.',
        ScanPurpose.staffBadge => 'Scan the signed workforce QR, then authenticate the device user.',
      };

  IconData _iconForPurpose(ScanPurpose value) => switch (value) {
        ScanPurpose.patientWristband => Icons.watch_outlined,
        ScanPurpose.nidsCard => Icons.credit_card_outlined,
        ScanPurpose.medication => Icons.medication_outlined,
        ScanPurpose.staffBadge => Icons.badge_outlined,
      };
}

class _MedicationResultCard extends StatelessWidget {
  const _MedicationResultCard({
    required this.identifier,
    required this.resolution,
    required this.message,
    required this.matchedPatient,
    required this.onOpenPatient,
  });

  final MedicationIdentifier identifier;
  final MedicationResolution? resolution;
  final String message;
  final Patient? matchedPatient;
  final VoidCallback? onOpenPatient;

  @override
  Widget build(BuildContext context) {
    final product = resolution?.product;
    final found = product != null;
    final approved = resolution?.approvedForClinicalAutomation == true;
    final accent = approved ? medqurGreen : found ? medqurBlue : medqurAmber;

    return SoftCard(
      highlighted: approved || matchedPatient != null,
      onTap: onOpenPatient,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: accent.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)),
                child: Icon(found ? Icons.medication_rounded : Icons.info_outline_rounded, color: accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      found ? product.displayName : 'Medication code captured',
                      style: const TextStyle(color: medqurInk, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(message, style: TextStyle(color: accent, fontSize: 11.5, height: 1.3, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          if (found) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (product.therapeuticCategory?.isNotEmpty == true) _Fact(label: 'Type', value: product.therapeuticCategory!),
                if (product.dosageForm.isNotEmpty) _Fact(label: 'Form', value: product.dosageForm),
                if (identifier.lotNumber != null) _Fact(label: 'Lot', value: identifier.lotNumber!),
                if (identifier.expiryDate != null) _Fact(label: 'Expires', value: _date(identifier.expiryDate!)),
                if (product.manufacturer.isNotEmpty) _Fact(label: 'Manufacturer', value: product.manufacturer),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (resolution != null)
                StatusPill(
                  label: resolution!.trustLabel,
                  color: approved ? medqurGreen : found ? medqurBlue : medqurAmber,
                ),
              if (matchedPatient != null) const StatusPill(label: 'Patient order match', color: medqurGreen),
              if (resolution?.onlineLookup == true) const StatusPill(label: 'Online lookup', color: medqurBlue),
            ],
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Technical code details', style: TextStyle(color: Color(0xFF718095), fontSize: 11.5, fontWeight: FontWeight.w700)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  identifier.summary,
                  style: const TextStyle(color: Color(0xFF647286), fontSize: 10.5, height: 1.35),
                ),
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  identifier.rawValue,
                  style: const TextStyle(color: Color(0xFF98A3B2), fontSize: 9.5, height: 1.3),
                ),
              ),
              if (resolution != null) ...[
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Source: ${resolution!.source}', style: const TextStyle(color: Color(0xFF98A3B2), fontSize: 9.5)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _date(DateTime value) => '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _GeneralScanResult extends StatelessWidget {
  const _GeneralScanResult({
    required this.message,
    required this.verified,
    required this.patient,
    required this.nidsTest,
    required this.nidsEnvelope,
    required this.capture,
    required this.onOpenPatient,
  });

  final String message;
  final bool verified;
  final Patient? patient;
  final NidsTestCredential? nidsTest;
  final NidsScanEnvelope? nidsEnvelope;
  final ScanCapture capture;
  final VoidCallback? onOpenPatient;

  @override
  Widget build(BuildContext context) {
    final accent = verified ? medqurGreen : medqurBlue;
    return SoftCard(
      highlighted: verified,
      onTap: onOpenPatient,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(verified ? Icons.verified_rounded : Icons.qr_code_scanner_rounded, color: accent),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 13.5)),
                const SizedBox(height: 7),
                if (nidsTest != null) ...[
                  Text(nidsTest!.fullName, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800)),
                  Text('DOB ${nidsTest!.dateOfBirth} • ${nidsTest!.nationalIdNumber}', style: const TextStyle(color: Color(0xFF718095), fontSize: 11.5)),
                  const SizedBox(height: 3),
                  const Text('TEST ONLY • not NIRA verified', style: TextStyle(color: medqurRed, fontSize: 10, fontWeight: FontWeight.w800)),
                ] else if (nidsEnvelope != null) ...[
                  Text(nidsEnvelope!.safeLabel, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  const Text('Awaiting authorized NIRA verification before autofill.', style: TextStyle(color: medqurAmber, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ] else
                  Text(patient?.name ?? capture.value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF718095), fontSize: 11.5)),
                const SizedBox(height: 5),
                Text('Scanner: ${capture.format.name}', style: const TextStyle(color: Color(0xFF98A3B2), fontSize: 9.5)),
              ],
            ),
          ),
          if (onOpenPatient != null) const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A3B2)),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 110),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(color: const Color(0xFFF7F9FC), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFF98A3B2), fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: .45)),
            const SizedBox(height: 2),
            Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: medqurInk, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _MedicationSearchTile extends StatelessWidget {
  const _MedicationSearchTile({
    required this.title,
    required this.subtitle,
    this.onTap,
    this.icon = Icons.medication_outlined,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEDF3FF),
          foregroundColor: medqurBlue,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
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
          style: const TextStyle(color: Color(0xFF8793A4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6),
        ),
      );
}
