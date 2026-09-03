import 'package:flutter/material.dart';

import '../models.dart';
import '../services/medication_identifier.dart';
import '../services/medication_master.dart';
import '../services/medication_registry.dart';
import '../services/pharmacy_api.dart';
import '../services/prescription_signature_store.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
import '../widgets/prescription_signature_pad.dart';
import 'live_scanner_page.dart';

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
  State<PrescriptionComposerPage> createState() => _PrescriptionComposerPageState();
}

class _PrescriptionComposerPageState extends State<PrescriptionComposerPage> {
  final _medication = TextEditingController();
  final _dose = TextEditingController();
  final _instructions = TextEditingController();
  final _signatureKey = GlobalKey<PrescriptionSignaturePadState>();
  final _registry = MedicationRegistryClient();
  final _pharmacy = PharmacyApiClient();
  final _signatureStore = PrescriptionSignatureStore();

  String _route = 'Oral';
  String _frequency = 'Once';
  String? _productCode;
  MedicationIdentifier? _identifier;
  MedicationResolution? _resolution;
  DateTime? _scheduledAt;
  bool _busy = false;
  bool _signatureReady = false;

  @override
  void dispose() {
    _medication.dispose();
    _dose.dispose();
    _instructions.dispose();
    _registry.dispose();
    _pharmacy.dispose();
    super.dispose();
  }

