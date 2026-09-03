import 'package:flutter/material.dart';

import '../models.dart';
import '../services/access_policy.dart';
import '../services/medication_identifier.dart';
import '../services/medication_registry.dart';
import '../services/medication_safety.dart';
import '../services/pharmacy_api.dart';
import '../widgets/common.dart';
import 'live_scanner_page.dart';

class PatientDetailPageV2 extends StatefulWidget {
  const PatientDetailPageV2({
    super.key,
    required this.staff,
    required this.patient,
    required this.onChanged,
  });
  final StaffProfile staff;
  final Patient patient;
  final VoidCallback onChanged;

  @override
  State<PatientDetailPageV2> createState() => _PatientDetailPageV2State();
}

class _PatientDetailPageV2State extends State<PatientDetailPageV2> {
  final MedicationRegistryClient _registry = MedicationRegistryClient();
  final PharmacyApiClient _pharmacyApi = PharmacyApiClient();

  bool get canOrder => AccessPolicy.allows(
        widget.staff.role,
        ClinicalAction.createMedicationOrder,
      );
  bool get canAdminister => AccessPolicy.allows(
        widget.staff.role,
        ClinicalAction.administerMedication,
      );
  bool get canAssign => AccessPolicy.allows(
        widget.staff.role,
        ClinicalAction.assignPatient,
      );

  String get _facilityId {
    final name = widget.patient.facilityName?.trim();
    for (final facility in widget.staff.facilities) {
      if (name != null && name.isNotEmpty && facility.name == name) {
        return facility.id;
      }
    }
    return widget.staff.facilities.isEmpty ? 'MRH' : widget.staff.facilities.first.id;
  }

  String _timeNow() {
    final now = TimeOfDay.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  bool _uuid(String? value) => value != null &&
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);

