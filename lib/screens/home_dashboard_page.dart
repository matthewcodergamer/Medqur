import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({
    super.key,
    required this.staff,
    required this.facility,
    required this.patients,
    required this.onPatients,
    required this.onScan,
    required this.onMedications,
  });

  final StaffProfile staff;
  final Facility facility;
  final List<Patient> patients;
  final VoidCallback onPatients;
  final VoidCallback onScan;
  final VoidCallback onMedications;

  @override
  Widget build(BuildContext context) {
    final waiting = patients.where((p) => p.status == PatientStatus.waiting || p.status == PatientStatus.triaged).length;
    final priority = patients.where((p) => p.triage == TriageLevel.critical || p.triage == TriageLevel.urgent).length;
    final pendingMeds = patients.fold<int>(
      0,
      (sum, patient) => sum + patient.medications.where((m) => !m.administered).length,
    );
    final p1 = patients.where((p) => p.triage == TriageLevel.critical).length;
    final p2 = patients.where((p) => p.triage == TriageLevel.urgent).length;
    final p3 = patients.where((p) => p.triage == TriageLevel.moderate).length;
    final p4 = patients.where((p) => p.triage == TriageLevel.routine).length;

    return MedqurPage(
      children: [
        MedqurPageHeader(
          eyebrow: '${staff.title} • active shift',
          title: _greeting(staff.name),
          subtitle: '${facility.name} • ${facility.classification.shortLabel}',
          trailing: const StatusPill(
            label: 'Online',
            color: medqurGreen,
            icon: Icons.cloud_done_outlined,
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 680 ? 3 : 3;
            final childWidth = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(width: childWidth, child: MedqurMetric(value: '${patients.length}', label: 'Patients')),
                SizedBox(width: childWidth, child: MedqurMetric(value: '$priority', label: 'Priority', color: priority > 0 ? medqurRed : medqurGreen)),
                SizedBox(width: childWidth, child: MedqurMetric(value: '$pendingMeds', label: staff.role == StaffRole.doctor ? 'Orders' : 'Medication tasks', color: pendingMeds > 0 ? medqurAmber : medqurGreen)),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const SectionTitle('Workspace'),
        const SizedBox(height: 10),
        MedqurActionCard(
          icon: Icons.people_alt_outlined,
          title: 'Patients',
          subtitle: '$waiting waiting or triaged • review the live clinical queue',
          badge: waiting == 0 ? null : '$waiting',
          onTap: onPatients,
        ),
        const SizedBox(height: 10),
        MedqurActionCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Scan',
          subtitle: 'Patient wristband, NIDS / NIC, medication or staff credential',
          onTap: onScan,
        ),
        const SizedBox(height: 10),
        MedqurActionCard(
          icon: Icons.medication_outlined,
          title: staff.role == StaffRole.pharmacist
              ? 'Pharmacy'
              : staff.role == StaffRole.doctor
                  ? 'Medications & prescriptions'
                  : 'Medication tasks',
          subtitle: staff.role == StaffRole.pharmacist
              ? 'Inventory, receiving, verification, dispensing and recalls'
              : staff.role == StaffRole.doctor
                  ? 'Search medicines, create and sign prescriptions, review orders'
                  : 'Review due doses and closed-loop administration tasks',
          badge: pendingMeds == 0 ? null : '$pendingMeds',
          onTap: onMedications,
          accent: const Color(0xFF4A68D8),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCE7FB)),
          ),
          child: Row(
            children: [
              const CapsuleIllustration(width: 112),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Medication safety',
                      style: TextStyle(color: medqurInk, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      staff.role == StaffRole.doctor
                          ? 'Prescriptions are structured, signed and linked to the patient encounter.'
                          : 'Scan the patient and medication before administration.',
                      style: const TextStyle(color: Color(0xFF647286), fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Emergency priority'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _PriorityTile(code: 'P1', count: p1, color: triageColor(TriageLevel.critical))),
            const SizedBox(width: 8),
            Expanded(child: _PriorityTile(code: 'P2', count: p2, color: triageColor(TriageLevel.urgent))),
            const SizedBox(width: 8),
            Expanded(child: _PriorityTile(code: 'P3', count: p3, color: triageColor(TriageLevel.moderate))),
            const SizedBox(width: 8),
            Expanded(child: _PriorityTile(code: 'P4', count: p4, color: triageColor(TriageLevel.routine))),
          ],
        ),
      ],
    );
  }

  String _greeting(String name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
    final display = name.trim().isEmpty ? 'clinician' : name;
    return '$greeting, $display';
  }
}

class _PriorityTile extends StatelessWidget {
  const _PriorityTile({required this.code, required this.count, required this.color});
  final String code;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: medqurLine),
        ),
        child: Column(
          children: [
            Text(code, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 2),
            Text('$count', style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
      );
}
