import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';
import 'home_dashboard_page.dart';
import 'new_encounter_page_v2.dart';
import 'orders_tasks_page.dart';
import 'patient_detail_page_v2.dart';
import 'patient_queue_page.dart';
import 'pharmacy_page.dart';
import 'prescription_composer_page.dart';
import 'profile_page_v2.dart';
import 'scan_page_v2.dart';

class ClinicalShellV2 extends StatefulWidget {
  const ClinicalShellV2({
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
  State<ClinicalShellV2> createState() => _ClinicalShellV2State();
}

class _ClinicalShellV2State extends State<ClinicalShellV2> {
  int index = 0;

  bool get isDoctor => widget.staff.role == StaffRole.doctor;
  bool get isPharmacist => widget.staff.role == StaffRole.pharmacist;

  List<_NavItem> get items => const [
        _NavItem('Home', Icons.home_outlined, Icons.home_rounded),
        _NavItem('Patients', Icons.people_alt_outlined, Icons.people_alt_rounded),
        _NavItem('Scan', Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_rounded),
        _NavItem('Medications', Icons.medication_outlined, Icons.medication_rounded),
        _NavItem('Profile', Icons.badge_outlined, Icons.badge_rounded),
      ];

  void _patientChanged() {
    if (mounted) setState(() {});
    widget.onPatientsChanged();
  }

  void openPatient(Patient patient) {
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

  Future<void> newEncounter() async {
    if (isPharmacist) return;
    final patient = await Navigator.of(context).push<Patient>(
      MaterialPageRoute(
        builder: (_) => NewEncounterPageV2(
          facility: widget.facility,
          existingPatients: widget.patients,
        ),
      ),
    );
    if (patient == null || !mounted) return;
    setState(() => widget.patients.insert(0, patient));
    await widget.onPatientsChanged();
    if (mounted) openPatient(patient);
  }

  Future<void> newPrescription() async {
    if (!isDoctor) return;
    if (widget.patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Register or select a patient before creating a prescription.')),
      );
      return;
    }

    final patient = await showModalBottomSheet<Patient>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'New prescription',
                  style: TextStyle(color: medqurInk, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Choose the patient encounter. Patient identity and allergies stay visible while you prescribe.',
                  style: TextStyle(color: Color(0xFF718095), fontSize: 12.5, height: 1.35),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: widget.patients.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final patient = widget.patients[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: triageColor(patient.triage).withValues(alpha: .10),
                          foregroundColor: triageColor(patient.triage),
                          child: Text(
                            triageCode(patient.triage),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ),
                        title: Text(patient.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${patient.age} • ${patient.sex} • ${patient.effectiveEncounterId}'),
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
      ),
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
      '${TimeOfDay.now().format(context)} — ${order.name} ${order.dose} prescription sent by ${widget.staff.name}',
    );
    await widget.onPatientsChanged();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prescription signed and added to the patient medication workflow.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget page() => switch (index) {
        0 => HomeDashboardPage(
            staff: widget.staff,
            facility: widget.facility,
            patients: widget.patients,
            onPatients: () => setState(() => index = 1),
            onScan: () => setState(() => index = 2),
            onMedications: () => setState(() => index = 3),
          ),
        1 => PatientQueuePage(
            staff: widget.staff,
            patients: widget.patients,
            onOpenPatient: openPatient,
            onNewEncounter: newEncounter,
          ),
        2 => ScanPageV2(patients: widget.patients, onOpenPatient: openPatient),
        3 => isDoctor
            ? OrdersPage(
                staff: widget.staff,
                patients: widget.patients,
                onOpenPatient: openPatient,
                onCreatePrescription: newPrescription,
              )
            : isPharmacist
                ? PharmacyPage(staff: widget.staff, facility: widget.facility)
                : NurseTasksPage(patients: widget.patients, onOpenPatient: openPatient),
        _ => ProfilePageV2(
            staff: widget.staff,
            facility: widget.facility,
            onEndShift: widget.onEndShift,
          ),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 980;
            return Row(
              children: [
                if (desktop) _desktopNavigation(),
                Expanded(
                  child: Column(
                    children: [
                      _topBar(desktop),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 210),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                          child: KeyedSubtree(key: ValueKey(index), child: page()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 980
          ? NavigationBar(
              height: 68,
              selectedIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              destinations: [
                for (final item in items)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
              ],
            )
          : null,
    );
  }

  Widget _desktopNavigation() => Container(
        width: 248,
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: medqurLine)),
        ),
        child: Column(
          children: [
            const Align(alignment: Alignment.centerLeft, child: MedqurLogo(width: 144)),
            const SizedBox(height: 28),
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: ListTile(
                  selected: index == i,
                  selectedTileColor: const Color(0xFFEDF3FF),
                  selectedColor: medqurBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Icon(index == i ? items[i].selectedIcon : items[i].icon),
                  title: Text(items[i].label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => setState(() => index = i),
                ),
              ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: medqurLine),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: medqurBlue.withValues(alpha: .10),
                    foregroundColor: medqurBlue,
                    child: Text(widget.staff.name.isEmpty ? '?' : widget.staff.name[0], style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.staff.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(widget.staff.title, style: const TextStyle(color: Color(0xFF8793A4), fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _topBar(bool desktop) {
    final compact = !desktop && MediaQuery.sizeOf(context).width < 430;
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 28 : 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: medqurLine)),
      ),
      child: Row(
        children: [
          if (!desktop) ...[
            MedqurLogo(width: compact ? 92 : 102),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: desktop ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Text(
                  widget.facility.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: medqurGreen, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Active shift • ${widget.facility.classification.shortLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF78869A), fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (desktop) ...[
            const SizedBox(width: 14),
            const StatusPill(label: 'Secure session', color: medqurGreen, icon: Icons.lock_rounded),
          ],
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
