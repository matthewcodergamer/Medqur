import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';

class PatientQueuePage extends StatelessWidget {
  const PatientQueuePage({
    super.key,
    required this.staff,
    required this.patients,
    required this.onOpenPatient,
    required this.onNewEncounter,
  });

  final StaffProfile staff;
  final List<Patient> patients;
  final ValueChanged<Patient> onOpenPatient;
  final VoidCallback onNewEncounter;

  @override
  Widget build(BuildContext context) {
    final active = patients.where((p) => p.status != PatientStatus.discharge).toList()
      ..sort((a, b) => a.triage.index.compareTo(b.triage.index));
    final p1Count = active.where((p) => p.triage == TriageLevel.critical).length;
    final p2Count = active.where((p) => p.triage == TriageLevel.urgent).length;
    final canCreateEncounter = staff.role == StaffRole.doctor || staff.role == StaffRole.nurse;

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
                      staff.role == StaffRole.doctor
                          ? 'My patient queue'
                          : staff.role == StaffRole.pharmacist
                              ? 'Clinical patient reference'
                              : 'Patient flow',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text('${active.length} active patients • prioritized P1 → P4'),
                  ],
                ),
              ),
              if (canCreateEncounter)
                FilledButton.tonalIcon(
                  onPressed: onNewEncounter,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New encounter'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Emergency priority'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final level in TriageLevel.values)
              _PriorityMetric(
                level: level,
                value: active.where((p) => p.triage == level).length,
              ),
          ],
        ),
        if (p1Count + p2Count > 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: medqurRed.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: medqurRed.withValues(alpha: .20)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.emergency_rounded, color: medqurRed),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${p1Count > 0 ? '$p1Count P1' : ''}${p1Count > 0 && p2Count > 0 ? ' • ' : ''}${p2Count > 0 ? '$p2Count P2' : ''} active. P1/P2 patients require immediate or urgent routing and should not remain in routine waiting.',
                  style: const TextStyle(
                    color: medqurInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 24),
        const SectionTitle('Priority list'),
        const SizedBox(height: 6),
        Text(
          staff.role == StaffRole.pharmacist
              ? 'Pharmacists can review patient context for medication workflow, but encounter creation and triage remain clinical registration/nursing/medical actions.'
              : 'P1 appears first, followed by P2, P3 and P4. Clinical teams remain responsible for reassessment and escalation.',
          style: const TextStyle(color: Color(0xFF748297), fontSize: 12, height: 1.35),
        ),
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

class _PriorityMetric extends StatelessWidget {
  const _PriorityMetric({required this.level, required this.value});

  final TriageLevel level;
  final int value;

  @override
  Widget build(BuildContext context) {
    final color = triageColor(level);
    return Container(
      width: 146,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: medqurLine),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Text(
            triageCode(level),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: medqurInk),
            ),
            Text(
              triageName(level),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF748297)),
            ),
          ]),
        ),
      ]),
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
    final highPriority = triageBypassesRoutineWaiting(patient.triage);
    return SoftCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 5,
            height: highPriority ? 84 : 72,
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
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      patient.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: medqurInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
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
                if (highPriority) ...[
                  const SizedBox(height: 5),
                  Text(
                    triageAction(patient.triage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${patient.id} • ${patientStatusLabel(patient.status)} • ${patient.waitMinutes} min',
                  style: const TextStyle(
                    color: Color(0xFF8793A4),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
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
