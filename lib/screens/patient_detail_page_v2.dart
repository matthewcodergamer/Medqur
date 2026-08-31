import 'package:flutter/material.dart';
import '../models.dart';
import '../services/access_policy.dart';
import '../widgets/common.dart';
import 'live_scanner_page.dart';

class PatientDetailPageV2 extends StatefulWidget {
  const PatientDetailPageV2({super.key, required this.staff, required this.patient, required this.onChanged});
  final StaffProfile staff;
  final Patient patient;
  final VoidCallback onChanged;

  @override
  State<PatientDetailPageV2> createState() => _PatientDetailPageV2State();
}

class _PatientDetailPageV2State extends State<PatientDetailPageV2> {
  bool get canOrder => AccessPolicy.allows(widget.staff.role, ClinicalAction.createMedicationOrder);
  bool get canAdminister => AccessPolicy.allows(widget.staff.role, ClinicalAction.administerMedication);
  bool get canAssign => AccessPolicy.allows(widget.staff.role, ClinicalAction.assignPatient);

  String _timeNow() {
    final now = TimeOfDay.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _changed() {
    widget.onChanged();
    if (mounted) setState(() {});
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? medqurRed : null,
    ));
  }

  void _assignToMe() {
    if (!canAssign) return;
    widget.patient.assignedStaffId = widget.staff.id;
    widget.patient.assignedStaffName = widget.staff.name;
    widget.patient.status = PatientStatus.withDoctor;
    widget.patient.timeline.add('${_timeNow()} — Assigned to ${widget.staff.name}');
    _changed();
    _message('Patient assigned to you.');
  }

  Future<void> _addOrder() async {
    if (!canOrder) return;
    final medication = TextEditingController();
    final dose = TextEditingController();
    String route = 'Oral';
    String frequency = 'Once';
    String? productCode;

    final order = await showModalBottomSheet<MedicationOrder>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        Future<void> scanPackage() async {
          final capture = await Navigator.of(sheetContext).push<ScanCapture>(
            MaterialPageRoute(builder: (_) => const LiveScannerPage(purpose: ScanPurpose.medication)),
          );
          if (capture != null) setSheetState(() => productCode = capture.value);
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Medication order', style: TextStyle(color: medqurInk, fontWeight: FontWeight.w900, fontSize: 22)),
                const SizedBox(height: 18),
                TextField(controller: medication, autofocus: true, decoration: const InputDecoration(labelText: 'Medication', hintText: 'e.g. Paracetamol', prefixIcon: Icon(Icons.medication_outlined))),
                const SizedBox(height: 12),
                TextField(controller: dose, decoration: const InputDecoration(labelText: 'Dose', hintText: 'e.g. 1 g', prefixIcon: Icon(Icons.straighten_rounded))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: route,
                  decoration: const InputDecoration(labelText: 'Route'),
                  items: const ['Oral', 'IV', 'IM', 'Inhaled', 'Topical'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                  onChanged: (value) { if (value != null) setSheetState(() => route = value); },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const ['Once', 'Every 4 hours', 'Every 6 hours', 'Every 8 hours', 'Daily'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                  onChanged: (value) { if (value != null) setSheetState(() => frequency = value); },
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: scanPackage,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(productCode == null ? 'Scan package barcode / QR' : 'Package code captured'),
                ),
                if (productCode != null) ...[
                  const SizedBox(height: 7),
                  Text(productCode!, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF748297), fontSize: 11)),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    final name = medication.text.trim();
                    final doseValue = dose.text.trim();
                    if (name.isEmpty || doseValue.isEmpty) return;
                    Navigator.of(sheetContext).pop(MedicationOrder(
                      name: name,
                      dose: doseValue,
                      route: route,
                      frequency: frequency,
                      orderedBy: widget.staff.name,
                      productCode: productCode,
                    ));
                  },
                  icon: const Icon(Icons.draw_outlined),
                  label: const Text('Sign & send order'),
                ),
              ]),
            ),
          ),
        );
      }),
    );

    medication.dispose();
    dose.dispose();
    if (order == null || !mounted) return;
    widget.patient.medications.add(order);
    widget.patient.status = PatientStatus.treatment;
    widget.patient.timeline.add('${_timeNow()} — ${order.name} ${order.dose} ordered by ${widget.staff.name}');
    _changed();
    _message('Order sent to the nursing task list.');
  }

  Future<void> _mapMedicationCode(MedicationOrder medication) async {
    if (!canOrder) return;
    final capture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(builder: (_) => const LiveScannerPage(purpose: ScanPurpose.medication)),
    );
    if (capture == null || !mounted) return;
    final index = widget.patient.medications.indexOf(medication);
    if (index < 0) return;
    widget.patient.medications[index] = medication.copyWith(productCode: capture.value);
    widget.patient.timeline.add('${_timeNow()} — Medication package code mapped by ${widget.staff.name}');
    _changed();
    _message('Package barcode mapped to this order.');
  }

  Future<void> _administer(MedicationOrder medication) async {
    if (!canAdminister) return;
    if (medication.productCode == null || medication.productCode!.isEmpty) {
      _message('This order has no approved package code mapped yet.', error: true);
      return;
    }

    final patientCapture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(builder: (_) => const LiveScannerPage(purpose: ScanPurpose.patientWristband)),
    );
    if (patientCapture == null || !mounted) return;
    if (patientCapture.value != widget.patient.encounterToken && patientCapture.value != widget.patient.id) {
      _message('Wristband mismatch. Medication was not administered.', error: true);
      return;
    }

    final medCapture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(builder: (_) => const LiveScannerPage(purpose: ScanPurpose.medication)),
    );
    if (medCapture == null || !mounted) return;
    if (medCapture.value != medication.productCode) {
      _message('Medication barcode mismatch. Medication was not administered.', error: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified_rounded, color: medqurGreen),
        title: const Text('Both scans matched'),
        content: Text('${widget.patient.name}\n${medication.name} ${medication.dose}\n${medication.route} • ${medication.frequency}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Record administration')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final index = widget.patient.medications.indexOf(medication);
    if (index < 0) return;
    widget.patient.medications[index] = medication.copyWith(administered: true);
    widget.patient.timeline.add('${_timeNow()} — ${medication.name} ${medication.dose} administered by ${widget.staff.name} after wristband + package scan');
    _changed();
    _message('Administration recorded.');
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
        title: const Row(children: [MedqurLogo(width: 104), SizedBox(width: 10), Text('Patient', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))]),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
        children: [
          SoftCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 27, backgroundColor: color.withValues(alpha: .10), foregroundColor: color, child: Text(patient.name.startsWith('Unknown') ? '?' : patient.name.split(' ').take(2).map((part) => part[0]).join(), style: const TextStyle(fontWeight: FontWeight.w900))),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(patient.name, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900, fontSize: 20)),
                  const SizedBox(height: 4),
                  Text('${patient.id} • ${patient.age == 0 ? 'Age unknown' : '${patient.age} years'} • ${patient.sex}', style: const TextStyle(color: Color(0xFF6B7A8F), fontSize: 12)),
                ])),
                StatusPill(label: triageLabel(patient.triage), color: color),
              ]),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                FakeQr(size: 74, data: patient.encounterToken),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Encounter wristband token', style: TextStyle(color: Color(0xFF8793A4), fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(patient.assignedStaffName ?? 'Unassigned clinician', style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800)),
                  if (canAssign && patient.assignedStaffId != widget.staff.id)
                    TextButton.icon(onPressed: _assignToMe, icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: const Text('Assign to me')),
                ])),
              ]),
            ]),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Chief complaint'),
          const SizedBox(height: 9),
          SoftCard(child: Text(patient.chiefComplaint, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w700, fontSize: 15, height: 1.4))),
          const SizedBox(height: 20),
          const SectionTitle('Latest vitals'),
          const SizedBox(height: 9),
          Wrap(spacing: 9, runSpacing: 9, children: patient.vitals.entries.map((entry) => Container(
            width: 145,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: medqurLine), borderRadius: BorderRadius.circular(17)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.key, style: const TextStyle(color: Color(0xFF78869A), fontSize: 11)), const SizedBox(height: 4), Text(entry.value, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900, fontSize: 16))]),
          )).toList()),
          const SizedBox(height: 20),
          const SectionTitle('Allergies'),
          const SizedBox(height: 9),
          SoftCard(child: Wrap(spacing: 8, runSpacing: 8, children: patient.allergies.map((item) => StatusPill(label: item, color: item.toLowerCase().contains('no known') ? medqurGreen : medqurRed, icon: Icons.warning_amber_rounded)).toList())),
          const SizedBox(height: 20),
          SectionTitle('Medication orders', trailing: canOrder ? TextButton.icon(onPressed: _addOrder, icon: const Icon(Icons.add_rounded), label: const Text('Add')) : null),
          const SizedBox(height: 9),
          if (patient.medications.isEmpty)
            const SoftCard(child: Text('No active medication orders.'))
          else
            for (final medication in patient.medications)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      CircleAvatar(backgroundColor: (medication.administered ? medqurGreen : medqurBlue).withValues(alpha: .10), foregroundColor: medication.administered ? medqurGreen : medqurBlue, child: Icon(medication.administered ? Icons.check_rounded : Icons.medication_outlined)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${medication.name} • ${medication.dose}', style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('${medication.route} • ${medication.frequency}', style: const TextStyle(color: Color(0xFF65748A), fontSize: 12)),
                        const SizedBox(height: 3),
                        Text(medication.productCode == null ? 'Package code not mapped' : 'Package code mapped', style: TextStyle(color: medication.productCode == null ? medqurAmber : medqurGreen, fontSize: 11, fontWeight: FontWeight.w700)),
                      ])),
                      StatusPill(label: medication.administered ? 'Given' : 'Pending', color: medication.administered ? medqurGreen : medqurAmber),
                    ]),
                    if (canOrder && !medication.administered && medication.productCode == null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(onPressed: () => _mapMedicationCode(medication), icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text('Map package barcode')),
                    ],
                    if (canAdminister && !medication.administered) ...[
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(onPressed: () => _administer(medication), icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text('Scan wristband + medication')),
                    ],
                  ]),
                ),
              ),
          const SizedBox(height: 20),
          const SectionTitle('Encounter timeline'),
          const SizedBox(height: 9),
          SoftCard(child: Column(children: [
            for (var i = 0; i < patient.timeline.length; i++)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 5), child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: medqurBlue, shape: BoxShape.circle))),
                const SizedBox(width: 11),
                Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(patient.timeline[i], style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w600)))),
              ]),
          ])),
          const SizedBox(height: 16),
          const Text('Prototype only • Do not use for real patient identification or medication administration.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8793A4), fontSize: 11)),
        ],
      ),
    );
  }
}
