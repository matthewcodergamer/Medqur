import 'package:flutter/material.dart';

import '../clinical_models.dart';
import '../models.dart';
import '../services/clinical_order_store.dart';
import '../widgets/common.dart';
import 'clinical_order_composer_page.dart';
import 'clinical_order_detail_page.dart';
import 'clinical_worklist_page.dart';
import 'doctor_orders_hub_page.dart';
import 'home_dashboard_page.dart';
import 'new_encounter_page_v2.dart';
import 'patient_detail_page_v2.dart';
import 'patient_queue_page.dart';
import 'pharmacy_page.dart';
import 'prescription_composer_page.dart';
import 'profile_page_v2.dart';
import 'scan_page_v2.dart';

/// Role-aware clinical shell introduced from the workforce/worklist voice-note
/// update. Doctors own prescriptions and investigations; clinical-support staff
/// receive routed work; pharmacy remains isolated to prescription fulfilment.
class ClinicalShellV3 extends StatefulWidget {
  const ClinicalShellV3({
    super.key,
    required this.staff,
    required this.facility,
    required this.patients,
    required this.onPatientsChanged,
    required this.onEndShift,
  });

  final StaffProfile staff;
  final Facility facility;
  final List<Patient> patients;
  final Future<void> Function() onPatientsChanged;
  final VoidCallback onEndShift;

  @override
  State<ClinicalShellV3> createState() => _ClinicalShellV3State();
}

class _ClinicalShellV3State extends State<ClinicalShellV3> {
  int _index = 0;
  final _orderStore = const ClinicalOrderStore();
  List<DiagnosticOrder> _orders = <DiagnosticOrder>[];
  bool _ordersLoaded = false;

