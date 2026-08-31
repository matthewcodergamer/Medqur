import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/medqur_theme.dart';

class PrototypePill extends StatelessWidget {
  const PrototypePill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD4E3FB)),
      ),
      child: Text(
        'CONCEPT PROTOTYPE · NO LIVE PATIENT DATA',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: MedqurColors.primaryDark,
              fontWeight: FontWeight.w800,
              letterSpacing: .35,
            ),
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: MedqurColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MedqurColors.inkMuted,
                    ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class TriageChip extends StatelessWidget {
  const TriageChip({super.key, required this.level});

  final TriageLevel level;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (level) {
      TriageLevel.critical => ('Critical', MedqurColors.danger, const Color(0xFFFFEDED)),
      TriageLevel.urgent => ('Urgent', MedqurColors.warning, const Color(0xFFFFF4E6)),
      TriageLevel.standard => ('Standard', MedqurColors.primaryDark, const Color(0xFFEFF5FF)),
      TriageLevel.low => ('Low', MedqurColors.success, const Color(0xFFECF8F2)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF5FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: MedqurColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: MedqurColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MedqurColors.inkMuted,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
