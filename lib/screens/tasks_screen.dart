import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/medqur_controller.dart';
import '../theme/medqur_theme.dart';
import '../widgets/common.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.controller});

  final MedqurController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pending = controller.medicationTasks.where((task) => task.status == MedicationTaskStatus.pending).toList();
        final done = controller.medicationTasks.where((task) => task.status == MedicationTaskStatus.administered).toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PageHeading(
              title: controller.role == StaffRole.nurse ? 'Medication queue' : 'Clinical orders',
              subtitle: controller.role == StaffRole.nurse
                  ? 'Doctor-signed medication tasks ready for closed-loop verification.'
                  : 'Orders you have sent into the treatment workflow.',
            ),
            const SizedBox(height: 18),
            if (pending.isEmpty)
              const _EmptyState()
            else
              ...pending.map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MedicationTaskCard(controller: controller, task: task),
                  )),
            if (done.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Completed',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: MedqurColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              ...done.map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MedicationTaskCard(controller: controller, task: task),
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _MedicationTaskCard extends StatelessWidget {
  const _MedicationTaskCard({required this.controller, required this.task});

  final MedqurController controller;
  final MedicationTask task;

  @override
  Widget build(BuildContext context) {
    final complete = task.status == MedicationTaskStatus.administered;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: complete ? const Color(0xFFEDF8F2) : const Color(0xFFEFF5FF),
                  child: Icon(
                    complete ? Icons.check_rounded : Icons.medication_outlined,
                    color: complete ? MedqurColors.success : MedqurColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.patientName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: MedqurColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${task.medication} · ${task.dose} · ${task.route}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MedqurColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: complete ? const Color(0xFFEDF8F2) : const Color(0xFFFFF4E6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    complete ? 'Administered' : 'Pending',
                    style: TextStyle(
                      color: complete ? MedqurColors.success : MedqurColors.warning,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniTag(icon: Icons.person_outline, label: task.orderedBy),
                _MiniTag(icon: Icons.schedule, label: task.frequency),
                _MiniTag(icon: Icons.tag, label: task.id),
              ],
            ),
            if (!complete && controller.role == StaffRole.nurse) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: MedqurColors.primaryDark),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Production flow: scan patient wristband + scan medication before administration.',
                        style: TextStyle(color: MedqurColors.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  controller.administerMedication(task.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${task.medication} recorded as administered to ${task.patientName}.')),
                  );
                },
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Demo scan checks & administer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: MedqurColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: MedqurColors.inkMuted),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: MedqurColors.inkMuted)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.task_alt_rounded, color: MedqurColors.success, size: 38),
            const SizedBox(height: 10),
            Text(
              'No pending medication tasks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MedqurColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
