import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';

class PatientQueuePage extends StatelessWidget {
  const PatientQueuePage({
    super.key,
    required this.staff,
    required this.patients,
    required this.onOpenPatient,
  });

  final StaffProfile staff;
  final List<Patient> patients;
  final ValueChanged<Patient> onOpenPatient;

  @override
  Widget build(BuildContext context) {
    final active = patients.where((p) => p.status != PatientStatus.discharge).toList()
      ..sort((a, b) => a.triage.index.compareTo(b.triage.index));

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        FadeSlideIn(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.role == StaffRole.doctor ? 'My patient queue' : 'Patient flow',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text('${active.length} active patients • prioritized by triage status'),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded),
                label: const Text('New encounter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Metric(
              label: 'Waiting',
              value: '${patients.where((p) => p.status == PatientStatus.waiting).length}',
              icon: Icons.schedule_rounded,
            ),
            _Metric(
              label: 'Triaged',
              value: '${patients.where((p) => p.status == PatientStatus.triaged).length}',
              icon: Icons.fact_check_outlined,
            ),
            _Metric(
              label: 'Treatment',
              value: '${patients.where((p) => p.medications.isNotEmpty).length}',
              icon: Icons.medication_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionTitle('Priority list'),
        const SizedBox(height: 12),
        ...active.map(
          (patient) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PatientTile(patient: patient, onTap: () => onOpenPatient(patient)),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: medqurLine),
      ),
      child: Row(
        children: [
          Icon(icon, color: medqurBlue, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: medqurInk)),
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF748297))),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient, required this.onTap});
  final Patient patient;
  final VoidCallback onTap;

  String get initials {
    if (patient.name.startsWith('Unknown')) return '?';
    return patient.name.split(' ').take(2).map((part) => part[0]).join();
  }

  @override
  Widget build(BuildContext context) {
    final color = triageColor(patient.triage);
    return SoftCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 5,
            height: 66,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(width: 14),
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: .10),
            foregroundColor: color,
            child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        patient.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(label: triageLabel(patient.triage), color: color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  patient.chiefComplaint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF66768B), fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '${patient.id} • ${patientStatusLabel(patient.status)} • ${patient.waitMinutes} min',
                  style: const TextStyle(color: Color(0xFF8793A4), fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA5B4)),
        ],
      ),
    );
  }
}
