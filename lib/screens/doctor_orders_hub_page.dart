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
    required this.onCreatePrescription,
    required this.onCreateDiagnosticOrder,
    required this.onOpenDiagnosticOrder,
  });

  final StaffProfile staff;
  final List<Patient> patients;
  final List<DiagnosticOrder> diagnosticOrders;
  final ValueChanged<Patient> onOpenPatient;
  final VoidCallback onCreatePrescription;
  final VoidCallback onCreateDiagnosticOrder;
  final ValueChanged<DiagnosticOrder> onOpenDiagnosticOrder;

  @override
  Widget build(BuildContext context) {
    final medicationOrders = <_MedicationItem>[];
    for (final patient in patients) {
      for (final medication in patient.medications) {
        if (!medication.administered) {
          medicationOrders.add(_MedicationItem(patient, medication));
        }
      }
    }

    final activeDiagnostics = diagnosticOrders.where((order) => order.isOpen).toList()
      ..sort((a, b) => b.orderedAt.compareTo(a.orderedAt));
    final completedDiagnostics = diagnosticOrders
        .where((order) => order.status == DiagnosticOrderStatus.completed)
        .toList()
      ..sort((a, b) => (b.completedAt ?? b.orderedAt)
          .compareTo(a.completedAt ?? a.orderedAt));

    return MedqurPage(
      wide: true,
      children: [
        const MedqurPageHeader(
          eyebrow: 'Doctor workspace',
          title: 'Orders',
          subtitle: 'Prescriptions, investigations and results.',
        ),
        const SizedBox(height: 16),
        ResponsiveActions(
          minActionWidth: 190,
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
        const SizedBox(height: 22),
        SectionTitle(
          'Tests & procedures',
          trailing: StatusPill(
            label: '${activeDiagnostics.length} open',
            color: activeDiagnostics.isEmpty ? medqurGreen : medqurBlue,
          ),
        ),
        const SizedBox(height: 10),
        if (activeDiagnostics.isEmpty)
          const SoftCard(
            child: Text(
              'No open diagnostic orders.',
              style: TextStyle(color: Color(0xFF687587)),
            ),
          )
        else
          ResponsiveGrid(
            minItemWidth: 330,
            maxColumns: 2,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final order in activeDiagnostics)
                _DiagnosticCard(
                  order: order,
                  onTap: () => onOpenDiagnosticOrder(order),
                ),
            ],
          ),
        const SizedBox(height: 20),
        SectionTitle(
          'Medication orders',
          trailing: StatusPill(
            label: '${medicationOrders.length} active',
            color: medicationOrders.isEmpty ? medqurGreen : medqurAmber,
          ),
        ),
        const SizedBox(height: 10),
        if (medicationOrders.isEmpty)
          const SoftCard(
            child: Text(
              'No active medication orders.',
              style: TextStyle(color: Color(0xFF687587)),
            ),
          )
        else
          ResponsiveGrid(
            minItemWidth: 330,
            maxColumns: 2,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in medicationOrders)
                _MedicationCard(
                  item: item,
                  onTap: () => onOpenPatient(item.patient),
                ),
            ],
          ),
        if (completedDiagnostics.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionTitle(
            'Recent results',
            trailing: StatusPill(
              label: '${completedDiagnostics.length}',
              color: medqurGreen,
            ),
          ),
          const SizedBox(height: 10),
          ResponsiveGrid(
            minItemWidth: 330,
            maxColumns: 2,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final order in completedDiagnostics.take(6))
                _DiagnosticCard(
                  order: order,
                  onTap: () => onOpenDiagnosticOrder(order),
                ),
            ],
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
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.medication_outlined, color: medqurBlue, size: 21),
            const SizedBox(width: 11),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.medication.name} ${item.medication.dose}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF687587),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${item.medication.route} • ${item.medication.frequency}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7B8796),
                      fontSize: 10.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9AA4B1),
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
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 315;
            final status = StatusPill(
              label: order.status.label,
              color: order.status == DiagnosticOrderStatus.completed
                  ? medqurGreen
                  : medqurBlue,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: medqurBlue.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(_icon(order.type), color: medqurBlue, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (narrow) ...[
                        Text(
                          order.studyName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: medqurInk,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        status,
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.studyName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: medqurInk,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            status,
                          ],
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${order.assignedDiscipline.label} • ${order.priority.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF748094),
                          fontSize: 10.5,
                        ),
                      ),
                      if (order.status == DiagnosticOrderStatus.completed &&
                          order.resultSummary.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          order.resultSummary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF536274),
                            fontSize: 10.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
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