  bool get _doctor => widget.staff.role == StaffRole.doctor;
  bool get _pharmacy => widget.staff.role == StaffRole.pharmacist;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final orders = await _orderStore.load();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _ordersLoaded = true;
    });
  }

  Future<void> _saveOrders() async {
    await _orderStore.save(_orders);
    if (mounted) setState(() {});
  }

  void _patientChanged() {
    if (mounted) setState(() {});
    widget.onPatientsChanged();
  }

  void _openPatient(Patient patient) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientDetailPageV2(
          staff: widget.staff,
          patient: patient,
          onChanged: _patientChanged,
        ),
      ),
    );
  }

  Future<void> _newEncounter() async {
    if (_pharmacy) return;
    final discipline = widget.staff.clinicalDiscipline;
    if (!_doctor &&
        discipline != ClinicalDiscipline.nursing &&
        discipline != ClinicalDiscipline.triage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient registration is limited to authorized clinical intake staff.'),
        ),
      );
      return;
    }
    final patient = await Navigator.of(context).push<Patient>(
      MaterialPageRoute(
        builder: (_) => NewEncounterPageV2(
          facility: widget.facility,
          existingPatients: widget.patients,
        ),
      ),
    );
    if (patient == null || !mounted) return;
    widget.patients.insert(0, patient);
    await widget.onPatientsChanged();
    if (mounted) _openPatient(patient);
  }

  Future<Patient?> _choosePatient(String title, String description) {
    if (widget.patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Register or select a patient first.')),
      );
      return Future.value(null);
    }
    return showModalBottomSheet<Patient>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: medqurInk,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 4),
                    Text(description,
                        style: const TextStyle(
                          color: Color(0xFF718095),
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.patients.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final patient = widget.patients[index];
                    return ListTile(
                      title: Text(patient.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${patient.age} • ${patient.sex} • ${patient.effectiveEncounterId}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(sheetContext, patient),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _newPrescription() async {
    if (!_doctor) return;
    final patient = await _choosePatient(
      'New prescription',
      'Choose the patient encounter to prescribe medication.',
    );
    if (patient == null || !mounted) return;
    final order = await Navigator.of(context).push<MedicationOrder>(
      MaterialPageRoute(
        builder: (_) => PrescriptionComposerPage(
          staff: widget.staff,
          patient: patient,
          facility: widget.facility,
        ),
      ),
    );
    if (order == null || !mounted) return;
    patient.medications.add(order);
    patient.status = PatientStatus.treatment;
    patient.timeline.add(
      '${TimeOfDay.now().format(context)} — ${order.name} ${order.dose} prescribed by ${widget.staff.name}',
    );
    await widget.onPatientsChanged();
    if (mounted) setState(() {});
  }

  Future<void> _newDiagnostic() async {
    if (!_doctor) return;
    final patient = await _choosePatient(
      'New test / procedure',
      'Choose the patient encounter, then route the order to the performing team.',
    );
    if (patient == null || !mounted) return;
    final order = await Navigator.of(context).push<DiagnosticOrder>(
      MaterialPageRoute(
        builder: (_) => ClinicalOrderComposerPage(
          staff: widget.staff,
          patient: patient,
          facility: widget.facility,
        ),
      ),
    );
    if (order == null || !mounted) return;
    _orders.insert(0, order);
    patient.timeline.add(
      '${TimeOfDay.now().format(context)} — ${order.studyName} ordered by ${widget.staff.name}',
    );
    await _saveOrders();
    await widget.onPatientsChanged();
  }

  void _openOrder(DiagnosticOrder order) {
    Patient? patient;
    for (final item in widget.patients) {
      if (item.id == order.patientId) {
        patient = item;
        break;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClinicalOrderDetailPage(
          staff: widget.staff,
          order: order,
          patient: patient,
          onChanged: () {
            _saveOrders();
            if (patient != null) widget.onPatientsChanged();
          },
        ),
      ),
    );
  }

  String get _workLabel => _doctor
      ? 'Orders'
      : _pharmacy
          ? 'Pharmacy'
          : 'Worklist';

  Widget _page() {
    if (!_ordersLoaded && _index == 3 && !_pharmacy) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return switch (_index) {
      0 => HomeDashboardPage(
          staff: widget.staff,
          facility: widget.facility,
          patients: widget.patients,
          onPatients: () => setState(() => _index = 1),
          onScan: () => setState(() => _index = 2),
          onMedications: () => setState(() => _index = 3),
        ),
      1 => PatientQueuePage(
          staff: widget.staff,
          patients: widget.patients,
          onOpenPatient: _openPatient,
          onNewEncounter: _newEncounter,
        ),
      2 => ScanPageV2(
          patients: widget.patients,
          onOpenPatient: _openPatient,
        ),
      3 => _doctor
          ? DoctorOrdersHubPage(
              staff: widget.staff,
              patients: widget.patients,
              diagnosticOrders: _orders
                  .where((order) => order.facilityId == widget.facility.id)
                  .toList(),
              onOpenPatient: _openPatient,
              onCreatePrescription: _newPrescription,
              onCreateDiagnosticOrder: _newDiagnostic,
              onOpenDiagnosticOrder: _openOrder,
            )
          : _pharmacy
              ? PharmacyPage(staff: widget.staff, facility: widget.facility)
              : ClinicalWorklistPage(
                  staff: widget.staff,
                  patients: widget.patients,
                  orders: _orders
                      .where((order) => order.facilityId == widget.facility.id)
                      .toList(),
                  onOpenPatient: _openPatient,
                  onOpenOrder: _openOrder,
                ),
      _ => ProfilePageV2(
          staff: widget.staff,
          facility: widget.facility,
          onEndShift: widget.onEndShift,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 980;
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.people_alt_outlined),
        selectedIcon: Icon(Icons.people_alt_rounded),
        label: 'Patients',
      ),
      const NavigationDestination(
        icon: Icon(Icons.qr_code_scanner_rounded),
        label: 'Scan',
      ),
      NavigationDestination(
        icon: Icon(_doctor
            ? Icons.assignment_outlined
            : _pharmacy
                ? Icons.local_pharmacy_outlined
                : Icons.task_outlined),
        selectedIcon: Icon(_doctor
            ? Icons.assignment_rounded
            : _pharmacy
                ? Icons.local_pharmacy_rounded
                : Icons.task_rounded),
        label: _workLabel,
      ),
      const NavigationDestination(
        icon: Icon(Icons.badge_outlined),
        selectedIcon: Icon(Icons.badge_rounded),
        label: 'Profile',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Row(
                children: [
                  if (desktop)
                    NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (value) =>
                          setState(() => _index = value),
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final item in destinations)
                          NavigationRailDestination(
                            icon: item.icon,
                            selectedIcon: item.selectedIcon,
                            label: Text(item.label),
                          ),
                      ],
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: KeyedSubtree(
                        key: ValueKey(_index),
                        child: _page(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: destinations,
            ),
    );
  }

  Widget _topBar() => Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: medqurLine)),
        ),
        child: Row(
          children: [
            const MedqurLogo(width: 96),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.facility.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: medqurInk,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.staff.workforceLabel} • ${widget.staff.clinicalDiscipline.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF78869A),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