  void _changed() {
    widget.onChanged();
    if (mounted) setState(() {});
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? medqurRed : null,
      ),
    );
  }

  void _assignToMe() {
    if (!canAssign) return;
    widget.patient.assignedStaffId = widget.staff.id;
    widget.patient.assignedStaffName = widget.staff.name;
    widget.patient.status = PatientStatus.withDoctor;
    widget.patient.timeline.add(
      '${_timeNow()} — Assigned to ${widget.staff.name}',
    );
    _changed();
    _message('Patient assigned to you.');
  }

  Future<DateTime?> _pickSchedule(
    BuildContext context,
    DateTime? current,
  ) async {
    final initial = current ?? DateTime.now().add(const Duration(minutes: 30));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return current;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return current;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _addOrder() async {
    if (!canOrder) return;
    final medication = TextEditingController();
    final dose = TextEditingController();
    String route = 'Oral';
    String frequency = 'Once';
    String? productCode;
    MedicationIdentifier? productIdentifier;
    MedicationResolution? resolution;
    DateTime? scheduledAt;
    var resolving = false;

    final order = await showModalBottomSheet<MedicationOrder>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> scanPackage() async {
            final capture = await Navigator.of(sheetContext).push<ScanCapture>(
              MaterialPageRoute(
                builder: (_) => const LiveScannerPage(
                  purpose: ScanPurpose.medication,
                ),
              ),
            );
            if (capture == null) return;
            final parsed = MedicationIdentifierParser.parse(
              capture.value,
              formatName: capture.format.name,
            );
            setSheetState(() {
              productCode = capture.value;
              productIdentifier = parsed;
              resolution = null;
              resolving = true;
            });
            final resolved = await _registry.resolve(parsed);
            if (!sheetContext.mounted) return;
            setSheetState(() {
              resolution = resolved;
              resolving = false;
              final product = resolved.product;
              if (product != null && medication.text.trim().isEmpty) {
                medication.text = product.genericName;
              }
              if (product != null && dose.text.trim().isEmpty) {
                dose.text = product.strength;
              }
            });
          }

          Future<void> chooseSchedule() async {
            final selected = await _pickSchedule(sheetContext, scheduledAt);
            if (!sheetContext.mounted) return;
            setSheetState(() => scheduledAt = selected);
          }

          final product = resolution?.product;
          final verified = resolution?.approvedForClinicalAutomation == true;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                6,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Medication order',
                      style: TextStyle(
                        color: medqurInk,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: medication,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Medication',
                        hintText: 'e.g. Paracetamol',
                        prefixIcon: Icon(Icons.medication_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dose,
                      decoration: const InputDecoration(
                        labelText: 'Dose',
                        hintText: 'e.g. 1 g',
                        prefixIcon: Icon(Icons.straighten_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: route,
                      decoration: const InputDecoration(labelText: 'Route'),
                      items: const ['Oral', 'IV', 'IM', 'Inhaled', 'Topical']
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => route = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        'Once',
                        'Every 4 hours',
                        'Every 6 hours',
                        'Every 8 hours',
                        'Daily',
                      ]
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => frequency = value);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: resolving ? null : scanPackage,
                      icon: resolving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.qr_code_scanner_rounded),
                      label: Text(
                        productCode == null
                            ? 'Scan package barcode / DataMatrix'
                            : 'Package code captured',
                      ),
                    ),
                    if (productIdentifier != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        product?.displayName ?? productIdentifier!.summary,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: verified ? medqurGreen : medqurAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (resolution != null)
                        Text(
                          '${resolution!.trustLabel} • ${resolution!.message}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF748297),
                            fontSize: 10,
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: chooseSchedule,
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(
                        scheduledAt == null
                            ? 'Schedule dose (optional)'
                            : 'Due ${_formatDateTime(scheduledAt!)}',
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Default administration window: 30 minutes early / 60 minutes late. The backend enforces the signed order and duplicate-dose checks when configured.',
                      style: TextStyle(
                        color: Color(0xFF748297),
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () {
                        final name = medication.text.trim();
                        final doseValue = dose.text.trim();
                        if (name.isEmpty || doseValue.isEmpty) return;
                        Navigator.of(sheetContext).pop(
                          MedicationOrder(
                            name: name,
                            dose: doseValue,
                            route: route,
                            frequency: frequency,
                            orderedBy: widget.staff.name,
                            productCode: productCode,
                            productId: product?.id,
                            scheduledAt: scheduledAt,
                            productVerified: verified,
                          ),
                        );
                      },
                      icon: const Icon(Icons.draw_outlined),
                      label: const Text('Sign & send order'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    medication.dispose();
    dose.dispose();
    if (order == null || !mounted) return;

    var finalOrder = order;
    if (_pharmacyApi.isConfigured) {
      try {
        final response = await _pharmacyApi.createOrder(
          staffId: widget.staff.id,
          facilityId: _facilityId,
          patientId: widget.patient.id,
          encounterId: widget.patient.effectiveEncounterId,
          medicationText: order.name,
          dose: order.dose,
          route: order.route,
          frequency: order.frequency,
          productId: _uuid(order.productId) ? order.productId : null,
          dueAt: order.scheduledAt,
          earlyGraceMinutes: order.earlyGraceMinutes,
          lateGraceMinutes: order.lateGraceMinutes,
        );
        final backendOrder = response['order'];
        if (backendOrder is Map<String, dynamic>) {
          finalOrder = order.copyWith(
            orderId: backendOrder['id']?.toString(),
            productId: backendOrder['product_id']?.toString(),
          );
        }
      } on Object catch (error) {
        _message('Order was not accepted by the backend: $error', error: true);
        return;
      }
    }

    widget.patient.medications.add(finalOrder);
    widget.patient.status = PatientStatus.treatment;
    widget.patient.timeline.add(
      '${_timeNow()} — ${finalOrder.name} ${finalOrder.dose} ordered by ${widget.staff.name}'
      '${finalOrder.scheduledAt == null ? '' : ' • due ${_formatDateTime(finalOrder.scheduledAt!)}'}',
    );
    _changed();
    _message(
      _pharmacyApi.isConfigured
          ? 'Signed order synchronized to pharmacy.'
          : 'Order saved in the local prototype task list.',
    );
  }

  Future<void> _mapMedicationCode(MedicationOrder medication) async {
    if (!canOrder) return;
    final capture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(
        builder: (_) => const LiveScannerPage(purpose: ScanPurpose.medication),
      ),
    );
    if (capture == null || !mounted) return;
    final parsed = MedicationIdentifierParser.parse(
      capture.value,
      formatName: capture.format.name,
    );
    final resolution = await _registry.resolve(parsed);
    if (!mounted) return;
    final index = widget.patient.medications.indexOf(medication);
    if (index < 0) return;
    widget.patient.medications[index] = medication.copyWith(
      productCode: capture.value,
      productId: resolution.product?.id,
      productVerified: resolution.approvedForClinicalAutomation,
    );
    widget.patient.timeline.add(
      '${_timeNow()} — Medication package code mapped by ${widget.staff.name}'
      '${parsed.gtin == null ? '' : ' • GTIN ${parsed.gtin}'} • ${resolution.trustLabel}',
    );
    _changed();
    _message(
      resolution.approvedForClinicalAutomation
          ? '${resolution.product!.displayName} verified and mapped to this order.'
          : 'Code mapped, but approved medication-master/pharmacist verification is still required.',
    );
  }

  Future<void> _showBlockers(List<String> blockers) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.block_rounded, color: medqurRed),
        title: const Text('Administration blocked'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final blocker in blockers)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $blocker'),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _administer(MedicationOrder medication) async {
    if (!canAdminister) return;
    if (medication.productCode == null || medication.productCode!.isEmpty) {
      _message('This order has no approved package code mapped yet.', error: true);
      return;
    }

    final patientCapture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(
        builder: (_) => const LiveScannerPage(
          purpose: ScanPurpose.patientWristband,
        ),
      ),
    );
    if (patientCapture == null || !mounted) return;
    if (patientCapture.value != widget.patient.encounterToken &&
        patientCapture.value != widget.patient.effectiveEncounterId &&
        patientCapture.value != widget.patient.id) {
      _message('Wristband mismatch. Medication was not administered.', error: true);
      return;
    }

    final medCapture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(
        builder: (_) => const LiveScannerPage(purpose: ScanPurpose.medication),
      ),
    );
    if (medCapture == null || !mounted) return;
    final scanned = MedicationIdentifierParser.parse(
      medCapture.value,
      formatName: medCapture.format.name,
    );
    final resolution = await _registry.resolve(scanned);
    if (!mounted) return;

    var workingOrder = medication;
    if (resolution.approvedForClinicalAutomation && resolution.product != null) {
      workingOrder = medication.copyWith(
        productId: resolution.product!.id,
        productVerified: true,
      );
    }

    final safety = MedicationSafetyEngine.evaluate(
      patient: widget.patient,
      order: workingOrder,
      scan: scanned,
    );
    final blockers = <String>[...safety.blockers];

    if (_pharmacyApi.isConfigured &&
        _uuid(workingOrder.productId) &&
        _uuid(workingOrder.orderId)) {
      try {
        final structured = await _pharmacyApi.structuredSafetyCheck(
          staffId: widget.staff.id,
          facilityId: _facilityId,
          patientId: widget.patient.id,
          productId: workingOrder.productId!,
          currentProductIds: widget.patient.medications
              .where((item) => item.productId != null && _uuid(item.productId))
              .map((item) => item.productId!)
              .toList(),
        );
        if (structured['allowed'] == false) {
          final allergies = structured['allergies'] as List<dynamic>? ?? const [];
          final interactions = structured['interactions'] as List<dynamic>? ?? const [];
          if (allergies.isNotEmpty) {
            blockers.add('Structured medication-allergy check found an approved coded conflict.');
          }
          if (interactions.isNotEmpty) {
            blockers.add('Approved interaction knowledge reported a major/contraindicated conflict.');
          }
        }
      } on Object catch (error) {
        blockers.add('The structured clinical safety service could not be completed: $error');
      }
    }

    if (blockers.isNotEmpty) {
      await _showBlockers(blockers);
      widget.patient.timeline.add(
        '${_timeNow()} — Medication administration blocked after scan by ${widget.staff.name}: ${blockers.join('; ')}',
      );
      _changed();
      return;
    }

    final product = resolution.product;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified_rounded, color: medqurGreen),
        title: const Text('Patient + medication verified'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.patient.name}\n${medication.name} ${medication.dose}\n${medication.route} • ${medication.frequency}',
            ),
            const SizedBox(height: 10),
            Text(
              scanned.summary,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF65748A),
              ),
            ),
            if (product != null) ...[
              const SizedBox(height: 5),
              Text(
                '${resolution.trustLabel}: ${product.displayName}',
                style: TextStyle(
                  fontSize: 11,
                  color: resolution.approvedForClinicalAutomation
                      ? medqurGreen
                      : medqurAmber,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (safety.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final warning in safety.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Warning: $warning',
                    style: const TextStyle(
                      fontSize: 11,
                      color: medqurAmber,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Record administration'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    if (_pharmacyApi.isConfigured) {
      if (!_uuid(workingOrder.orderId) || !_uuid(workingOrder.productId)) {
        _message(
          'Backend workflow requires a synchronized order and approved product ID. Administration was not recorded.',
          error: true,
        );
        return;
      }
      try {
        await _pharmacyApi.recordAdministration(
          staffId: widget.staff.id,
          facilityId: _facilityId,
          orderId: workingOrder.orderId!,
          patientId: widget.patient.id,
          encounterId: widget.patient.effectiveEncounterId,
          productId: workingOrder.productId!,
          patientScan: patientCapture.value,
          medicationScan: medCapture.value,
          dispenseId: _uuid(workingOrder.dispenseId)
              ? workingOrder.dispenseId
              : null,
          lotId: _uuid(workingOrder.lotId) ? workingOrder.lotId : null,
        );
      } on Object catch (error) {
        _message('Backend blocked/failed the administration: $error', error: true);
        return;
      }
    }

    final index = widget.patient.medications.indexOf(medication);
    if (index < 0) return;
    widget.patient.medications[index] = workingOrder.copyWith(administered: true);
    widget.patient.timeline.add(
      '${_timeNow()} — ${medication.name} ${medication.dose} administered by ${widget.staff.name} after wristband + medication scan'
      '${scanned.gtin == null ? '' : ' • GTIN ${scanned.gtin}'}'
      '${scanned.lotNumber == null ? '' : ' • lot ${scanned.lotNumber}'}',
    );
    _changed();
    _message(
      _pharmacyApi.isConfigured
          ? 'Administration recorded and synchronized.'
          : 'Administration recorded in the local prototype.',
    );
  }

  @override
  void dispose() {
    _registry.dispose();
    _pharmacyApi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;
    final color = triageColor(patient.triage);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: const Row(
          children: [
            MedqurLogo(width: 104),
            SizedBox(width: 10),
            Text(
              'Patient',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: color.withValues(alpha: .10),
                      foregroundColor: color,
                      child: Text(
                        patient.name.startsWith('Unknown')
                            ? '?'
                            : patient.name
                                .split(' ')
                                .take(2)
                                .map((part) => part[0])
                                .join(),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.name,
                            style: const TextStyle(
                              color: medqurInk,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${patient.id} • ${patient.age == 0 ? 'Age unknown' : '${patient.age} years'} • ${patient.sex}',
                            style: const TextStyle(
                              color: Color(0xFF6B7A8F),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(label: triageLabel(patient.triage), color: color),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FakeQr(size: 74, data: patient.encounterToken),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Encounter wristband token',
                            style: TextStyle(
                              color: Color(0xFF8793A4),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            patient.assignedStaffName ?? 'Unassigned clinician',
                            style: const TextStyle(
                              color: medqurInk,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (canAssign && patient.assignedStaffId != widget.staff.id)
                            TextButton.icon(
                              onPressed: _assignToMe,
                              icon: const Icon(
                                Icons.person_add_alt_1_rounded,
                                size: 18,
                              ),
                              label: const Text('Assign to me'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Chief complaint'),
          const SizedBox(height: 9),
          SoftCard(
            child: Text(
              patient.chiefComplaint,
              style: const TextStyle(
                color: medqurInk,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Latest vitals'),
          const SizedBox(height: 9),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: patient.vitals.entries
                .map(
                  (entry) => Container(
                    width: 145,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: medqurLine),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            color: Color(0xFF78869A),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            color: medqurInk,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Allergies'),
          const SizedBox(height: 9),
          SoftCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: patient.allergies
                  .map(
                    (item) => StatusPill(
                      label: item,
                      color: item.toLowerCase().contains('no known')
                          ? medqurGreen
                          : medqurRed,
                      icon: Icons.warning_amber_rounded,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          SectionTitle(
            'Medication orders',
            trailing: canOrder
                ? TextButton.icon(
                    onPressed: _addOrder,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  )
                : null,
          ),
          const SizedBox(height: 9),
          if (patient.medications.isEmpty)
            const SoftCard(child: Text('No active medication orders.'))
          else
            for (final medication in patient.medications)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: (medication.administered
                                    ? medqurGreen
                                    : medqurBlue)
                                .withValues(alpha: .10),
                            foregroundColor: medication.administered
                                ? medqurGreen
                                : medqurBlue,
                            child: Icon(
                              medication.administered
                                  ? Icons.check_rounded
                                  : Icons.medication_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${medication.name} • ${medication.dose}',
                                  style: const TextStyle(
                                    color: medqurInk,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${medication.route} • ${medication.frequency}',
                                  style: const TextStyle(
                                    color: Color(0xFF65748A),
                                    fontSize: 12,
                                  ),
                                ),
                                if (medication.scheduledAt != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Due ${_formatDateTime(medication.scheduledAt!)} • window -${medication.earlyGraceMinutes}/+${medication.lateGraceMinutes} min',
                                    style: const TextStyle(
                                      color: Color(0xFF65748A),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 3),
                                Text(
                                  medication.productCode == null
                                      ? 'Package code not mapped'
                                      : MedicationIdentifierParser.parse(
                                          medication.productCode!,
                                        ).summary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: medication.productCode == null
                                        ? medqurAmber
                                        : medication.productVerified
                                            ? medqurGreen
                                            : medqurAmber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (medication.productCode != null)
                                  Text(
                                    medication.productVerified
                                        ? 'Approved medication-master match'
                                        : 'Verification still required',
                                    style: TextStyle(
                                      color: medication.productVerified
                                          ? medqurGreen
                                          : medqurAmber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: medication.administered ? 'Given' : 'Pending',
                            color: medication.administered
                                ? medqurGreen
                                : medqurAmber,
                          ),
                        ],
                      ),
                      if (canOrder &&
                          !medication.administered &&
                          medication.productCode == null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _mapMedicationCode(medication),
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Map package barcode'),
                        ),
                      ],
                      if (canAdminister && !medication.administered) ...[
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () => _administer(medication),
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Scan wristband + medication'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 20),
          const SectionTitle('Encounter timeline'),
          const SizedBox(height: 9),
          SoftCard(
            child: Column(
              children: [
                for (var i = 0; i < patient.timeline.length; i++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: medqurBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            patient.timeline[i],
                            style: const TextStyle(
                              color: medqurInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Prototype only • Production medication actions require authenticated backend, approved medication master, pharmacy verification and approved clinical knowledge sources.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8793A4), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
