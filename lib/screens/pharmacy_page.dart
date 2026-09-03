import 'package:flutter/material.dart';

import '../models.dart';
import '../services/medication_identifier.dart';
import '../services/medication_registry.dart';
import '../services/pharmacy_api.dart';
import '../widgets/common.dart';
import 'live_scanner_page.dart';

class PharmacyPage extends StatefulWidget {
  const PharmacyPage({
    super.key,
    required this.staff,
    required this.facility,
  });

  final StaffProfile staff;
  final Facility facility;

  @override
  State<PharmacyPage> createState() => _PharmacyPageState();
}

class _PharmacyPageState extends State<PharmacyPage> {
  final _api = PharmacyApiClient();
  final _registry = MedicationRegistryClient();
  final _lotController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _recallGtinController = TextEditingController();
  final _recallLotController = TextEditingController();

  int tab = 0;
  bool busy = false;
  String? status;
  MedicationIdentifier? scanned;
  MedicationResolution? resolved;
  List<PharmacyInventoryItem> inventory = const [];
  List<RecallImpact> recalls = const [];

  String get _role => 'pharmacist';

  @override
  void initState() {
    super.initState();
    if (_api.isConfigured) _loadInventory();
  }

  Future<void> _loadInventory() async {
    if (!_api.isConfigured) return;
    setState(() => busy = true);
    try {
      final value = await _api.inventory(
        facilityId: widget.facility.id,
        staffId: widget.staff.id,
        role: _role,
      );
      if (!mounted) return;
      setState(() {
        inventory = value;
        status = 'Inventory refreshed from ${widget.facility.name}.';
      });
    } on Object catch (error) {
      if (mounted) setState(() => status = '$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _scanReceivingPackage() async {
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
      scanned = identifier;
      resolved = null;
      if (identifier.lotNumber != null) _lotController.text = identifier.lotNumber!;
      status = 'Resolving medication identity…';
      busy = true;
    });
    try {
      final resolution = await _registry.resolve(identifier);
      if (!mounted) return;
      setState(() {
        resolved = resolution;
        status = resolution.message;
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _receive() async {
    final identifier = scanned;
    final product = resolved?.product;
    final quantity = double.tryParse(_quantityController.text.trim());
    if (!_api.isConfigured) {
      setState(() => status = 'Backend not configured. Set MEDQUR_API_BASE before receiving real inventory.');
      return;
    }
    if (identifier == null || product == null) {
      setState(() => status = 'Scan and resolve the medication before receiving stock.');
      return;
    }
    if (quantity == null || quantity <= 0 || _lotController.text.trim().isEmpty) {
      setState(() => status = 'Enter a valid lot number and quantity.');
      return;
    }
    setState(() => busy = true);
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
      if (!mounted) return;
      setState(() => status = 'Stock received. It remains traceable by product, lot, expiry and facility location.');
      await _loadInventory();
    } on Object catch (error) {
      if (mounted) setState(() => status = '$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _searchRecall() async {
    if (!_api.isConfigured) {
      setState(() => status = 'Backend not configured. Recall impact requires the PostgreSQL pharmacy service.');
      return;
    }
    setState(() => busy = true);
    try {
      final value = await _api.searchRecall(
        staffId: widget.staff.id,
        role: _role,
        gtin: _recallGtinController.text,
        lot: _recallLotController.text,
      );
      if (!mounted) return;
      setState(() {
        recalls = value;
        status = value.isEmpty
            ? 'No active recall impact matched that GTIN/lot.'
            : '${value.length} affected inventory/patient record(s) found.';
      });
    } on Object catch (error) {
      if (mounted) setState(() => status = '$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _unitDose(PharmacyInventoryItem item) async {
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
          icon: const Icon(Icons.qr_code_2_rounded, color: medqurBlue),
          title: const Text('Unit-dose DataMatrix created'),
          content: SelectableText(
            '${result.codeValue}\n\nThe backend also generated Zebra ZPL. Use this only when the individual dose does not already carry a usable manufacturer code.',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      );
    } on Object catch (error) {
      if (mounted) setState(() => status = '$error');
    }
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
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pharmacy', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 5),
                  Text('${widget.facility.name} • medication master + lot inventory'),
                ],
              ),
            ),
            if (busy) const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
          ],
        ),
        const SizedBox(height: 16),
        if (!_api.isConfigured)
          const SoftCard(
            highlighted: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off_rounded, color: medqurAmber),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The pharmacy UI is installed, but this public build has no clinical backend configured. Build with MEDQUR_API_BASE and authenticated OIDC access for live receiving, inventory, recall and dispense data.',
                  ),
                ),
              ],
            ),
          ),
        if (status != null) ...[
          const SizedBox(height: 10),
          Text(status!, style: const TextStyle(color: Color(0xFF65748A), fontSize: 12, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 18),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, icon: Icon(Icons.inventory_2_outlined), label: Text('Inventory')),
            ButtonSegment(value: 1, icon: Icon(Icons.add_box_outlined), label: Text('Receive')),
            ButtonSegment(value: 2, icon: Icon(Icons.warning_amber_rounded), label: Text('Recall')),
          ],
          selected: {tab},
          onSelectionChanged: (value) => setState(() => tab = value.first),
        ),
        const SizedBox(height: 18),
        if (tab == 0) _inventoryTab(),
        if (tab == 1) _receiveTab(),
        if (tab == 2) _recallTab(),
      ],
    );
  }

  Widget _inventoryTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SectionTitle('Facility inventory')),
              IconButton(onPressed: busy ? null : _loadInventory, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          const SizedBox(height: 8),
          if (inventory.isEmpty)
            const SoftCard(child: Text('No live inventory loaded.'))
          else
            for (final item in inventory)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.medication_outlined, color: medqurBlue),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.displayName, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 3),
                                Text('${item.quantity} ${item.unit} • ${item.locationName}', style: const TextStyle(fontSize: 12)),
                                if (item.lotNumber != null)
                                  Text('Lot ${item.lotNumber}${item.expiryDate == null ? '' : ' • Exp ${item.expiryDate!.toIso8601String().split('T').first}'}', style: const TextStyle(fontSize: 11, color: Color(0xFF748297))),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: item.approvalStatus,
                            color: item.approvalStatus == 'verified' ? medqurGreen : medqurAmber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _api.isConfigured ? () => _unitDose(item) : null,
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('Create internal unit-dose code'),
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
          FilledButton.icon(
            onPressed: busy ? null : _scanReceivingPackage,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan medication package'),
          ),
          if (scanned != null) ...[
            const SizedBox(height: 10),
            SoftCard(
              highlighted: resolved?.found == true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resolved?.product?.displayName ?? scanned!.summary, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(scanned!.summary, style: const TextStyle(fontSize: 11, color: Color(0xFF65748A))),
                  if (resolved != null) ...[
                    const SizedBox(height: 5),
                    Text(resolved!.trustLabel, style: TextStyle(fontSize: 11, color: resolved!.approvedForClinicalAutomation ? medqurGreen : medqurAmber, fontWeight: FontWeight.w800)),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(controller: _lotController, decoration: const InputDecoration(labelText: 'Lot / batch number')),
          const SizedBox(height: 10),
          TextField(controller: _quantityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity received')),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy ? null : _receive,
            icon: const Icon(Icons.inventory_rounded),
            label: const Text('Receive into Main Pharmacy'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Receiving records GTIN/product, lot, expiry, quantity, location, scanner payload and receiving staff. A pharmacist must still verify product provenance before clinical automation.',
            style: TextStyle(fontSize: 11, color: Color(0xFF748297), height: 1.35),
          ),
        ],
      );

  Widget _recallTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: _recallGtinController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'GTIN / barcode', prefixIcon: Icon(Icons.barcode_reader))),
          const SizedBox(height: 10),
          TextField(controller: _recallLotController, decoration: const InputDecoration(labelText: 'Lot number (optional)')),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: busy ? null : _searchRecall, icon: const Icon(Icons.search_rounded), label: const Text('Search recall impact')),
          const SizedBox(height: 14),
          for (final item in recalls)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                highlighted: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text('${item.genericName} ${item.brandName}'.trim(), style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900))),
                      StatusPill(label: item.severity.toUpperCase(), color: medqurRed),
                    ]),
                    const SizedBox(height: 6),
                    Text(item.reason),
                    const SizedBox(height: 5),
                    Text('GTIN ${item.gtin ?? '—'} • Lot ${item.lotNumber ?? 'all lots'}', style: const TextStyle(fontSize: 11, color: Color(0xFF65748A))),
                    if (item.inventoryQuantity != null)
                      Text('Inventory affected: ${item.inventoryQuantity}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    if (item.patientId != null)
                      Text('Administration record: patient ${item.patientId} • encounter ${item.encounterId ?? '—'}', style: const TextStyle(fontSize: 11, color: medqurRed, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      );
}
