import 'package:flutter/material.dart';

import '../clinical_clock.dart';
import '../models.dart';
import '../services/medication_identifier.dart';
import '../services/medication_registry.dart';
import '../services/pharmacy_api.dart';
import '../services/prescription_record_store.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
import '../widgets/medqur_responsive.dart';
import 'live_scanner_page.dart';

class PharmacyPage extends StatefulWidget {
  const PharmacyPage({
    super.key,
    required this.staff,
    required this.facility,
    required this.patients,
    required this.onPatientsChanged,
  });

  final StaffProfile staff;
  final Facility facility;
  final List<Patient> patients;
  final Future<void> Function() onPatientsChanged;

  @override
  State<PharmacyPage> createState() => _PharmacyPageState();
}

class _PharmacyPageState extends State<PharmacyPage> {
  final _api = PharmacyApiClient();
  final _registry = MedicationRegistryClient();
  final _records = const PrescriptionRecordStore();
  final _lotController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _recallGtinController = TextEditingController();
  final _recallLotController = TextEditingController();

  int _tab = 0;
  bool _busy = false;
  String? _status;
  MedicationIdentifier? _scanned;
  MedicationResolution? _resolved;
  List<PrescriptionRecord> _prescriptions = const [];
  List<PharmacyInventoryItem> _inventory = const [];
  List<RecallImpact> _recalls = const [];

