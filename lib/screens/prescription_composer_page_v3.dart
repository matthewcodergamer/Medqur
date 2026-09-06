import 'package:flutter/material.dart';

import '../clinical_clock.dart';
import '../medication_order_options.dart';
import '../medication_prescribing_options.dart';
import '../models.dart';
import '../services/medication_identifier.dart';
import '../services/medication_master.dart';
import '../services/medication_registry.dart';
import '../services/pharmacy_api.dart';
import '../services/prescription_document.dart';
import '../services/prescription_record_store.dart';
import '../services/prescription_signature_store.dart';
import '../services/signature_rendering.dart';
import '../services/signature_vault.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
import '../widgets/medqur_responsive.dart';
import 'live_scanner_page.dart';
import 'prescription_print_preview_page.dart';
import 'signature_vault_page.dart';

/// V0.14 prescription composer revision.
///
/// - duration is controlled by a dropdown rather than free text
/// - common medication instructions are searchable and multi-select
/// - prescription/signature ink has one active choice: blue
/// - frequency remains 1x through 20x and routes remain alphabetized
/// - signed prescriptions can still be reopened and amended without destroying
///   the previous revision
class PrescriptionComposerPage extends StatefulWidget {
  const PrescriptionComposerPage({
    super.key,
    required this.staff,
    required this.patient,
    required this.facility,
    this.existingOrder,
    this.existingRecord,
  });

  final StaffProfile staff;
  final Patient patient;
  final Facility facility;
  final MedicationOrder? existingOrder;
  final PrescriptionRecord? existingRecord;

  bool get isAmendment => existingOrder != null;

  @override
  State<PrescriptionComposerPage> createState() =>
      _PrescriptionComposerPageState();
}

class _PrescriptionComposerPageState extends State<PrescriptionComposerPage> {
  final _medication = TextEditingController();
  final _instructions = TextEditingController();
  final _amendmentReason = TextEditingController();
  final _registry = MedicationRegistryClient();
  final _pharmacy = PharmacyApiClient();
  final _signatureStore = PrescriptionSignatureStore();
  final _recordStore = const PrescriptionRecordStore();
  final _signatureVault = DoctorSignatureVault();

  int _doseValue = 1;
  MedicationDoseUnit _doseUnit = MedicationDoseUnit.milligram;
  String _route = 'Oral';
  int _frequencyCount = 1;
  MedicationFrequencyPeriod _frequencyPeriod = MedicationFrequencyPeriod.day;
  MedicationDueMode _dueMode = MedicationDueMode.immediate;
  DateTime? _scheduledAt;
  String _duration = 'Not specified';

  String? _productCode;
  MedicationIdentifier? _identifier;
  MedicationResolution? _resolution;
  bool _busy = false;
  List<StoredDoctorSignature> _signatures = const [];
  String? _selectedSignatureId;

  StructuredMedicationDirections get _directions =>
      StructuredMedicationDirections(
        doseValue: _doseValue,
        doseUnit: _doseUnit,
        frequencyCount: _frequencyCount,
        frequencyPeriod: _frequencyPeriod,
        dueMode: _dueMode,
        scheduledAt: _scheduledAt,
      );

  List<String> get _durationOptions {
    final options = [...MedicationPrescribingOptions.durations];
    if (_duration.trim().isNotEmpty && !options.contains(_duration)) {
      options.add(_duration);
    }
    return options;
  }

