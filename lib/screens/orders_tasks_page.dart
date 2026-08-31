import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({
    super.key,
    required this.patients,
    required this.onOpenPatient,
  });

  final List<Patient> patients;
  final ValueChanged<Patient> onOpenPatient;

  @override
  Widget build(BuildContext context) {
    final ordered = patients.where((patient) => patient.medications.isNotEmpty).toList();
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('Orders', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'Medication instructions are structured, traceable, and immediately visible to the care team.',
        ),
        const SizedBox(height: 22),
        if (ordered.isEmpty)
          const SoftCard(child: Text('No active medication orders in this demo.'))
        else
          for (final patient in ordered)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SoftCard(
                onTap: () => onOpenPatient(patient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: medqurInk, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    for (final med in patient.medications)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: medqurBlue.withValues(alpha: .10),
                          foregroundColor: medqurBlue,
                          child: const Icon(Icons.medication_outlined),
                        ),
                        title: Text('${med.name} • ${med.dose}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${med.route} • ${med.frequency}'),
                        trailing: StatusPill(
                          label: med.administered ? 'Administered' : 'Awaiting nurse',
                          color: med.administered ? medqurGreen : medqurAmber,
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
      for (var i = 0; i < patient.medications.length; i++) {
        if (!patient.medications[i].administered) {
          tasks.add(_Task(patient, patient.medications[i]));
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('Medication tasks', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'Confirm the right patient and medication by scanning both before administration.',
        ),
        const SizedBox(height: 22),
        if (tasks.isEmpty)
          const SoftCard(
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: medqurGreen),
                SizedBox(width: 10),
                Text('No pending medication tasks.'),
              ],
            ),
          )
        else
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SoftCard(
                onTap: () => onOpenPatient(task.patient),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: medqurAmber.withValues(alpha: .12),
                      foregroundColor: medqurAmber,
                      child: const Icon(Icons.medication_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.patient.name, style: const TextStyle(fontWeight: FontWeight.w900, color: medqurInk)),
                          const SizedBox(height: 4),
                          Text('${task.medication.name} ${task.medication.dose} • ${task.medication.route}', style: const TextStyle(color: Color(0xFF65748A))),
                          const SizedBox(height: 4),
                          Text('Ordered by ${task.medication.orderedBy}', style: const TextStyle(fontSize: 11, color: Color(0xFF8793A4))),
                        ],
                      ),
                    ),
                    const StatusPill(label: 'Scan to give', color: medqurAmber),
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
