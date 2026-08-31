import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/medqur_controller.dart';
import '../theme/medqur_theme.dart';
import '../widgets/common.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key, required this.controller});

  final MedqurController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const PageHeading(
              title: 'Clinical activity',
              subtitle: 'A human-readable view of the prototype audit trail.',
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: controller.auditEntries.map((entry) => _AuditRow(entry: entry)).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Production note: security and clinical audit records should be append-only, centrally retained and protected from ordinary user edits.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: MedqurColors.inkMuted, height: 1.4),
            ),
          ],
        );
      },
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final icon = switch (entry.kind) {
      'identity' => Icons.verified_user_outlined,
      'triage' => Icons.monitor_heart_outlined,
      'medication' => Icons.medication_outlined,
      _ => Icons.login_rounded,
    };
    final time = '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: MedqurColors.primaryDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: MedqurColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MedqurColors.inkMuted,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(time, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: MedqurColors.inkMuted)),
        ],
      ),
    );
  }
}
