import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/medqur_controller.dart';
import '../theme/medqur_theme.dart';
import '../widgets/common.dart';
import 'patient_detail_screen.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key, required this.controller});

  final MedqurController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 700 ? 16.0 : 28.0;
        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            PageHeading(
              title: controller.role == StaffRole.doctor ? 'My patient queue' : 'Triage & patient queue',
              subtitle: '${controller.activeFacility!.name} · live shift view',
              trailing: IconButton.filledTonal(
                tooltip: 'Scan patient wristband',
                onPressed: () => controller.selectTab(1),
                icon: const Icon(Icons.qr_code_scanner),
              ),
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, box) {
                final columns = box.maxWidth >= 820 ? 4 : 2;
                const gap = 12.0;
                final width = (box.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(width: width, child: const MetricCard(label: 'Waiting', value: '4', icon: Icons.schedule)),
                    SizedBox(width: width, child: const MetricCard(label: 'Urgent', value: '2', icon: Icons.priority_high_rounded)),
                    SizedBox(width: width, child: const MetricCard(label: 'Treatment', value: '3', icon: Icons.medication_outlined)),
                    SizedBox(width: width, child: const MetricCard(label: 'Discharged', value: '11', icon: Icons.check_circle_outline)),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Assigned patients',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: MedqurColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                Text(
                  '${controller.patients.length} patients',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: MedqurColors.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...controller.patients.map((patient) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PatientTile(
                    patient: patient,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PatientDetailScreen(controller: controller, patient: patient),
                        ),
                      );
                    },
                  ),
                )),
          ],
        );
      },
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: patient.nidsVerified ? const Color(0xFFEFF5FF) : const Color(0xFFFFF4E6),
                child: Text(
                  patient.initials,
                  style: TextStyle(
                    color: patient.nidsVerified ? MedqurColors.primaryDark : MedqurColors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: MedqurColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (patient.nidsVerified)
                          const Icon(Icons.verified_rounded, color: MedqurColors.primary, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patient.chiefComplaint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MedqurColors.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TriageChip(level: patient.triageLevel),
                        Text(
                          patient.waitMinutes == 0 ? 'Now' : 'Waiting ${patient.waitMinutes} min',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: MedqurColors.inkMuted),
                        ),
                        Text(
                          patient.encounterId,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: MedqurColors.inkMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: MedqurColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
