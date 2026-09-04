import 'package:flutter/material.dart';

import '../models.dart';
import '../services/medication_identifier.dart';
import '../services/medication_master.dart';
import '../services/medication_registry.dart';
import '../services/pharmacy_api.dart';
import '../services/prescription_document.dart';
import '../services/prescription_signature_store.dart';
import '../services/signature_vault.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
import '../widgets/prescription_signature_pad.dart';
import 'live_scanner_page.dart';
import 'prescription_print_preview_page.dart';
import 'signature_vault_page.dart';

class PrescriptionComposerPage extends StatefulWidget {
  const PrescriptionComposerPage({
    super.key,
    required this.staff,
    required this.patient,
    required this.facility,
  });

  final StaffProfile staff;
  final Patient patient;
  final Facility facility;

  @override
  State<PrescriptionComposerPage> createState() =>
      _PrescriptionComposerPageState();
}

class _PrescriptionComposerPageState extends State<PrescriptionComposerPage> {
  final _medication = TextEditingController();
  final _dose = TextEditingController();
  final _duration = TextEditingController();
  final _instructions = TextEditingController();
  final _registry = MedicationRegistryClient();
  final _pharmacy = PharmacyApiClient();
  final _orderSignatureStore = PrescriptionSignatureStore();
  final _signatureVault = DoctorSignatureVault();

  String _route = 'Oral';
  String _frequency = 'Twice daily';
  String? _productCode;
  MedicationIdentifier? _identifier;
  MedicationResolution? _resolution;
  DateTime? _scheduledAt;
  bool _busy = false;
  List<StoredDoctorSignature> _signatures = const [];
  String? _selectedSignatureId;
  PrescriptionInk _ink = PrescriptionInk.blue;

