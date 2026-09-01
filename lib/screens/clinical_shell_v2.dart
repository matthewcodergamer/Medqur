import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'new_encounter_page_v2.dart';
import 'orders_tasks_page.dart';
import 'patient_detail_page_v2.dart';
import 'patient_queue_page.dart';
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

  List<_NavItem> get items => [
        const _NavItem('Patients', Icons.people_alt_outlined),
        const _NavItem('Scan', Icons.qr_code_scanner_rounded),
        _NavItem(
          isDoctor ? 'Orders' : 'Tasks',
          isDoctor ? Icons.receipt_long_outlined : Icons.medical_services_outlined,
        ),
        const _NavItem('Profile', Icons.badge_outlined),
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
    final patient = await Navigator.of(context).push<Patient>(
      MaterialPageRoute(builder: (_) => const NewEncounterPageV2()),
    );
    if (patient == null || !mounted) return;
    setState(() => widget.patients.insert(0, patient));
    await widget.onPatientsChanged();
    if (mounted) openPatient(patient);
  }

  Widget page() => switch (index) {
        0 => PatientQueuePage(
            staff: widget.staff,
            patients: widget.patients,
            onOpenPatient: openPatient,
            onNewEncounter: newEncounter,
          ),
        1 => ScanPageV2(patients: widget.patients, onOpenPatient: openPatient),
        2 => isDoctor
            ? OrdersPage(patients: widget.patients, onOpenPatient: openPatient)
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
        child: LayoutBuilder(builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 920;
          return Row(children: [
            if (desktop) _desktopNavigation(),
            Expanded(
              child: Column(children: [
                _topBar(desktop),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    child: KeyedSubtree(key: ValueKey(index), child: page()),
                  ),
                ),
              ]),
            ),
          ]);
        }),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 920
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              destinations: [
                for (final item in items)
                  NavigationDestination(icon: Icon(item.icon), label: item.label),
              ],
            )
          : null,
    );
  }

  Widget _desktopNavigation() => Container(
        width: 236,
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: medqurLine)),
        ),
        child: Column(children: [
          const MedqurLogo(width: 150),
          const SizedBox(height: 30),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                selected: index == i,
                selectedTileColor: const Color(0xFFEAF2FF),
                selectedColor: medqurBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                leading: Icon(items[i].icon),
                title: Text(items[i].label, style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => setState(() => index = i),
              ),
            ),
          const Spacer(),
          Text(
            widget.staff.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(widget.staff.title, style: const TextStyle(color: Color(0xFF8793A4), fontSize: 11)),
        ]),
      );

  Widget _topBar(bool desktop) => Container(
        height: 70,
        padding: EdgeInsets.symmetric(horizontal: desktop ? 28 : 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: medqurLine)),
        ),
        child: Row(children: [
          if (!desktop) ...[const MedqurLogo(width: 108), const SizedBox(width: 10)],
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
                Text(
                  'Active shift • V0.4 • ${widget.facility.classification.shortLabel} • P1–P4 triage',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF78869A), fontSize: 11),
                ),
              ],
            ),
          ),
          if (desktop) ...[
            const SizedBox(width: 14),
            const StatusPill(label: 'Device session', color: medqurGreen, icon: Icons.lock_rounded),
          ],
        ]),
      );
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}
