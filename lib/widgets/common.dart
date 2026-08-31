import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_assets.dart';
import '../models.dart';

const medqurBlue = Color(0xFF3474E6);
const medqurNavy = Color(0xFF173F8A);
const medqurInk = Color(0xFF10233F);
const medqurSurface = Color(0xFFF5F8FC);
const medqurLine = Color(0xFFE3EAF3);
const medqurGreen = Color(0xFF0F9D73);
const medqurAmber = Color(0xFFF4A51C);
const medqurRed = Color(0xFFD83A4D);

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
            const SizedBox(width: 78, height: 62, child: CustomPaint(painter: _MedqurMarkPainter())),
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
              child: Text('TM', style: TextStyle(color: medqurNavy, fontSize: 13, fontWeight: FontWeight.w900)),
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
      ..quadraticBezierTo(size.width * .13, size.height * .90, size.width * .22, size.height * .90)
      ..lineTo(size.width * .78, size.height * .90)
      ..quadraticBezierTo(size.width * .87, size.height * .90, size.width * .87, size.height * .82)
      ..lineTo(size.width * .87, size.height * .18)
      ..lineTo(size.width * .54, size.height * .55)
      ..quadraticBezierTo(size.width * .50, size.height * .60, size.width * .46, size.height * .55)
      ..lineTo(size.width * .13, size.height * .18);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MinistryLogo extends StatelessWidget {
  const MinistryLogo({super.key, this.size = 58});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
        AppAssets.ministryLogo,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.health_and_safety_rounded, color: medqurGreen),
        ),
      );
}

class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.highlighted = false});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: highlighted ? medqurBlue.withValues(alpha: .55) : medqurLine, width: highlighted ? 1.5 : 1),
        boxShadow: const [BoxShadow(color: Color(0x0A173F8A), blurRadius: 22, offset: Offset(0, 8))],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(22), onTap: onTap, child: card));
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: medqurInk))),
        if (trailing != null) trailing!,
      ]);
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 5)],
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      );
}

Color triageColor(TriageLevel level) => switch (level) {
      TriageLevel.critical => medqurRed,
      TriageLevel.urgent => const Color(0xFFE46A25),
      TriageLevel.moderate => medqurAmber,
      TriageLevel.routine => medqurGreen,
    };

String triageLabel(TriageLevel level) => switch (level) {
      TriageLevel.critical => 'Critical',
      TriageLevel.urgent => 'Urgent',
      TriageLevel.moderate => 'Moderate',
      TriageLevel.routine => 'Routine',
    };

String patientStatusLabel(PatientStatus status) => switch (status) {
      PatientStatus.waiting => 'Waiting',
      PatientStatus.triaged => 'Triaged',
      PatientStatus.withDoctor => 'With doctor',
      PatientStatus.treatment => 'Treatment',
      PatientStatus.discharge => 'Discharge',
    };

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 360 + delay.inMilliseconds),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          final delayed = delay.inMilliseconds == 0
              ? value
              : ((value * (360 + delay.inMilliseconds) - delay.inMilliseconds) / 360).clamp(0.0, 1.0);
          return Opacity(opacity: delayed, child: Transform.translate(offset: Offset(0, 9 * (1 - delayed)), child: child));
        },
      );
}

/// Kept under the original class name so V0.1 screens remain source-compatible,
/// but this now renders an actual, scannable QR code.
class FakeQr extends StatelessWidget {
  const FakeQr({super.key, this.size = 88, this.data = 'medqur://prototype'});
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
