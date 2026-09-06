import 'package:flutter/material.dart';

import '../clinical_models.dart';
import '../models.dart';
import '../services/access_policy.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
import '../widgets/medqur_responsive.dart';

class ClinicalWorklistPage extends StatelessWidget {
  const ClinicalWorklistPage({
    super.key,
    required this.staff,
    required this.patients,
    required this.orders,
    required this.onOpenPatient,
    required this.onOpenOrder,
  });

  final StaffProfile staff;
  final List<Patient> patients;
  final List<DiagnosticOrder> orders;
  final ValueChanged<Patient> onOpenPatient;
  final ValueChanged<DiagnosticOrder> onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final medicationTasks = <_MedicationTask>[];
    if (staff.clinicalDiscipline == ClinicalDiscipline.nursing ||
        staff.clinicalDiscipline == ClinicalDiscipline.triage) {
      for (final patient in patients) {
        for (final medication in patient.medications) {
          if (!medication.administered) {
            medicationTasks.add(_MedicationTask(patient, medication));
          }
        }
      }
    }

    final openOrders = orders.where((order) => order.isOpen).toList()
      ..sort((a, b) {
        final rank = _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
        if (rank != 0) return rank;
        return a.orderedAt.compareTo(b.orderedAt);
      });

    return MedqurPage(
      wide: true,
      children: [
        MedqurPageHeader(
          eyebrow: 'Clinical support',
          title: 'Worklist',
          subtitle: staff.clinicalDiscipline.label,
          trailing: StatusPill(
            label: '${medicationTasks.length + openOrders.length} open',
            color: medicationTasks.isEmpty && openOrders.isEmpty
                ? medqurGreen
                : medqurAmber,
          ),
        ),
        const SizedBox(height: 18),
        if (medicationTasks.isNotEmpty) ...[
          const SectionTitle('Medication administration'),
          const SizedBox(height: 10),
          ResponsiveGrid(
            minItemWidth: 320,
            maxColumns: 2,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final task in medicationTasks)
                _MedicationTaskCard(
                  task: task,
                  onTap: () => onOpenPatient(task.patient),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        const SectionTitle('Tests & procedures'),
        const SizedBox(height: 10),
        if (openOrders.isEmpty)
          const SoftCard(
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: medqurGreen),
                SizedBox(width: 10),
                Expanded(child: Text('No open clinical-support orders.')),
              ],
            ),
          )
        else
          ResponsiveGrid(
            minItemWidth: 330,
            maxColumns: 2,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final order in openOrders)
                _OrderCard(
                  order: order,
                  staff: staff,
                  icon: _orderIcon(order.type),
                  onTap: () => onOpenOrder(order),
                ),
            ],
          ),
      ],
    );
  }

  Widget _orderIcon(DiagnosticOrderType type) {
    final icon = switch (type) {
      DiagnosticOrderType.xray ||
      DiagnosticOrderType.ctScan ||
      DiagnosticOrderType.mri ||
      DiagnosticOrderType.ultrasound => Icons.image_outlined,
      DiagnosticOrderType.laboratory => Icons.science_outlined,
      DiagnosticOrderType.ecg => Icons.monitor_heart_outlined,
      DiagnosticOrderType.respiratory => Icons.air_rounded,
      DiagnosticOrderType.other => Icons.assignment_outlined,
    };
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: medqurBlue.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: medqurBlue, size: 20),
    );
  }

  int _priorityRank(DiagnosticOrderPriority priority) => switch (priority) {
        DiagnosticOrderPriority.routine => 1,
        DiagnosticOrderPriority.urgent => 2,
        DiagnosticOrderPriority.stat => 3,
      };
}

class _MedicationTaskCard extends StatelessWidget {
  const _MedicationTaskCard({required this.task, required this.onTap});

  final _MedicationTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SoftCard(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.medication_outlined, color: medqurBlue, size: 22),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.patient.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: medqurInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${task.medication.name} ${task.medication.dose}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF687587),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    task.medication.route,
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.staff,
    required this.icon,
    required this.onTap,
  });

  final DiagnosticOrder order;
  final StaffProfile staff;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canWork = AccessPolicy.canWorkOnDiagnosticOrder(staff, order);
    final priorityColor = order.priority == DiagnosticOrderPriority.stat
        ? medqurRed
        : order.priority == DiagnosticOrderPriority.urgent
            ? medqurAmber
            : medqurBlue;

    return SoftCard(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 315;
          final priority = StatusPill(
            label: order.priority.label,
            color: priorityColor,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      priority,
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
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          priority,
                        ],
                      ),
                    const SizedBox(height: 4),
                    Text(
                      order.assignedDiscipline.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF748094),
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      canWork ? 'Open task' : 'Read only',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: canWork ? medqurGreen : const Color(0xFF8A96A6),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MedicationTask {
  const _MedicationTask(this.patient, this.medication);
  final Patient patient;
  final MedicationOrder medication;
}
