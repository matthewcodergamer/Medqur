import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
import '../widgets/medqur_responsive.dart';

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
    final waiting = patients
        .where((p) =>
            p.status == PatientStatus.waiting ||
            p.status == PatientStatus.triaged)
        .length;
    final priority = patients
        .where((p) =>
            p.triage == TriageLevel.critical ||
            p.triage == TriageLevel.urgent)
        .length;
    final pendingMeds = patients.fold<int>(
      0,
      (sum, patient) =>
          sum + patient.medications.where((m) => !m.administered).length,
    );
    final p1 =
        patients.where((p) => p.triage == TriageLevel.critical).length;
    final p2 = patients.where((p) => p.triage == TriageLevel.urgent).length;
    final p3 =
        patients.where((p) => p.triage == TriageLevel.moderate).length;
    final p4 = patients.where((p) => p.triage == TriageLevel.routine).length;

    return MedqurPage(
      wide: true,
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
        const SizedBox(height: 18),
        ResponsiveGrid(
          minItemWidth: 145,
          maxColumns: 3,
          spacing: 10,
          children: [
            MedqurMetric(value: '${patients.length}', label: 'Patients'),
            MedqurMetric(
              value: '$priority',
              label: 'Priority',
              color: priority > 0 ? medqurRed : medqurGreen,
            ),
            MedqurMetric(
              value: '$pendingMeds',
              label: staff.role == StaffRole.doctor
                  ? 'Orders'
                  : 'Medication tasks',
              color: pendingMeds > 0 ? medqurAmber : medqurGreen,
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionTitle('Workspace'),
        const SizedBox(height: 10),
        ResponsiveGrid(
          minItemWidth: 245,
          maxColumns: 3,
          spacing: 10,
          runSpacing: 10,
          children: [
            MedqurActionCard(
              icon: Icons.people_alt_outlined,
              title: 'Patients',
              subtitle: '$waiting waiting or triaged',
              badge: waiting == 0 ? null : '$waiting',
              onTap: onPatients,
            ),
            MedqurActionCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan',
              subtitle: 'Patient, ID, medication or staff code',
              onTap: onScan,
            ),
            MedqurActionCard(
              icon: Icons.medication_outlined,
              title: staff.role == StaffRole.pharmacist
                  ? 'Pharmacy'
                  : staff.role == StaffRole.doctor
                      ? 'Prescriptions'
                      : 'Medication tasks',
              subtitle: staff.role == StaffRole.pharmacist
                  ? 'Inventory, dispensing and recalls'
                  : staff.role == StaffRole.doctor
                      ? 'Create, sign and review medication orders'
                      : 'Review due doses and scan to administer',
              badge: pendingMeds == 0 ? null : '$pendingMeds',
              onTap: onMedications,
              accent: const Color(0xFF4A68D8),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final tiny = constraints.maxWidth < 390;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Medication safety',
                  style: TextStyle(
                    color: medqurInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                CompactHelperText(
                  staff.role == StaffRole.doctor
                      ? 'Structured prescriptions stay linked to the patient encounter.'
                      : 'Scan the patient and medication before administration.',
                  maxLinesPhone: 2,
                ),
              ],
            );
            return Container(
              padding: EdgeInsets.all(tiny ? 14 : 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDCE7FB)),
              ),
              child: tiny
                  ? content
                  : Row(
                      children: [
                        const CapsuleIllustration(width: 88),
                        const SizedBox(width: 8),
                        Expanded(child: content),
                      ],
                    ),
            );
          },
        ),
        const SizedBox(height: 22),
        const SectionTitle('Emergency priority'),
        const SizedBox(height: 10),
        ResponsiveGrid(
          minItemWidth: 110,
          maxColumns: 4,
          spacing: 8,
          runSpacing: 8,
          children: [
            _PriorityTile(
              code: 'P1',
              count: p1,
              color: triageColor(TriageLevel.critical),
            ),
            _PriorityTile(
              code: 'P2',
              count: p2,
              color: triageColor(TriageLevel.urgent),
            ),
            _PriorityTile(
              code: 'P3',
              count: p3,
              color: triageColor(TriageLevel.moderate),
            ),
            _PriorityTile(
              code: 'P4',
              count: p4,
              color: triageColor(TriageLevel.routine),
            ),
          ],
        ),
      ],
    );
  }

  String _greeting(String name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final display = name.trim().isEmpty ? 'clinician' : name;
    return '$greeting, $display';
  }
}

class _PriorityTile extends StatelessWidget {
  const _PriorityTile({
    required this.code,
    required this.count,
    required this.color,
  });
  final String code;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: medqurLine),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              code,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: const TextStyle(
                color: medqurInk,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
}
