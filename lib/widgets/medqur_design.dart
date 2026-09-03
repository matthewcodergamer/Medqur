import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import 'common.dart';

abstract final class MedqurLayout {
  static const compact = 600.0;
  static const medium = 1000.0;
  static const contentMax = 1180.0;

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compact) return const EdgeInsets.fromLTRB(16, 18, 16, 28);
    if (width < medium) return const EdgeInsets.fromLTRB(24, 22, 24, 34);
    return const EdgeInsets.fromLTRB(32, 28, 32, 42);
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
                    color: Color(0xFF7A8798),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .65,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: compact ? 26 : 30,
                      letterSpacing: -.7,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF647286),
                        height: 1.35,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 14),
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: medqurLine),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0910233F),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 13),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.15,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF718095),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A3B2)),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: medqurLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF718095),
                fontSize: 11.5,
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
    final allergy = patient.allergies.isEmpty ? 'No known allergies recorded' : patient.allergies.join(', ');
    final color = triageColor(patient.triage);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: medqurLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              triageCode(patient.triage),
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${patient.age} • ${patient.sex} • ${patient.id}',
                  style: const TextStyle(color: Color(0xFF718095), fontSize: 11.5),
                ),
                const SizedBox(height: 5),
                Text(
                  'Allergies: $allergy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: patient.allergies.isEmpty ? const Color(0xFF718095) : medqurRed,
                    fontSize: 11.5,
                    fontWeight: patient.allergies.isEmpty ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline_rounded, size: 17, color: Color(0xFF98A3B2)),
        ],
      ),
    );
  }
}

class CapsuleIllustration extends StatelessWidget {
  const CapsuleIllustration({super.key, this.width = 142});
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: width * .62,
        child: CustomPaint(painter: _CapsulePainter()),
      );
}

class _CapsulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width * .12, size.height * .12);
    canvas.rotate(-math.pi / 13);
    final rect = Rect.fromLTWH(0, 0, size.width * .76, size.height * .48);
    final radius = Radius.circular(rect.height / 2);
    final clip = RRect.fromRectAndRadius(rect, radius);
    canvas.clipRRect(clip);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, rect.width * .5, rect.height),
      Paint()..color = medqurBlue,
    );
    canvas.drawRect(
      Rect.fromLTWH(rect.width * .5, 0, rect.width * .5, rect.height),
      Paint()..color = Colors.white,
    );
    canvas.drawLine(
      Offset(rect.width * .5, 2),
      Offset(rect.width * .5, rect.height - 2),
      Paint()
        ..color = const Color(0xFFDCE5F2)
        ..strokeWidth = 1.4,
    );
    canvas.restore();

    final borderRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .12, size.height * .12, size.width * .76, size.height * .48),
      Radius.circular(size.height * .24),
    );
    canvas.save();
    canvas.translate(borderRect.left, borderRect.top);
    canvas.rotate(-math.pi / 13);
    canvas.translate(-borderRect.left, -borderRect.top);
    canvas.drawRRect(
      borderRect,
      Paint()
        ..color = const Color(0x180F274A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
