import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
import '../widgets/medqur_responsive.dart';

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
    final active = patients
        .where((p) => p.status != PatientStatus.discharge)
        .toList()
      ..sort((a, b) => a.triage.index.compareTo(b.triage.index));
    final p1Count =
        active.where((p) => p.triage == TriageLevel.critical).length;
    final p2Count = active.where((p) => p.triage == TriageLevel.urgent).length;
    final canCreateEncounter =
        staff.role == StaffRole.doctor || staff.role == StaffRole.nurse;

    final title = staff.role == StaffRole.doctor
        ? 'My patient queue'
        : staff.role == StaffRole.pharmacist
            ? 'Patients'
            : 'Patient flow';

    return MedqurPage(
      wide: true,
      children: [
        MedqurPageHeader(
          title: title,
          subtitle: '${active.length} active • P1 → P4 priority',
          trailing: canCreateEncounter
              ? FilledButton.tonalIcon(
                  onPressed: onNewEncounter,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New encounter'),
                )
              : null,
        ),
        const SizedBox(height: 18),
        const SectionTitle('Emergency priority'),
        const SizedBox(height: 10),
        ResponsiveGrid(
          minItemWidth: 125,
          maxColumns: 4,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final level in TriageLevel.values)
              _PriorityMetric(
                level: level,
                value: active.where((p) => p.triage == level).length,
              ),
          ],
        ),
        if (p1Count + p2Count > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: medqurRed.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: medqurRed.withValues(alpha: .20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emergency_rounded, color: medqurRed, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${p1Count > 0 ? '$p1Count P1' : ''}${p1Count > 0 && p2Count > 0 ? ' • ' : ''}${p2Count > 0 ? '$p2Count P2' : ''} require priority routing.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: medqurInk,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        const SectionTitle('Priority list'),
        const SizedBox(height: 9),
        if (active.isEmpty)
          const SoftCard(child: Text('No active patients.'))
        else
          ResponsiveGrid(
            minItemWidth: 350,
            maxColumns: 2,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final patient in active)
                _PatientTile(
                  patient: patient,
                  onTap: () => onOpenPatient(patient),
                ),
            ],
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
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: medqurLine),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              triageCode(level),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: medqurInk,
                  ),
                ),
                Text(
                  triageName(level),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF748297),
                  ),
                ),
              ],
            ),
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
    final highPriority = triageBypassesRoutineWaiting(patient.triage);
    return SoftCard(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tiny = constraints.maxWidth < 320;
          return Row(
            children: [
              Container(
                width: 4,
                height: highPriority ? 78 : 66,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              if (!tiny) ...[
                CircleAvatar(
                  radius: 21,
                  backgroundColor: color.withValues(alpha: .10),
                  foregroundColor: color,
                  child: Text(
                    initials,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: medqurInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        StatusPill(
                          label: triageLabel(patient.triage),
                          color: color,
                        ),
                        StatusPill(
                          label: patientStatusLabel(patient.status),
                          color: medqurBlue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      patient.chiefComplaint,
                      maxLines: highPriority ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF66768B),
                        fontSize: 11.5,
                      ),
                    ),
                    if (highPriority) ...[
                      const SizedBox(height: 4),
                      Text(
                        triageAction(patient.triage),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9AA5B4),
              ),
            ],
          );
        },
      ),
    );
  }
}