  String get _role => 'pharmacist';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _busy = true);
    final prescriptions = await _records.forFacility(widget.facility.id);
    List<PharmacyInventoryItem> inventory = _inventory;
    if (_api.isConfigured) {
      try {
        inventory = await _api.inventory(
          facilityId: widget.facility.id,
          staffId: widget.staff.id,
          role: _role,
        );
      } on Object catch (error) {
        _status = '$error';
      }
    }
    if (!mounted) return;
    setState(() {
      _prescriptions = prescriptions;
      _inventory = inventory;
      _busy = false;
    });
  }

  Patient? _patient(String patientId) {
    for (final patient in widget.patients) {
      if (patient.id == patientId) return patient;
    }
    return null;
  }

  ({Patient patient, int index, MedicationOrder order})? _medicationFor(
    PrescriptionRecord record,
  ) {
    final patient = _patient(record.patientId);
    if (patient == null) return null;
    for (var i = 0; i < patient.medications.length; i++) {
      final order = patient.medications[i];
      final idMatch = order.orderId != null &&
          (order.orderId == record.id ||
              order.orderId == record.backendOrderId);
      final contentMatch =
          order.name == record.medication &&
          order.dose == record.dose &&
          order.route == record.route &&
          order.frequency == record.frequency;
      if (idMatch || contentMatch) {
        return (patient: patient, index: i, order: order);
      }
    }
    return null;
  }

  Future<void> _dispense(PrescriptionRecord record) async {
    final medication = _medicationFor(record);
    if (medication == null) {
      _message('The patient medication order could not be matched.');
      return;
    }
    if (record.isDispensed) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Dispense medication?'),
            content: SizedBox(
              width: 390,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.patient.name,
                    style: const TextStyle(
                      color: medqurInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${record.medication} ${record.dose}'),
                  Text('${record.route} • ${record.frequency}'),
                  const SizedBox(height: 8),
                  Text(
                    'Prescribed by ${record.orderedByName} • ${record.orderedById}',
                    style: const TextStyle(
                      color: Color(0xFF687587),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Dispense'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final dispenseId =
          'DSP-${now.microsecondsSinceEpoch}-${record.revision.toString().padLeft(2, '0')}';
      await _records.markDispensed(
        record: record,
        staffId: widget.staff.id,
        dispenseId: dispenseId,
      );
      medication.patient.medications[medication.index] =
          medication.order.copyWith(dispenseId: dispenseId);
      medication.patient.timeline.add(
        '${ClinicalClock.time(now)} — ${record.medication} ${record.dose} dispensed by ${widget.staff.name}',
      );
      await widget.onPatientsChanged();
      _status = 'Medication dispensed and linked to the patient encounter.';
      await _refresh();
    } on Object catch (error) {
      _status = 'Dispense failed: $error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanReceivingPackage() async {
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
      _scanned = identifier;
      _resolved = null;
      if (identifier.lotNumber != null) {
        _lotController.text = identifier.lotNumber!;
      }
      _status = 'Identifying medication…';
      _busy = true;
    });
    try {
      final resolution = await _registry.resolve(identifier);
      if (!mounted) return;
      setState(() {
        _resolved = resolution;
        _status = resolution.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive() async {
    final identifier = _scanned;
    final product = _resolved?.product;
    final quantity = double.tryParse(_quantityController.text.trim());
    if (!_api.isConfigured) {
      _message('Live inventory receiving requires MEDQUR_API_BASE.');
      return;
    }
    if (identifier == null || product == null) {
      _message('Scan and identify the medication first.');
      return;
    }
    if (quantity == null || quantity <= 0 || _lotController.text.trim().isEmpty) {
      _message('Enter a valid lot and quantity.');
      return;
    }

    setState(() => _busy = true);
    try {
      await _api.receiveStock(
        facilityId: widget.facility.id,
        staffId: widget.staff.id,
        role: _role,
        locationCode: 'MAIN-PHARM',
        productId: product.id,
        gtin: identifier.gtin,
        lotNumber: _lotController.text.trim(),
        quantity: quantity,
        unit: 'unit',
        manufactureDate: identifier.manufactureDate,
        expiryDate: identifier.expiryDate,
        serialNumber: identifier.serialNumber ?? '',
        rawScan: identifier.rawValue,
        scanFormat: identifier.kind.name,
      );
      _status = 'Stock received.';
      await _refresh();
    } on Object catch (error) {
      _status = '$error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchRecall() async {
    if (!_api.isConfigured) {
      _message('Recall impact search requires the configured pharmacy backend.');
      return;
    }
    setState(() => _busy = true);
    try {
      final value = await _api.searchRecall(
        staffId: widget.staff.id,
        role: _role,
        gtin: _recallGtinController.text,
        lot: _recallLotController.text,
      );
      if (!mounted) return;
      setState(() {
        _recalls = value;
        _status = value.isEmpty
            ? 'No active recall impact matched.'
            : '${value.length} affected record(s) found.';
      });
    } on Object catch (error) {
      _status = '$error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unitDose(PharmacyInventoryItem item) async {
    if (!_api.isConfigured) return;
    try {
      final result = await _api.generateUnitDoseLabel(
        facilityId: widget.facility.id,
        staffId: widget.staff.id,
        role: _role,
        productId: item.productId,
        lotId: item.lotId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unit-dose code'),
          content: SelectableText(result.codeValue),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      _message('$error');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _api.dispose();
    _registry.dispose();
    _lotController.dispose();
    _quantityController.dispose();
    _recallGtinController.dispose();
    _recallLotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _prescriptions.where((item) => item.isActive).toList();
    final dispensed = _prescriptions.where((item) => item.isDispensed).toList();

    return MedqurPage(
      children: [
        MedqurPageHeader(
          eyebrow: 'Pharmacy • ${widget.facility.name}',
          title: 'Pharmacy',
          subtitle: _tab == 0
              ? 'Signed prescriptions ready for dispensing.'
              : 'Medication inventory and traceability.',
          trailing: _busy
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        if (_status != null) ...[
          const SizedBox(height: 8),
          Text(
            _status!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF687587),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.medication_liquid_outlined),
                label: Text('Dispense'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.inventory_2_outlined),
                label: Text('Inventory'),
              ),
              ButtonSegment(
                value: 2,
                icon: Icon(Icons.add_box_outlined),
                label: Text('Receive'),
              ),
              ButtonSegment(
                value: 3,
                icon: Icon(Icons.warning_amber_rounded),
                label: Text('Recall'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (value) =>
                setState(() => _tab = value.first),
          ),
        ),
        const SizedBox(height: 16),
        if (_tab == 0) _dispenseTab(pending, dispensed),
        if (_tab == 1) _inventoryTab(),
        if (_tab == 2) _receiveTab(),
        if (_tab == 3) _recallTab(),
      ],
    );
  }

  Widget _dispenseTab(
    List<PrescriptionRecord> pending,
    List<PrescriptionRecord> dispensed,
  ) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Pending prescriptions',
            trailing: StatusPill(
              label: '${pending.length}',
              color: pending.isEmpty ? medqurGreen : medqurBlue,
            ),
          ),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const SoftCard(
              padding: EdgeInsets.all(13),
              child: Text(
                'No signed prescriptions waiting to be dispensed.',
                style: TextStyle(color: Color(0xFF687587), fontSize: 12),
              ),
            )
          else
            for (final record in pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PrescriptionDispenseCard(
                  record: record,
                  patient: _patient(record.patientId),
                  onDispense: _busy ? null : () => _dispense(record),
                ),
              ),
          if (dispensed.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionTitle('Recently dispensed'),
            const SizedBox(height: 8),
            for (final record in dispensed.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: SoftCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: medqurGreen,
                        size: 19,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${record.medication} ${record.dose} • ${_patient(record.patientId)?.name ?? record.patientId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: medqurInk,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      );

  Widget _inventoryTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Facility inventory',
            trailing: IconButton(
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 8),
          if (!_api.isConfigured)
            const SoftCard(
              padding: EdgeInsets.all(13),
              child: Text(
                'Connect MEDQUR_API_BASE to load live lot inventory.',
                style: TextStyle(color: Color(0xFF687587), fontSize: 12),
              ),
            )
          else if (_inventory.isEmpty)
            const SoftCard(child: Text('No live inventory loaded.'))
          else
            for (final item in _inventory)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.medication_outlined,
                            color: medqurBlue,
                            size: 19,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: medqurInk,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${item.quantity} ${item.unit} • ${item.locationName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF748297),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: item.approvalStatus,
                            color: item.approvalStatus == 'verified'
                                ? medqurGreen
                                : medqurAmber,
                          ),
                        ],
                      ),
                      if (item.lotNumber != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          'Lot ${item.lotNumber}${item.expiryDate == null ? '' : ' • Exp ${item.expiryDate!.toIso8601String().split('T').first}'}',
                          style: const TextStyle(
                            color: Color(0xFF748297),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _unitDose(item),
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('Unit-dose code'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      );

  Widget _receiveTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Receive stock'),
          const SizedBox(height: 8),
          SoftCard(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _scanReceivingPackage,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan package'),
                ),
                if (_resolved?.product != null) ...[
                  const SizedBox(height: 9),
                  Text(
                    _resolved!.product!.displayName,
                    style: const TextStyle(
                      color: medqurInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                ResponsiveFields(
                  children: [
                    TextField(
                      controller: _lotController,
                      decoration: const InputDecoration(labelText: 'Lot'),
                    ),
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _receive,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Receive stock'),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _recallTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Recall impact'),
          const SizedBox(height: 8),
          SoftCard(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveFields(
                  children: [
                    TextField(
                      controller: _recallGtinController,
                      decoration: const InputDecoration(labelText: 'GTIN'),
                    ),
                    TextField(
                      controller: _recallLotController,
                      decoration: const InputDecoration(labelText: 'Lot'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _busy ? null : _searchRecall,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search recall'),
                ),
              ],
            ),
          ),
          if (_recalls.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final recall in _recalls)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: SoftCard(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '${recall.genericName} ${recall.brandName} • ${recall.reason}',
                    style: const TextStyle(
                      color: medqurInk,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
          ],
        ],
      );
}

class _PrescriptionDispenseCard extends StatelessWidget {
  const _PrescriptionDispenseCard({
    required this.record,
    required this.patient,
    required this.onDispense,
  });

  final PrescriptionRecord record;
  final Patient? patient;
  final VoidCallback? onDispense;

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 420;
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient?.name ?? record.patientId,
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
                  '${record.medication} ${record.dose} • ${record.frequency}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF687587),
                    fontSize: 10.75,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.orderedByName} • signed R${record.revision}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8793A2),
                    fontSize: 10.25,
                  ),
                ),
              ],
            );
            final button = FilledButton(
              onPressed: onDispense,
              child: const Text('Dispense'),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  info,
                  const SizedBox(height: 9),
                  button,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 10),
                button,
              ],
            );
          },
        ),
      );
}
