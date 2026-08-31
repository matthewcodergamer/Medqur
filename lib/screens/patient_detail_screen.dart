import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/medqur_controller.dart';
import '../theme/medqur_theme.dart';
import '../widgets/common.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({
    super.key,
    required this.controller,
    required this.patient,
  });

  final MedqurController controller;
  final Patient patient;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  String medication = 'Paracetamol';
  String dose = '500 mg';
  String route = 'Oral';

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(patient.name),
        actions: [
          IconButton(
            tooltip: 'Scan wristband',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Demo wristband scan confirmed this encounter.')),
            ),
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _IdentityCard(patient: patient),
          const SizedBox(height: 14),
          _VitalsCard(patient: patient),
          const SizedBox(height: 14),
          _ClinicalSummary(patient: patient),
          const SizedBox(height: 14),
          if (widget.controller.role == StaffRole.doctor)
            _DoctorOrderCard(
              medication: medication,
              dose: dose,
              route: route,
              onMedicationChanged: (value) => setState(() => medication = value),
              onDoseChanged: (value) => setState(() => dose = value),
              onRouteChanged: (value) => setState(() => route = value),
              onSubmit: () {
                widget.controller.placeMedicationOrder(
                  patient: patient,
                  medication: medication,
                  dose: dose,
                  route: route,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$medication order sent to the nursing medication queue.')),
                );
              },
            )
          else
            _NursePatientTasks(controller: widget.controller, patient: patient),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFEFF5FF),
                  child: Text(
                    patient.initials,
                    style: const TextStyle(color: MedqurColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: MedqurColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        patient.age == 0 ? patient.sex : '${patient.age} years · ${patient.sex}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MedqurColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                TriageChip(level: patient.triageLevel),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: patient.nidsVerified ? const Color(0xFFEDF8F2) : const Color(0xFFFFF4E6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    patient.nidsVerified ? Icons.verified_user_outlined : Icons.emergency_outlined,
                    color: patient.nidsVerified ? MedqurColors.success : MedqurColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      patient.nidsVerified
                          ? 'Identity verified in this demo after patient consent. Only minimum identity fields are linked.'
                          : 'Temporary emergency encounter. Care may continue before identity is known, then records can be reconciled later.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: MedqurColors.navy,
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${patient.id} · ${patient.encounterId}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: MedqurColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Triage vitals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MedqurColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: patient.vitals.entries
                  .map(
                    (entry) => Container(
                      width: 150,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: MedqurColors.inkMuted)),
                          const SizedBox(height: 3),
                          Text(
                            entry.value,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: MedqurColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicalSummary extends StatelessWidget {
  const _ClinicalSummary({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clinical summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MedqurColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _SummaryRow(label: 'Chief complaint', value: patient.chiefComplaint),
            _SummaryRow(label: 'Triage note', value: patient.triageNote),
            _SummaryRow(label: 'Allergies', value: patient.allergies.isEmpty ? 'None recorded' : patient.allergies.join(', ')),
            _SummaryRow(label: 'History', value: patient.history.join(', '), last: true),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: MedqurColors.inkMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MedqurColors.navy, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorOrderCard extends StatelessWidget {
  const _DoctorOrderCard({
    required this.medication,
    required this.dose,
    required this.route,
    required this.onMedicationChanged,
    required this.onDoseChanged,
    required this.onRouteChanged,
    required this.onSubmit,
  });

  final String medication;
  final String dose;
  final String route;
  final ValueChanged<String> onMedicationChanged;
  final ValueChanged<String> onDoseChanged;
  final ValueChanged<String> onRouteChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.medication_outlined, color: MedqurColors.primaryDark),
                const SizedBox(width: 8),
                Text(
                  'Create medication order',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: MedqurColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Prototype order entry. A production system would validate allergies, interactions, formulary and prescribing privileges before signing.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: MedqurColors.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: medication,
              decoration: const InputDecoration(labelText: 'Medication'),
              items: const [
                DropdownMenuItem(value: 'Paracetamol', child: Text('Paracetamol')),
                DropdownMenuItem(value: 'Salbutamol', child: Text('Salbutamol')),
                DropdownMenuItem(value: 'Oral rehydration salts', child: Text('Oral rehydration salts')),
              ],
              onChanged: (value) {
                if (value != null) onMedicationChanged(value);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: dose,
                    decoration: const InputDecoration(labelText: 'Dose'),
                    items: const [
                      DropdownMenuItem(value: '500 mg', child: Text('500 mg')),
                      DropdownMenuItem(value: '2.5 mg', child: Text('2.5 mg')),
                      DropdownMenuItem(value: '5 mL', child: Text('5 mL')),
                    ],
                    onChanged: (value) {
                      if (value != null) onDoseChanged(value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: route,
                    decoration: const InputDecoration(labelText: 'Route'),
                    items: const [
                      DropdownMenuItem(value: 'Oral', child: Text('Oral')),
                      DropdownMenuItem(value: 'Nebulized', child: Text('Nebulized')),
                      DropdownMenuItem(value: 'IV', child: Text('IV')),
                    ],
                    onChanged: (value) {
                      if (value != null) onRouteChanged(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Text('Sign & send to nurse'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NursePatientTasks extends StatelessWidget {
  const _NursePatientTasks({required this.controller, required this.patient});

  final MedqurController controller;
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tasks = controller.medicationTasks.where((task) => task.patientId == patient.id).toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Medication tasks',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: MedqurColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                if (tasks.isEmpty)
                  const Text('No pending medication orders for this patient.', style: TextStyle(color: MedqurColors.inkMuted))
                else
                  ...tasks.map((task) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEFF5FF),
                            child: Icon(Icons.medication, color: MedqurColors.primaryDark),
                          ),
                          title: Text('${task.medication} · ${task.dose}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${task.route} · ordered by ${task.orderedBy}'),
                          trailing: task.status == MedicationTaskStatus.pending
                              ? FilledButton.tonal(
                                  onPressed: () => controller.administerMedication(task.id),
                                  child: const Text('Administer'),
                                )
                              : const Icon(Icons.check_circle, color: MedqurColors.success),
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }
}
