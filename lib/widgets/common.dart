import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_assets.dart';
import '../models.dart';

const medqurBlue = Color(0xFF2F67C7);
const medqurNavy = Color(0xFF183B67);
const medqurInk = Color(0xFF17283A);
const medqurSurface = Color(0xFFF7F8FA);
const medqurLine = Color(0xFFE4E7EB);
const medqurGreen = Color(0xFF167A59);
const medqurAmber = Color(0xFFC98516);
const medqurRed = Color(0xFFC83B4B);

/// Browser-safe vector wordmark. It intentionally does not use the old raster
/// wordmark, which carried a baked grey background on some browsers.
class MedqurLogo extends StatelessWidget {
  const MedqurLogo({super.key, this.width = 210});
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * .29,
      child: FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.contain,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: 78,
              height: 62,
              child: CustomPaint(painter: _MedqurMarkPainter()),
            ),
            const SizedBox(width: 4),
            const Text(
              'edqur',
              style: TextStyle(
                color: medqurNavy,
                fontSize: 58,
                fontWeight: FontWeight.w400,
                letterSpacing: -2.6,
                height: 1,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 6, bottom: 31),
              child: Text(
                'TM',
                style: TextStyle(
                  color: medqurNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedqurMarkPainter extends CustomPainter {
  const _MedqurMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = medqurBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .115
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .13, size.height * .18)
      ..lineTo(size.width * .13, size.height * .82)
      ..quadraticBezierTo(
        size.width * .13,
        size.height * .90,
        size.width * .22,
        size.height * .90,
      )
      ..lineTo(size.width * .78, size.height * .90)
      ..quadraticBezierTo(
        size.width * .87,
        size.height * .90,
        size.width * .87,
        size.height * .82,
      )
      ..lineTo(size.width * .87, size.height * .18)
      ..lineTo(size.width * .54, size.height * .55)
      ..quadraticBezierTo(
        size.width * .50,
        size.height * .60,
        size.width * .46,
        size.height * .55,
      )
      ..lineTo(size.width * .13, size.height * .18);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The Ministry artwork in assets/ministry_health_logo.png is a wide wordmark,
/// not a square icon. `width` renders that full wordmark at its natural aspect
/// ratio. `size` is retained for source compatibility with older call sites.
class MinistryLogo extends StatelessWidget {
  const MinistryLogo({
    super.key,
    this.size = 58,
    this.width,
  });

  final double size;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final resolvedWidth = width ?? size;
    final resolvedHeight = width == null ? size : resolvedWidth / 2.82;

    return SizedBox(
      width: resolvedWidth,
      height: resolvedHeight,
      child: Image.asset(
        AppAssets.ministryLogo,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        errorBuilder: (_, __, ___) => Align(
          alignment: Alignment.centerLeft,
          child: Icon(
            Icons.health_and_safety_rounded,
            color: medqurGreen,
            size: resolvedHeight * .72,
          ),
        ),
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(
          color: highlighted
              ? medqurBlue.withValues(alpha: .45)
              : medqurLine,
          width: highlighted ? 1.25 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: medqurInk,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .065),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12.5, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

/// The persisted enum names remain critical/urgent/moderate/routine so V0.2
/// prototype data still loads, while the clinical UI now exposes Jamaica's
/// P1-P4 emergency-priority terminology.
Color triageColor(TriageLevel level) => switch (level) {
      TriageLevel.critical => medqurRed,
      TriageLevel.urgent => const Color(0xFFD66B2C),
      TriageLevel.moderate => medqurAmber,
      TriageLevel.routine => medqurGreen,
    };

String triageCode(TriageLevel level) => switch (level) {
      TriageLevel.critical => 'P1',
      TriageLevel.urgent => 'P2',
      TriageLevel.moderate => 'P3',
      TriageLevel.routine => 'P4',
    };

String triageName(TriageLevel level) => switch (level) {
      TriageLevel.critical => 'Critical',
      TriageLevel.urgent => 'Emergent',
      TriageLevel.moderate => 'Intermediate',
      TriageLevel.routine => 'Fast track',
    };

String triageLabel(TriageLevel level) =>
    '${triageCode(level)} • ${triageName(level)}';

String triageDescription(TriageLevel level) => switch (level) {
      TriageLevel.critical =>
        'Life-threatening emergency requiring immediate life-saving intervention.',
      TriageLevel.urgent =>
        'Severe or potentially life-threatening condition requiring rapid assessment and urgent treatment.',
      TriageLevel.moderate =>
        'Stable, intermediate condition requiring medical care that can be delayed safely for a reasonable period.',
      TriageLevel.routine =>
        'Minor, non-acute or routine case appropriate for fast-track care.',
    };

String triageAction(TriageLevel level) => switch (level) {
      TriageLevel.critical =>
        'Immediate • route directly to resuscitation',
      TriageLevel.urgent =>
        'Urgent • route to priority treatment area',
      TriageLevel.moderate =>
        'Care required • reassess while waiting',
      TriageLevel.routine =>
        'Fast track • lowest emergency queue priority',
    };

bool triageBypassesRoutineWaiting(TriageLevel level) =>
    level == TriageLevel.critical || level == TriageLevel.urgent;

String patientStatusLabel(PatientStatus status) => switch (status) {
      PatientStatus.waiting => 'Waiting',
      PatientStatus.triaged => 'Triaged',
      PatientStatus.withDoctor => 'With doctor',
      PatientStatus.treatment => 'Treatment',
      PatientStatus.discharge => 'Discharge',
    };

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 260 + delay.inMilliseconds),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          final delayed = delay.inMilliseconds == 0
              ? value
              : ((value * (260 + delay.inMilliseconds) -
                          delay.inMilliseconds) /
                      260)
                  .clamp(0.0, 1.0);
          return Opacity(
            opacity: delayed,
            child: Transform.translate(
              offset: Offset(0, 6 * (1 - delayed)),
              child: child,
            ),
          );
        },
      );
}

/// Kept under the original class name so V0.1 screens remain source-compatible,
/// but this renders an actual, scannable QR code.
class FakeQr extends StatelessWidget {
  const FakeQr({
    super.key,
    this.size = 88,
    this.data = 'medqur://prototype',
  });

  final double size;
  final String data;

  @override
  Widget build(BuildContext context) => QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        padding: const EdgeInsets.all(4),
        backgroundColor: Colors.white,
      );
}
