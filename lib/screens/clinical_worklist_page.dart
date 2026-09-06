import 'package:flutter/material.dart';

import '../clinical_models.dart';
import '../models.dart';
import '../services/access_policy.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';

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
      children: [
        MedqurPageHeader(
          eyebrow: 'Clinical support',
          title: 'Worklist',
          subtitle:
              '${staff.clinicalDiscipline.label} • orders and patient tasks routed from the clinical team.',
          trailing: StatusPill(
            label: '${medicationTasks.length + openOrders.length} open',
            color: medicationTasks.isEmpty && openOrders.isEmpty
                ? medqurGreen
                : medqurAmber,
          ),
        ),
        const SizedBox(height: 18),
        if (medicationTasks.isNotEmpty) ...[
          SectionTitle('Medication administration'),
          const SizedBox(height: 10),
          for (final task in medicationTasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SoftCard(
                padding: const EdgeInsets.all(14),
                onTap: () => onOpenPatient(task.patient),
                child: Row(
                  children: [
                    const Icon(Icons.medication_outlined,
                        color: medqurBlue, size: 22),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.patient.name,
                            style: const TextStyle(
                              color: medqurInk,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${task.medication.name} ${task.medication.dose} • ${task.medication.route}',
                            style: const TextStyle(
                              color: Color(0xFF687587),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF9AA4B1)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        SectionTitle('Tests & procedures'),
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
          for (final order in openOrders)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SoftCard(
                padding: const EdgeInsets.all(14),
                onTap: () => onOpenOrder(order),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _orderIcon(order.type),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  order.studyName,
                                  style: const TextStyle(
                                    color: medqurInk,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              StatusPill(
                                label: order.priority.label,
                                color: order.priority == DiagnosticOrderPriority.stat
                                    ? medqurRed
                                    : order.priority == DiagnosticOrderPriority.urgent
                                        ? medqurAmber
                                        : medqurBlue,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${order.patientId} • ${order.assignedDiscipline.label}',
                            style: const TextStyle(
                              color: Color(0xFF748094),
                              fontSize: 10.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            AccessPolicy.canWorkOnDiagnosticOrder(staff, order)
                                ? 'Tap to perform and upload result'
                                : 'Read only — routed to another discipline',
                            style: TextStyle(
                              color: AccessPolicy.canWorkOnDiagnosticOrder(staff, order)
                                  ? medqurGreen
                                  : const Color(0xFF8A96A6),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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

class _MedicationTask {
  const _MedicationTask(this.patient, this.medication);
  final Patient patient;
  final MedicationOrder medication;
}
