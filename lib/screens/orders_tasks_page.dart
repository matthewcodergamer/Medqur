import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({
    super.key,
    required this.staff,
    required this.patients,
    required this.onOpenPatient,
    required this.onCreatePrescription,
  });

  final StaffProfile staff;
  final List<Patient> patients;
  final ValueChanged<Patient> onOpenPatient;
  final VoidCallback onCreatePrescription;

  @override
  Widget build(BuildContext context) {
    final ordered = patients.where((patient) => patient.medications.isNotEmpty).toList();
    final active = patients.fold<int>(
      0,
      (sum, patient) => sum + patient.medications.where((med) => !med.administered).length,
    );

    return MedqurPage(
      children: [
        MedqurPageHeader(
          eyebrow: 'Doctor workspace',
          title: 'Medications',
          subtitle: 'Create, sign and review patient prescriptions.',
          trailing: IconButton.filledTonal(
            tooltip: 'New prescription',
            onPressed: onCreatePrescription,
            icon: const Icon(Icons.add_rounded),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCE7FB)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prescribe with patient context',
                      style: TextStyle(color: medqurInk, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Search or scan the package, enter dose and route, then sign with your finger or stylus before sending.',
                      style: TextStyle(color: Color(0xFF647286), fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const CapsuleIllustration(width: 102),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onCreatePrescription,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('New prescription'),
        ),
        const SizedBox(height: 24),
        SectionTitle(
          'Active prescriptions',
          trailing: StatusPill(
            label: '$active active',
            color: active > 0 ? medqurBlue : medqurGreen,
          ),
        ),
        const SizedBox(height: 10),
        if (ordered.isEmpty)
          const SoftCard(
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: Color(0xFF8B98A9)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No medication prescriptions have been created for the current patient list.',
                    style: TextStyle(color: Color(0xFF65748A)),
                  ),
                ),
              ],
            ),
          )
        else
          for (final patient in ordered)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                padding: const EdgeInsets.all(16),
                onTap: () => onOpenPatient(patient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            patient.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: medqurInk,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                        StatusPill(
                          label: triageCode(patient.triage),
                          color: triageColor(patient.triage),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      patient.effectiveEncounterId,
                      style: const TextStyle(color: Color(0xFF8A96A6), fontSize: 10.5),
                    ),
                    const SizedBox(height: 10),
                    for (final med in patient.medications)
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: medqurBlue.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.medication_outlined, size: 18, color: medqurBlue),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${med.name} • ${med.dose}',
                                    style: const TextStyle(color: medqurInk, fontSize: 13, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${med.route} • ${med.frequency}${med.scheduledAt == null ? '' : ' • scheduled'}',
                                    style: const TextStyle(color: Color(0xFF718095), fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusPill(
                              label: med.administered ? 'Given' : 'Active',
                              color: med.administered ? medqurGreen : medqurAmber,
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
}

class NurseTasksPage extends StatelessWidget {
  const NurseTasksPage({
    super.key,
    required this.patients,
    required this.onOpenPatient,
  });

  final List<Patient> patients;
  final ValueChanged<Patient> onOpenPatient;

  @override
  Widget build(BuildContext context) {
    final tasks = <_Task>[];
    for (final patient in patients) {
      for (final medication in patient.medications) {
        if (!medication.administered) tasks.add(_Task(patient, medication));
      }
    }

    return MedqurPage(
      children: [
        MedqurPageHeader(
          eyebrow: 'Nursing workspace',
          title: 'Medication tasks',
          subtitle: 'Verify the patient wristband and medication package before administration.',
          trailing: StatusPill(
            label: '${tasks.length} due',
            color: tasks.isEmpty ? medqurGreen : medqurAmber,
          ),
        ),
        const SizedBox(height: 18),
        if (tasks.isEmpty)
          const SoftCard(
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: medqurGreen),
                SizedBox(width: 10),
                Expanded(child: Text('No pending medication tasks.')),
              ],
            ),
          )
        else
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                padding: const EdgeInsets.all(15),
                onTap: () => onOpenPatient(task.patient),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: medqurAmber.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.medication_outlined, color: medqurAmber),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.patient.name, style: const TextStyle(fontWeight: FontWeight.w800, color: medqurInk)),
                          const SizedBox(height: 3),
                          Text('${task.medication.name} ${task.medication.dose} • ${task.medication.route}', style: const TextStyle(color: Color(0xFF65748A), fontSize: 12)),
                          const SizedBox(height: 3),
                          Text('Ordered by ${task.medication.orderedBy}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF8793A4))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.qr_code_scanner_rounded, color: medqurBlue, size: 21),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _Task {
  const _Task(this.patient, this.medication);
  final Patient patient;
  final MedicationOrder medication;
}