  StoredDoctorSignature? get _selectedSignature {
    if (_signatures.isEmpty) return null;
    return _signatures.firstWhere(
      (item) => item.id == _selectedSignatureId,
      orElse: () => _signatures.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  @override
  void dispose() {
    _medication.dispose();
    _dose.dispose();
    _duration.dispose();
    _instructions.dispose();
    _registry.dispose();
    _pharmacy.dispose();
    super.dispose();
  }

  Future<void> _loadSignatures() async {
    final items = await _signatureVault.load(widget.staff.id);
    if (!mounted) return;
    final preferred = items.where((item) => item.isDefault).firstOrNull;
    setState(() {
      _signatures = items;
      _selectedSignatureId =
          preferred?.id ?? (items.isEmpty ? null : items.first.id);
      if (preferred != null) _ink = preferred.ink;
    });
  }

  Future<void> _manageSignatures() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignatureVaultPage(staff: widget.staff),
      ),
    );
    await _loadSignatures();
  }

  Future<void> _scanMedication() async {
    final capture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(
        builder: (_) =>
            const LiveScannerPage(purpose: ScanPurpose.medication),
      ),
    );
    if (capture == null || !mounted) return;

    final identifier = MedicationIdentifierParser.parse(
      capture.value,
      formatName: capture.format.name,
    );
    setState(() {
      _busy = true;
      _productCode = capture.value;
      _identifier = identifier;
      _resolution = null;
    });

    final resolution = await _registry.resolve(identifier);
    if (!mounted) return;
    final product = resolution.product;
    setState(() {
      _busy = false;
      _resolution = resolution;
      if (product != null) {
        _medication.text = product.genericName;
        if (_dose.text.trim().isEmpty) _dose.text = product.strength;
      }
    });
  }

  Future<void> _searchMedication() async {
    final queryController =
        TextEditingController(text: _medication.text.trim());
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find medication'),
        content: TextField(
          controller: queryController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Brand, generic or ingredient',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, queryController.text.trim()),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    queryController.dispose();
    if (query == null || query.length < 2 || !mounted) return;

    setState(() => _busy = true);
    final local = MedicationMasterCatalog.search(query);
    final remote = await _registry.searchByName(query);
    if (!mounted) return;
    setState(() => _busy = false);

    final options = <MedicationProduct>[
      ...local,
      ...remote.where((item) => item.product != null).map((item) => item.product!),
    ];

    final selected = await showModalBottomSheet<MedicationProduct>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .72,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Medication results',
                    style: TextStyle(
                      color: medqurInk,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: options.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No product record was returned. Enter the medication manually and pharmacy verification will be required.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final product = options[index];
                          return ListTile(
                            title: Text(
                              product.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              [product.therapeuticCategory, product.manufacturer]
                                  .whereType<String>()
                                  .where((item) => item.trim().isNotEmpty)
                                  .join(' • '),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.pop(sheetContext, product),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    final raw = selected.gtin ??
        (selected.rawAliases.isEmpty ? selected.id : selected.rawAliases.first);
    final identifier = MedicationIdentifierParser.parse(raw);
    setState(() {
      _medication.text = selected.genericName;
      _dose.text = selected.strength;
      _productCode = raw;
      _identifier = identifier;
      _resolution = MedicationResolution(
        identifier: identifier,
        product: selected,
        trust: switch (selected.source) {
          MedicationProductSource.jamaicaApproved =>
            MedicationResolutionTrust.jamaicaApproved,
          MedicationProductSource.publicReference =>
            MedicationResolutionTrust.publicReference,
          MedicationProductSource.observedPackage =>
            MedicationResolutionTrust.observedPackage,
          MedicationProductSource.prototype =>
            MedicationResolutionTrust.prototype,
        },
        source: selected.sourceLabel,
        message: 'Medication selected from the searchable catalogue.',
      );
    });
  }

  Future<void> _schedule() async {
    final initial =
        _scheduledAt ?? DateTime.now().add(const Duration(minutes: 30));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(
      () => _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  void _appendPhrase(String phrase) {
    final current = _instructions.text.trim();
    _instructions.text = current.isEmpty
        ? phrase
        : '$current${current.endsWith('.') ? ' ' : '. '}$phrase';
    _instructions.selection =
        TextSelection.collapsed(offset: _instructions.text.length);
  }

  Future<void> _signAndPreview() async {
    final name = _medication.text.trim();
    final dose = _dose.text.trim();
    if (name.isEmpty || dose.isEmpty) {
      _show('Medication and dose are required.');
      return;
    }

    var signature = _selectedSignature;
    if (signature == null) {
      await _manageSignatures();
      signature = _selectedSignature;
      if (signature == null) {
        _show('Add a doctor signature before signing this prescription.');
        return;
      }
    }

    final prepared = _signatureVault.prepare(
      signature: signature,
      prescriberId: widget.staff.id,
    );

    setState(() => _busy = true);
    String? backendOrderId;
    try {
      if (_pharmacy.isConfigured) {
        final response = await _pharmacy.createOrder(
          staffId: widget.staff.id,
          facilityId: widget.facility.id,
          patientId: widget.patient.id,
          encounterId: widget.patient.effectiveEncounterId,
          medicationText: name,
          dose: dose,
          route: _route,
          frequency: _frequency,
          productId:
              _uuid(_resolution?.product?.id) ? _resolution?.product?.id : null,
          dueAt: _scheduledAt,
          signaturePayload: prepared.payload,
          signatureSha256: prepared.digest,
          signatureSignedAt: prepared.signedAt,
          signatureMethod: 'stored-${signature.source.name}',
        );
        final order = response['order'];
        if (order is Map<String, dynamic>) {
          backendOrderId = order['id']?.toString();
        }
      }

      final localKey = backendOrderId ??
          '${widget.patient.id}-${DateTime.now().microsecondsSinceEpoch}-${prepared.digest.substring(0, 12)}';
      await _orderSignatureStore.save(
        orderKey: localKey,
        signature: PrescriptionSignature(
          payload: prepared.payload,
          digest: prepared.digest,
          signedAt: prepared.signedAt,
        ),
        prescriberId: widget.staff.id,
        patientId: widget.patient.id,
      );

      final order = MedicationOrder(
        name: name,
        dose: dose,
        route: _route,
        frequency: _frequency,
        orderedBy: widget.staff.name,
        productCode: _productCode,
        orderId: backendOrderId,
        productId: _resolution?.product?.id,
        scheduledAt: _scheduledAt,
        productVerified: _resolution?.approvedForClinicalAutomation == true,
      );

      final copyNumber = _copyNumber();
      final printData = PrescriptionPrintData(
        patient: widget.patient,
        staff: widget.staff,
        facility: widget.facility,
        medication: name,
        dose: dose,
        route: _route,
        frequency: _frequency,
        duration: _duration.text.trim(),
        instructions: _instructions.text.trim(),
        ink: _ink,
        signature: signature,
        copyNumber: copyNumber,
        createdAt: DateTime.now(),
      );

      widget.patient.timeline.add(
        '${_timeNow()} — Prescription $copyNumber signed by ${widget.staff.name} • signature ${prepared.digest.substring(0, 12)}',
      );

      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrescriptionPrintPreviewPage(data: printData),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, order);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _show('Prescription could not be signed: $error');
    }
  }

  bool _uuid(String? value) =>
      value != null &&
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);

  String _timeNow() {
    final now = TimeOfDay.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _copyNumber() {
    final now = DateTime.now();
    final serial =
        (now.microsecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    return 'RX-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$serial';
  }

  void _show(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  String _scheduleLabel() {
    final value = _scheduledAt;
    if (value == null) return 'First dose time';
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year} • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final product = _resolution?.product;
    final verified = _resolution?.approvedForClinicalAutomation == true;
    final selectedSignature = _selectedSignature;

    return Scaffold(
      appBar: AppBar(title: const Text('Prescription')),
      body: SafeArea(
        child: MedqurPage(
          children: [
            PatientContextBar(patient: widget.patient),
            const SizedBox(height: 18),
            const MedqurPageHeader(
              eyebrow: 'Doctor order',
              title: 'New prescription',
              subtitle:
                  'Choose the medicine, write the directions, then sign and preview the hospital form.',
            ),
            const SizedBox(height: 18),
            _SectionLabel('Medicine'),
            const SizedBox(height: 8),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _medication,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Medication'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _searchMedication,
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Search'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _scanMedication,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Scan'),
                        ),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 2),
                  ] else if (_identifier != null) ...[
                    const SizedBox(height: 12),
                    _MedicationStatus(
                      title: product?.displayName ?? _identifier!.summary,
                      label: _resolution?.trustLabel ??
                          'Product identification pending',
                      verified: verified,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionLabel('Directions'),
            const SizedBox(height: 8),
            SoftCard(
              child: Column(
                children: [
                  TextField(
                    controller: _dose,
                    decoration: const InputDecoration(labelText: 'Dose'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _route,
                          decoration: const InputDecoration(labelText: 'Route'),
                          items: const [
                            'Oral',
                            'IV',
                            'IM',
                            'Inhaled',
                            'Topical',
                            'Subcutaneous',
                          ]
                              .map((value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _route = value ?? _route),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _frequency,
                          decoration:
                              const InputDecoration(labelText: 'Frequency'),
                          items: const [
                            'Once',
                            'Every 4 hours',
                            'Every 6 hours',
                            'Every 8 hours',
                            'Every 12 hours',
                            'Daily',
                            'Twice daily',
                            'As needed',
                          ]
                              .map((value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(
                            () => _frequency = value ?? _frequency,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _duration,
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      hintText: 'e.g. 7 days',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _instructions,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Instructions',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        label: const Text('Take with food'),
                        onPressed: () => _appendPhrase('Take with food'),
                      ),
                      ActionChip(
                        label: const Text('Complete full course'),
                        onPressed: () => _appendPhrase('Complete full course'),
                      ),
                      ActionChip(
                        label: const Text('As directed'),
                        onPressed: () => _appendPhrase('Use as directed'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading:
                        const Icon(Icons.schedule_outlined, color: medqurBlue),
                    title: const Text('Schedule'),
                    subtitle: Text(_scheduleLabel()),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _schedule,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionLabel('Pen & signature'),
            const SizedBox(height: 8),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<PrescriptionInk>(
                    segments: const [
                      ButtonSegment(
                        value: PrescriptionInk.blue,
                        label: Text('Blue pen'),
                      ),
                      ButtonSegment(
                        value: PrescriptionInk.black,
                        label: Text('Black pen'),
                      ),
                    ],
                    selected: {_ink},
                    onSelectionChanged: (value) =>
                        setState(() => _ink = value.first),
                  ),
                  const SizedBox(height: 12),
                  if (_signatures.isEmpty)
                    OutlinedButton.icon(
                      onPressed: _manageSignatures,
                      icon: const Icon(Icons.draw_outlined),
                      label: const Text('Add doctor signature'),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSignatureId,
                      decoration: const InputDecoration(labelText: 'Signature'),
                      items: [
                        for (final signature in _signatures)
                          DropdownMenuItem(
                            value: signature.id,
                            child: Text(
                              signature.isDefault
                                  ? '${signature.label} • default'
                                  : signature.label,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedSignatureId = value),
                    ),
                    const SizedBox(height: 10),
                    if (selectedSignature != null)
                      Container(
                        height: 82,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: medqurLine),
                        ),
                        child: Image.memory(
                          selectedSignature.imageBytes,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _manageSignatures,
                        child: const Text('Manage signatures'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _signAndPreview,
              icon: const Icon(Icons.edit_document),
              label: Text(_busy ? 'Signing…' : 'Sign & preview'),
            ),
            const SizedBox(height: 8),
            const Text(
              'The selected signature is a visual attestation. The authenticated doctor account, six-digit staff ID, facility, timestamp and audit trail remain the authoritative signer identity.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7A8798),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF68778A),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: .15,
        ),
      );
}

class _MedicationStatus extends StatelessWidget {
  const _MedicationStatus({
    required this.title,
    required this.label,
    required this.verified,
  });

  final String title;
  final String label;
  final bool verified;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: verified ? const Color(0xFFF0F8F5) : const Color(0xFFFFF8EA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              verified ? Icons.verified_outlined : Icons.info_outline_rounded,
              size: 18,
              color: verified ? medqurGreen : medqurAmber,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: medqurInk,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: verified ? medqurGreen : medqurAmber,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