  Future<void> _scanMedication() async {
    final capture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(
        builder: (_) => const LiveScannerPage(purpose: ScanPurpose.medication),
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
        if (_medication.text.trim().isEmpty) _medication.text = product.genericName;
        if (_dose.text.trim().isEmpty) _dose.text = product.strength;
      }
    });
  }

  Future<void> _searchMedication() async {
    final queryController = TextEditingController(text: _medication.text.trim());
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search medication'),
        content: TextField(
          controller: queryController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Brand, generic name, ingredient or type',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, queryController.text.trim()), child: const Text('Search')),
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

    final selected = await showModalBottomSheet<MedicationProduct>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Medication results', style: TextStyle(color: medqurInk, fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Choose a product record when available. Public terminology results remain reference-only.', style: TextStyle(color: Color(0xFF718095), fontSize: 12, height: 1.35)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final product in local)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEDF3FF),
                            foregroundColor: medqurBlue,
                            child: Icon(Icons.medication_outlined),
                          ),
                          title: Text(product.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text([product.therapeuticCategory, product.manufacturer].whereType<String>().where((e) => e.isNotEmpty).join(' • ')),
                          onTap: () => Navigator.pop(sheetContext, product),
                        ),
                      if (local.isNotEmpty && remote.isNotEmpty) const Divider(height: 24),
                      for (final item in remote.where((item) => item.product != null))
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                          leading: const Icon(Icons.cloud_done_outlined, color: medqurBlue),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(item.source),
                          onTap: () => Navigator.pop(sheetContext, item.product),
                        ),
                      if (local.isEmpty && remote.where((item) => item.product != null).isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Text('No verified product record was returned. You can still enter the medication manually and pharmacy verification will be required.'),
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

    if (selected == null || !mounted) return;
    final raw = selected.gtin ?? (selected.rawAliases.isEmpty ? selected.id : selected.rawAliases.first);
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
          MedicationProductSource.jamaicaApproved => MedicationResolutionTrust.jamaicaApproved,
          MedicationProductSource.publicReference => MedicationResolutionTrust.publicReference,
          MedicationProductSource.observedPackage => MedicationResolutionTrust.observedPackage,
          MedicationProductSource.prototype => MedicationResolutionTrust.prototype,
        },
        source: selected.sourceLabel,
        message: 'Medication selected from the searchable catalogue.',
      );
    });
  }

  Future<void> _schedule() async {
    final initial = _scheduledAt ?? DateTime.now().add(const Duration(minutes: 30));
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
    setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    final name = _medication.text.trim();
    final dose = _dose.text.trim();
    if (name.isEmpty || dose.isEmpty) {
      _show('Medication and dose are required.');
      return;
    }
    final signature = _signatureKey.currentState?.buildSignature();
    if (signature == null) {
      _show('Sign the prescription before sending it.');
      return;
    }

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
          productId: _uuid(_resolution?.product?.id) ? _resolution?.product?.id : null,
          dueAt: _scheduledAt,
        );
        final order = response['order'];
        if (order is Map<String, dynamic>) backendOrderId = order['id']?.toString();
      }

      final localKey = backendOrderId ??
          '${widget.patient.id}-${DateTime.now().microsecondsSinceEpoch}-${signature.digest.substring(0, 12)}';
      await _signatureStore.save(
        orderKey: localKey,
        signature: signature,
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
      widget.patient.timeline.add(
        '${_timeNow()} — Prescription signed by ${widget.staff.name} • signature ${signature.digest.substring(0, 12)}${_instructions.text.trim().isEmpty ? '' : ' • ${_instructions.text.trim()}'}',
      );
      if (!mounted) return;
      Navigator.pop(context, order);
    } on Object catch (error) {
      if (!mounted) return;
      _show('Prescription could not be sent: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _uuid(String? value) => value != null &&
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$').hasMatch(value);

  String _timeNow() {
    final now = TimeOfDay.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _show(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  String _scheduleLabel() {
    final value = _scheduledAt;
    if (value == null) return 'Schedule first dose (optional)';
    final local = value.toLocal();
    return 'Due ${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final product = _resolution?.product;
    final verified = _resolution?.approvedForClinicalAutomation == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New prescription'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: MedqurPage(
          children: [
            PatientContextBar(patient: widget.patient),
            const SizedBox(height: 18),
            const MedqurPageHeader(
              eyebrow: 'Prescription',
              title: 'Medication order',
              subtitle: 'Structure the order, verify the product when possible, then sign with your finger or stylus.',
            ),
            const SizedBox(height: 18),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _medication,
                    decoration: const InputDecoration(labelText: 'Medication', prefixIcon: Icon(Icons.medication_outlined)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _scanMedication,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Scan package'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _searchMedication,
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Search'),
                        ),
                      ),
                    ],
                  ),
                  if (_identifier != null || _busy) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: verified ? const Color(0xFFEDF9F5) : const Color(0xFFFFF8EA),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: _busy
                          ? const Row(
                              children: [
                                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 10),
                                Text('Identifying medication…', style: TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product?.displayName ?? _identifier!.summary, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800)),
                                if (_resolution != null) ...[
                                  const SizedBox(height: 3),
                                  Text(_resolution!.trustLabel, style: TextStyle(color: verified ? medqurGreen : medqurAmber, fontSize: 11, fontWeight: FontWeight.w700)),
                                ],
                              ],
                            ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dose,
                    decoration: const InputDecoration(labelText: 'Dose', prefixIcon: Icon(Icons.straighten_rounded)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _route,
                    decoration: const InputDecoration(labelText: 'Route'),
                    items: const ['Oral', 'IV', 'IM', 'Inhaled', 'Topical', 'Subcutaneous']
                        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) => setState(() => _route = value ?? _route),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _frequency,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: const ['Once', 'Every 4 hours', 'Every 6 hours', 'Every 8 hours', 'Every 12 hours', 'Daily', 'Twice daily', 'As needed']
                        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) => setState(() => _frequency = value ?? _frequency),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _instructions,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Clinical instructions / notes', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _schedule,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(_scheduleLabel()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Prescriber signature', style: TextStyle(color: medqurInk, fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                      TextButton(
                        onPressed: () => _signatureKey.currentState?.clear(),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const Text(
                    'Sign using your finger or stylus. The signature is stored with a SHA-256 integrity fingerprint; possession of the signature does not replace authenticated clinician access.',
                    style: TextStyle(color: Color(0xFF718095), fontSize: 11.5, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  PrescriptionSignaturePad(
                    key: _signatureKey,
                    onChanged: (value) {
                      if (_signatureReady != value) setState(() => _signatureReady = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || !_signatureReady ? null : _submit,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.verified_user_outlined),
              label: const Text('Sign & send prescription'),
            ),
            const SizedBox(height: 8),
            const Text(
              'The authenticated doctor account remains the legal/audit identity. The drawn signature is an additional visual attestation for the prescription record.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A96A6), fontSize: 10.5, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}
