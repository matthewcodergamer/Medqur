import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'new_encounter_page.dart';
import 'orders_tasks_page.dart';
import 'patient_detail_page.dart';
import 'patient_queue_page.dart';
import 'profile_page.dart';
import 'scan_page.dart';

class ClinicalShell extends StatefulWidget {
  const ClinicalShell({
    super.key,
    required this.staff,
    required this.facility,
    required this.patients,
    required this.onEndShift,
  });

  final StaffProfile staff;
  final Facility facility;
  final List<Patient> patients;
  final VoidCallback onEndShift;

  @override
  State<ClinicalShell> createState() => _ClinicalShellState();
}

class _ClinicalShellState extends State<ClinicalShell> {
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

  void openPatient(Patient patient) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientDetailPage(
          staff: widget.staff,
          patient: patient,
          onChanged: () => setState(() {}),
        ),
      ),
    );
  }

  Future<void> newEncounter() async {
    final patient = await Navigator.of(context).push<Patient>(
      MaterialPageRoute(builder: (_) => const NewEncounterPage()),
    );
    if (patient == null || !mounted) return;
    setState(() => widget.patients.insert(0, patient));
    openPatient(patient);
  }

  Widget page() {
    switch (index) {
      case 0:
        return PatientQueuePage(
          staff: widget.staff,
          patients: widget.patients,
          onOpenPatient: openPatient,
          onNewEncounter: newEncounter,
        );
      case 1:
        return ScanPage(
          patient: widget.patients.first,
          onOpenPatient: openPatient,
        );
      case 2:
        return isDoctor
            ? OrdersPage(patients: widget.patients, onOpenPatient: openPatient)
            : NurseTasksPage(patients: widget.patients, onOpenPatient: openPatient);
      default:
        return ProfilePage(
          staff: widget.staff,
          facility: widget.facility,
          onEndShift: widget.onEndShift,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 920;
            return Row(
              children: [
                if (desktop) _desktopNavigation(),
                Expanded(
                  child: Column(
                    children: [
                      _topBar(desktop),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOutCubic,
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

  Widget _desktopNavigation() {
    return Container(
      width: 236,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: medqurLine)),
      ),
      child: Column(
        children: [
          const MedqurLogo(width: 150),
          const SizedBox(height: 34),
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: medqurSurface, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: medqurBlue.withValues(alpha: .12),
                  foregroundColor: medqurBlue,
                  child: Text(widget.staff.name.split(' ').last[0]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.staff.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: medqurInk),
                      ),
                      Text(widget.staff.title, style: const TextStyle(fontSize: 11, color: Color(0xFF748297))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(bool desktop) {
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 28 : 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: medqurLine)),
      ),
      child: Row(
        children: [
          if (!desktop) ...[
            const MedqurLogo(width: 112),
            const SizedBox(width: 12),
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
                  style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 2),
                const Text('Active shift • Demo workspace', style: TextStyle(color: Color(0xFF78869A), fontSize: 11)),
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
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}