  String get _durationForRecord =>
      _duration == 'Not specified' ? '' : _duration.trim();

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
    _seedExisting();
    _loadSignatures();
  }

  void _seedExisting() {
    final order = widget.existingOrder;
    final record = widget.existingRecord;
    if (order == null) return;

    _medication.text = order.name;
    _productCode = order.productCode;
    _scheduledAt = order.scheduledAt;
    if (order.scheduledAt != null) _dueMode = MedicationDueMode.scheduled;
    _route = _normalizeRoute(order.route);
    _duration = record?.duration.trim().isNotEmpty == true
        ? record!.duration.trim()
        : 'Not specified';
    _instructions.text = record?.instructions ?? '';

    final dose = RegExp(r'^\s*(\d{1,3})\s*([^\s]+)')
        .firstMatch(order.dose.trim());
    final parsedDose = int.tryParse(dose?.group(1) ?? '');
    if (parsedDose != null &&
        StructuredMedicationDirections.doseValues.contains(parsedDose)) {
      _doseValue = parsedDose;
    }
    final unitToken = (dose?.group(2) ?? '').toLowerCase();
    _doseUnit = switch (unitToken) {
      'g' => MedicationDoseUnit.gram,
      'mg' => MedicationDoseUnit.milligram,
      'mcg' || 'ug' || 'µg' => MedicationDoseUnit.microgram,
      'ml' => MedicationDoseUnit.millilitre,
      'ul' || 'µl' => MedicationDoseUnit.microlitre,
      'l' => MedicationDoseUnit.litre,
      _ => _doseUnit,
    };

    final frequency = RegExp(
      r'^(\d{1,2})x\s+per\s+(hour|day|week)$',
      caseSensitive: false,
    ).firstMatch(order.frequency.trim());
    final count = int.tryParse(frequency?.group(1) ?? '');
    if (count != null &&
        StructuredMedicationDirections.frequencyCounts.contains(count)) {
      _frequencyCount = count;
    }
    _frequencyPeriod = switch ((frequency?.group(2) ?? '').toLowerCase()) {
      'hour' => MedicationFrequencyPeriod.hour,
      'week' => MedicationFrequencyPeriod.week,
      _ => MedicationFrequencyPeriod.day,
    };
  }

  String _normalizeRoute(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'iv' || value.startsWith('intravenous')) {
      return 'Intravenous (IV)';
    }
    if (value == 'im' || value.startsWith('intramuscular')) {
      return 'Intramuscular (IM)';
    }
    if (value == 'io' || value.startsWith('intraosseous')) {
      return 'Intraosseous (IO)';
    }
    for (final route in MedicationPrescribingOptions.routes) {
      if (route.toLowerCase() == value) return route;
    }
    return 'Oral';
  }

  @override
  void dispose() {
    _medication.dispose();
    _instructions.dispose();
    _amendmentReason.dispose();
    _registry.dispose();
    _pharmacy.dispose();
    super.dispose();
  }

  Future<void> _loadSignatures() async {
    final items = await _signatureVault.load(widget.staff.id);
    if (!mounted) return;
    StoredDoctorSignature? preferred;
    for (final item in items) {
      if (item.isDefault) {
        preferred = item;
        break;
      }
    }
    setState(() {
      _signatures = items;
      _selectedSignatureId =
          preferred?.id ?? (items.isEmpty ? null : items.first.id);
    });
  }

  Future<void> _manageSignatures() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SignatureVaultPage(staff: widget.staff)),
    );
    if (mounted) await _loadSignatures();
  }

  void _applyProductStrength(String strength) {
    final preset = MedicationDosePreset.tryParse(strength);
    if (preset == null) return;
    _doseValue = preset.value;
    _doseUnit = preset.unit;
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
        _applyProductStrength(product.strength);
      }
    });
  }

  Future<void> _searchMedication() async {
    final controller = TextEditingController(text: _medication.text.trim());
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find medication'),
        content: TextField(
          controller: controller,
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
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query == null || query.length < 2 || !mounted) return;

    setState(() => _busy = true);
    final local = MedicationMasterCatalog.search(query);
    final remote = await _registry.searchByName(query);
    if (!mounted) return;
    setState(() => _busy = false);

    final seen = <String>{};
    final options = <MedicationProduct>[];
    for (final product in <MedicationProduct>[
      ...local,
      ...remote.where((item) => item.product != null).map((item) => item.product!),
    ]) {
      final key = '${product.id}|${product.displayName}';
      if (seen.add(key)) options.add(product);
    }

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
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: options.isEmpty
                    ? const Center(child: Text('No matching product record.'))
                    : ListView.separated(
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final product = options[index];
                          return ListTile(
                            title: Text(
                              product.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              product.therapeuticCategory ?? product.sourceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
      _applyProductStrength(selected.strength);
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

  Future<void> _pickCommonInstructions() async {
    var query = '';
    final selected = <String>{};
    final values = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final options = MedicationPrescribingOptions.commonInstructions
              .where((item) =>
                  query.isEmpty || item.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: .84,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Medication instructions',
                            style: TextStyle(
                              color: medqurInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (selected.isNotEmpty)
                          StatusPill(
                            label: '${selected.length} selected',
                            color: medqurBlue,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Search and add only the instructions that apply to this medicine and patient.',
                        style: TextStyle(
                          color: Color(0xFF748091),
                          fontSize: 11.25,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search alcohol, dairy, tea, food, water…',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) => setSheetState(() => query = value),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (_, index) {
                          final option = options[index];
                          final checked = selected.contains(option);
                          return CheckboxListTile(
                            value: checked,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              option,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selected.add(option);
                                } else {
                                  selected.remove(option);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.pop(
                                  sheetContext,
                                  selected.toList(growable: false),
                                ),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          selected.isEmpty
                              ? 'Select instructions'
                              : 'Add ${selected.length} instruction${selected.length == 1 ? '' : 's'}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (values == null || values.isEmpty) return;
    for (final value in values) {
      _appendPhrase(value);
    }
  }

  void _appendPhrase(String phrase) {
    final current = _instructions.text.trim();
    if (current.toLowerCase().contains(phrase.toLowerCase())) return;
    _instructions.text = current.isEmpty
        ? phrase
        : '$current${current.endsWith('.') ? ' ' : '. '}$phrase';
    _instructions.selection =
        TextSelection.collapsed(offset: _instructions.text.length);
    setState(() {});
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
    setState(() {
      _dueMode = MedicationDueMode.scheduled;
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _signAndPreview() async {
    final name = _medication.text.trim();
    if (name.isEmpty) {
      _show('Medication is required.');
      return;
    }
    if (_dueMode == MedicationDueMode.scheduled && _scheduledAt == null) {
      _show('Choose the date and time for the scheduled dose.');
      return;
    }
    if (widget.isAmendment && _amendmentReason.text.trim().isEmpty) {
      _show('Add a reason for the amendment.');
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

    final directions = _directions;
    final dose = directions.doseText;
    final frequency = directions.frequencyText;
    final dueAt = directions.effectiveDueAt();
    final prepared = _signatureVault.prepare(
      signature: signature,
      prescriberId: widget.staff.id,
    );
    final now = DateTime.now();
    final previous = widget.existingRecord;
    final revision = (previous?.revision ?? 0) + 1;
    final localId =
        'RXO-${now.microsecondsSinceEpoch}-${prepared.digest.substring(0, 8)}';
    final copyNumber = _copyNumber(now, revision);

    setState(() => _busy = true);
    String? backendOrderId;
    try {
      final canCreateRemote = _pharmacy.isConfigured &&
          (!widget.isAmendment || previous?.backendOrderId == null);
      if (canCreateRemote) {
        final response = await _pharmacy.createOrder(
          staffId: widget.staff.id,
          facilityId: widget.facility.id,
          patientId: widget.patient.id,
          encounterId: widget.patient.effectiveEncounterId,
          medicationText: name,
          dose: dose,
          route: _route,
          frequency: frequency,
          productId:
              _uuid(_resolution?.product?.id) ? _resolution?.product?.id : null,
          dueAt: dueAt,
          signaturePayload: prepared.payload,
          signatureSha256: prepared.digest,
          signatureSignedAt: prepared.signedAt,
          signatureMethod: 'stored-${signature.source.name}',
        );
        final rawOrder = response['order'];
        if (rawOrder is Map<String, dynamic>) {
          backendOrderId = rawOrder['id']?.toString();
        }
      }

      final record = PrescriptionRecord(
        id: localId,
        patientId: widget.patient.id,
        encounterId: widget.patient.effectiveEncounterId,
        facilityId: widget.facility.id,
        medication: name,
        dose: dose,
        route: _route,
        frequency: frequency,
        duration: _durationForRecord,
        instructions: _instructions.text.trim(),
        orderedById: widget.staff.id,
        orderedByName: widget.staff.name,
        orderedAt: now.toUtc(),
        signatureDigest: prepared.digest,
        signatureSignedAt: prepared.signedAt,
        signatureMethod: 'stored-${signature.source.name}',
        copyNumber: copyNumber,
        revision: revision,
        backendOrderId: backendOrderId,
        amendmentReason:
            widget.isAmendment ? _amendmentReason.text.trim() : null,
        supersedesId: previous?.id,
      );

      if (previous == null) {
        await _recordStore.add(record);
      } else {
        await _recordStore.addRevision(previous: previous, revision: record);
      }
      await _signatureStore.save(
        orderKey: record.orderKey,
        signature: PrescriptionSignature(
          payload: prepared.payload,
          digest: prepared.digest,
          signedAt: prepared.signedAt,
        ),
        prescriberId: widget.staff.id,
        patientId: widget.patient.id,
      );

      final existing = widget.existingOrder;
      final order = MedicationOrder(
        name: name,
        dose: dose,
        route: _route,
        frequency: frequency,
        orderedBy: widget.staff.name,
        productCode: _productCode ?? existing?.productCode,
        orderId: backendOrderId ?? record.id,
        productId: _resolution?.product?.id ?? existing?.productId,
        dispenseId: null,
        lotId: null,
        scheduledAt: dueAt,
        productVerified:
            _resolution?.approvedForClinicalAutomation == true ||
                existing?.productVerified == true,
      );

      widget.patient.timeline.add(
        widget.isAmendment
            ? '${ClinicalClock.time(now)} — Prescription amended by ${widget.staff.name} • revision $revision • ${_amendmentReason.text.trim()}'
            : '${ClinicalClock.time(now)} — Prescription $copyNumber signed by ${widget.staff.name}',
      );

      final printData = PrescriptionPrintData(
        patient: widget.patient,
        staff: widget.staff,
        facility: widget.facility,
        medication: name,
        dose: dose,
        route: _route,
        frequency: frequency,
        duration: _durationForRecord,
        instructions: _instructions.text.trim(),
        ink: PrescriptionInk.blue,
        signature: signature,
        copyNumber: copyNumber,
        createdAt: now,
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

  String _copyNumber(DateTime now, int revision) {
    final serial =
        (now.microsecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
    final base =
        'RX-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$serial';
    return revision <= 1 ? base : '$base-R$revision';
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  String _scheduleLabel() {
    if (_dueMode == MedicationDueMode.immediate) return 'Due immediately';
    final value = _scheduledAt;
    if (value == null) return 'Choose date and time';
    return 'Due ${ClinicalClock.dateTimeShort(value)}';
  }

  @override
  Widget build(BuildContext context) {
    final product = _resolution?.product;
    final verified = _resolution?.approvedForClinicalAutomation == true;
    final signature = _selectedSignature;
    final signaturePreview = signature == null
        ? null
        : SignatureRendering.blueInkOnWhitePaper(signature.imageBytes);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAmendment ? 'Amend prescription' : 'Prescription'),
      ),
      body: SafeArea(
        child: MedqurPage(
          children: [
            PatientContextBar(patient: widget.patient),
            const SizedBox(height: 16),
            MedqurPageHeader(
              eyebrow:
                  widget.isAmendment ? 'Signed order amendment' : 'Doctor order',
              title:
                  widget.isAmendment ? 'Update prescription' : 'New prescription',
              subtitle: widget.isAmendment
                  ? 'Changes create a new signed revision; the previous revision stays in the audit history.'
                  : 'Set the medication and directions, then sign and preview.',
            ),
            const SizedBox(height: 16),
            _section(
              'Medication',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _medication,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Medication'),
                  ),
                  const SizedBox(height: 9),
                  ResponsiveButtonRow(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _searchMedication,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Search'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _scanMedication,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan'),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(minHeight: 2),
                  ] else if (_identifier != null) ...[
                    const SizedBox(height: 9),
                    Text(
                      product?.displayName ?? _identifier!.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: verified ? medqurGreen : medqurAmber,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _section(
              'Directions',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ResponsiveFields(
                    minFieldWidth: 190,
                    children: [
                      DropdownButtonFormField<int>(
                        value: _doseValue,
                        decoration:
                            const InputDecoration(labelText: 'Dose amount'),
                        menuMaxHeight: 360,
                        items: [
                          for (final value
                              in StructuredMedicationDirections.doseValues)
                            DropdownMenuItem(value: value, child: Text('$value')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _doseValue = value);
                        },
                      ),
                      DropdownButtonFormField<MedicationDoseUnit>(
                        value: _doseUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: [
                          for (final unit in MedicationDoseUnit.values)
                            DropdownMenuItem(
                              value: unit,
                              child: Text('${unit.symbol} • ${unit.label}'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _doseUnit = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    value: _route,
                    decoration: const InputDecoration(labelText: 'Route'),
                    menuMaxHeight: 390,
                    items: [
                      for (final route in MedicationPrescribingOptions.routes)
                        DropdownMenuItem(value: route, child: Text(route)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _route = value);
                    },
                  ),
                  const SizedBox(height: 9),
                  ResponsiveFields(
                    minFieldWidth: 190,
                    children: [
                      DropdownButtonFormField<int>(
                        value: _frequencyCount,
                        decoration: const InputDecoration(labelText: 'Times'),
                        menuMaxHeight: 360,
                        items: [
                          for (final value
                              in StructuredMedicationDirections.frequencyCounts)
                            DropdownMenuItem(
                              value: value,
                              child: Text('${value}x'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _frequencyCount = value);
                          }
                        },
                      ),
                      DropdownButtonFormField<MedicationFrequencyPeriod>(
                        value: _frequencyPeriod,
                        decoration: const InputDecoration(labelText: 'Per'),
                        items: [
                          for (final period in MedicationFrequencyPeriod.values)
                            DropdownMenuItem(
                              value: period,
                              child: Text(period.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _frequencyPeriod = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    value: _duration,
                    decoration: const InputDecoration(labelText: 'Duration'),
                    menuMaxHeight: 390,
                    items: [
                      for (final duration in _durationOptions)
                        DropdownMenuItem(
                          value: duration,
                          child: Text(duration),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _duration = value);
                    },
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: _instructions,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Instructions',
                      alignLabelWithHint: true,
                      hintText: 'Selected instructions appear here',
                    ),
                  ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _pickCommonInstructions,
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: const Text('Search & add instructions'),
                    ),
                  ),
                  const SizedBox(height: 7),
                  SegmentedButton<MedicationDueMode>(
                    segments: const [
                      ButtonSegment(
                        value: MedicationDueMode.immediate,
                        label: Text('Immediately'),
                      ),
                      ButtonSegment(
                        value: MedicationDueMode.scheduled,
                        label: Text('Date / time'),
                      ),
                    ],
                    selected: {_dueMode},
                    onSelectionChanged: (value) =>
                        setState(() => _dueMode = value.first),
                  ),
                  if (_dueMode == MedicationDueMode.scheduled) ...[
                    const SizedBox(height: 7),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Scheduled due time'),
                      subtitle: Text(_scheduleLabel()),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _schedule,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.isAmendment) ...[
              const SizedBox(height: 14),
              _section(
                'Amendment',
                TextField(
                  controller: _amendmentReason,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason for change',
                    hintText: 'What changed and why?',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _section(
              'Signature',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.circle, size: 11, color: medqurBlue),
                      SizedBox(width: 7),
                      Text(
                        'Blue pen',
                        style: TextStyle(
                          color: medqurNavy,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  if (_signatures.isEmpty)
                    OutlinedButton.icon(
                      onPressed: _manageSignatures,
                      icon: const Icon(Icons.draw_outlined),
                      label: const Text('Add doctor signature'),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      value: _selectedSignatureId,
                      decoration: const InputDecoration(labelText: 'Signature'),
                      items: [
                        for (final item in _signatures)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.isDefault
                                  ? '${item.label} • default'
                                  : item.label,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedSignatureId = value),
                    ),
                    if (signaturePreview != null) ...[
                      const SizedBox(height: 9),
                      Container(
                        height: 76,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: medqurLine),
                        ),
                        child: Image.memory(
                          signaturePreview,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ],
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
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _signAndPreview,
              icon: const Icon(Icons.edit_document),
              label: Text(
                _busy
                    ? 'Signing…'
                    : widget.isAmendment
                        ? 'Sign amended revision'
                        : 'Sign & preview',
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF68778A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          SoftCard(padding: const EdgeInsets.all(13), child: child),
        ],
      );
}
