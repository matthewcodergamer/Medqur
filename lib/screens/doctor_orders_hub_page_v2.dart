import 'package:flutter/material.dart';

import '../clinical_models.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
import '../widgets/medqur_responsive.dart';

class DoctorOrdersHubPage extends StatelessWidget {
  const DoctorOrdersHubPage({
    super.key,
    required this.staff,
    required this.patients,
    required this.diagnosticOrders,
    required this.onOpenPatient,
    required this.onOpenMedicationOrder,
    required this.onCreatePrescription,
    required this.onCreateDiagnosticOrder,
    required this.onOpenDiagnosticOrder,
  });

  final StaffProfile staff;
  final List<Patient> patients;
  final List<DiagnosticOrder> diagnosticOrders;
  final ValueChanged<Patient> onOpenPatient;
  final void Function(Patient patient, MedicationOrder order)
      onOpenMedicationOrder;
  final VoidCallback onCreatePrescription;
  final VoidCallback onCreateDiagnosticOrder;
  final ValueChanged<DiagnosticOrder> onOpenDiagnosticOrder;

  @override
  Widget build(BuildContext context) {
    final medications = <_MedicationItem>[];
    for (final patient in patients) {
      for (final medication in patient.medications) {
        if (!medication.administered) {
          medications.add(_MedicationItem(patient, medication));
        }
      }
    }

    final activeDiagnostics =
        diagnosticOrders.where((order) => order.isOpen).toList()
          ..sort((a, b) => b.orderedAt.compareTo(a.orderedAt));
    final completedDiagnostics = diagnosticOrders
        .where((order) => order.status == DiagnosticOrderStatus.completed)
        .toList()
      ..sort((a, b) => (b.completedAt ?? b.orderedAt)
          .compareTo(a.completedAt ?? a.orderedAt));

    return MedqurPage(
      children: [
        const MedqurPageHeader(
          eyebrow: 'Doctor workspace',
          title: 'Orders',
          subtitle: 'Open, review and update signed patient orders.',
        ),
        const SizedBox(height: 15),
        ResponsiveActions(
          children: [
            FilledButton.icon(
              onPressed: onCreatePrescription,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Prescription'),
            ),
            OutlinedButton.icon(
              onPressed: onCreateDiagnosticOrder,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Test / procedure'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionTitle(
          'Medication orders',
          trailing: StatusPill(
            label: '${medications.length} active',
            color: medications.isEmpty ? medqurGreen : medqurBlue,
          ),
        ),
        const SizedBox(height: 8),
        if (medications.isEmpty)
          const SoftCard(
            padding: EdgeInsets.all(13),
            child: Text(
              'No active medication orders.',
              style: TextStyle(color: Color(0xFF687587), fontSize: 12),
            ),
          )
        else
          for (final item in medications)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MedicationCard(
                item: item,
                onTap: () =>
                    onOpenMedicationOrder(item.patient, item.medication),
              ),
            ),
        const SizedBox(height: 18),
        SectionTitle(
          'Tests & procedures',
          trailing: StatusPill(
            label: '${activeDiagnostics.length} open',
            color: activeDiagnostics.isEmpty ? medqurGreen : medqurBlue,
          ),
        ),
        const SizedBox(height: 8),
        if (activeDiagnostics.isEmpty)
          const SoftCard(
            padding: EdgeInsets.all(13),
            child: Text(
              'No open diagnostic orders.',
              style: TextStyle(color: Color(0xFF687587), fontSize: 12),
            ),
          )
        else
          for (final order in activeDiagnostics)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DiagnosticCard(
                order: order,
                onTap: () => onOpenDiagnosticOrder(order),
              ),
            ),
        if (completedDiagnostics.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionTitle('Recent results'),
          const SizedBox(height: 8),
          for (final order in completedDiagnostics.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DiagnosticCard(
                order: order,
                onTap: () => onOpenDiagnosticOrder(order),
              ),
            ),
        ],
      ],
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.item, required this.onTap});

  final _MedicationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: medqurBlue.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.medication_outlined,
                color: medqurBlue,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.patient.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: medqurInk,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.medication.name} ${item.medication.dose} • ${item.medication.frequency}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF687587),
                      fontSize: 10.75,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9AA4B1),
              size: 19,
            ),
          ],
        ),
      );
}

class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({required this.order, required this.onTap});

  final DiagnosticOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: medqurBlue.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon(order.type), color: medqurBlue, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.studyName,
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
                    '${order.patientId} • ${order.assignedDiscipline.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF748094),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            StatusPill(
              label: order.status.label,
              color: order.status == DiagnosticOrderStatus.completed
                  ? medqurGreen
                  : medqurBlue,
            ),
          ],
        ),
      );

  IconData _icon(DiagnosticOrderType type) => switch (type) {
        DiagnosticOrderType.xray ||
        DiagnosticOrderType.ctScan ||
        DiagnosticOrderType.mri ||
        DiagnosticOrderType.ultrasound => Icons.image_outlined,
        DiagnosticOrderType.laboratory => Icons.science_outlined,
        DiagnosticOrderType.ecg => Icons.monitor_heart_outlined,
        DiagnosticOrderType.respiratory => Icons.air_rounded,
        DiagnosticOrderType.other => Icons.assignment_outlined,
      };
}

class _MedicationItem {
  const _MedicationItem(this.patient, this.medication);
  final Patient patient;
  final MedicationOrder medication;
}
