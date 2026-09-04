import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import 'common.dart';

abstract final class MedqurLayout {
  static const compact = 600.0;
  static const medium = 1000.0;
  static const contentMax = 1120.0;

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compact) {
      return const EdgeInsets.fromLTRB(14, 16, 14, 24);
    }
    if (width < medium) {
      return const EdgeInsets.fromLTRB(22, 20, 22, 30);
    }
    return const EdgeInsets.fromLTRB(30, 26, 30, 38);
  }
}

class MedqurPage extends StatelessWidget {
  const MedqurPage({
    super.key,
    required this.children,
    this.controller,
    this.physics,
  });

  final List<Widget> children;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MedqurLayout.contentMax),
        child: ListView(
          controller: controller,
          physics: physics,
          padding: MedqurLayout.pagePadding(context),
          children: children,
        ),
      ),
    );
  }
}

class MedqurPageHeader extends StatelessWidget {
  const MedqurPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.eyebrow,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < MedqurLayout.compact;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF7B8796),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .55,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: compact ? 23 : 27,
                      letterSpacing: -.5,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF69778A),
                        fontSize: compact ? 12.5 : 13,
                        height: 1.34,
                      ),
                ),
              ],
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

class MedqurActionCard extends StatelessWidget {
  const MedqurActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.accent = medqurBlue,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: medqurLine),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .075),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: medqurInk,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.1,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                color: accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF748094),
                        fontSize: 11.8,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9AA4B1),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MedqurMetric extends StatelessWidget {
  const MedqurMetric({
    super.key,
    required this.value,
    required this.label,
    this.color = medqurBlue,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: medqurLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -.4,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF748094),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class PatientContextBar extends StatelessWidget {
  const PatientContextBar({super.key, required this.patient});
  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final allergy = patient.allergies.isEmpty
        ? 'No known allergies recorded'
        : patient.allergies.join(', ');
    final color = triageColor(patient.triage);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: medqurLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              triageCode(patient.triage),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: const TextStyle(
                    color: medqurInk,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${patient.age} • ${patient.sex} • ${patient.id}',
                  style: const TextStyle(
                    color: Color(0xFF748094),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Allergies: $allergy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: patient.allergies.isEmpty
                        ? const Color(0xFF748094)
                        : medqurRed,
                    fontSize: 11,
                    fontWeight: patient.allergies.isEmpty
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: Color(0xFF9AA4B1),
          ),
        ],
      ),
    );
  }
}

/// A restrained medication motif for low-risk browsing surfaces only.
/// It should not be used on prescribing confirmation or administration screens.
class CapsuleIllustration extends StatelessWidget {
  const CapsuleIllustration({super.key, this.width = 132});
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: width * .54,
        child: CustomPaint(painter: _CapsulePainter()),
      );
}

class _CapsulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width * .14, size.height * .12);
    canvas.rotate(-math.pi / 15);

    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        3,
        4,
        size.width * .70,
        size.height * .40,
      ),
      Radius.circular(size.height * .20),
    );
    canvas.drawRRect(
      shadowRect,
      Paint()
        ..color = const Color(0x1210243F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final rect = Rect.fromLTWH(
      0,
      0,
      size.width * .70,
      size.height * .40,
    );
    final capsule = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    canvas.clipRRect(capsule);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, rect.width * .5, rect.height),
      Paint()..color = const Color(0xFF2E6EDC),
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.width * .5, 0, rect.width * .5, rect.height),
      Paint()..color = const Color(0xFFFDFEFE),
    );
    canvas.drawLine(
      Offset(rect.width * .5, 1),
      Offset(rect.width * .5, rect.height - 1),
      Paint()
        ..color = const Color(0xFFD8E0EA)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
