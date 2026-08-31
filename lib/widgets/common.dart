import 'package:flutter/material.dart';
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

class MedqurLogo extends StatelessWidget {
  const MedqurLogo({super.key, this.width = 210});
  final double width;
  @override
  Widget build(BuildContext context) => Image.asset(
        AppAssets.medqurLogo,
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
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
      );
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.highlighted = false,
  });
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
        border: Border.all(
          color: highlighted ? medqurBlue.withValues(alpha: .55) : medqurLine,
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x0A173F8A), blurRadius: 22, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(22), onTap: onTap, child: card),
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
                    fontWeight: FontWeight.w800,
                    color: medqurInk,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
            ],
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

Color triageColor(TriageLevel level) {
  switch (level) {
    case TriageLevel.critical:
      return medqurRed;
    case TriageLevel.urgent:
      return const Color(0xFFE46A25);
    case TriageLevel.moderate:
      return medqurAmber;
    case TriageLevel.routine:
      return medqurGreen;
  }
}

String triageLabel(TriageLevel level) {
  switch (level) {
    case TriageLevel.critical:
      return 'Critical';
    case TriageLevel.urgent:
      return 'Urgent';
    case TriageLevel.moderate:
      return 'Moderate';
    case TriageLevel.routine:
      return 'Routine';
  }
}

String patientStatusLabel(PatientStatus status) {
  switch (status) {
    case PatientStatus.waiting:
      return 'Waiting';
    case PatientStatus.triaged:
      return 'Triaged';
    case PatientStatus.withDoctor:
      return 'With doctor';
    case PatientStatus.treatment:
      return 'Treatment';
    case PatientStatus.discharge:
      return 'Discharge';
  }
}

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 420 + delay.inMilliseconds),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          final delayed = delay.inMilliseconds == 0
              ? value
              : ((value * (420 + delay.inMilliseconds) - delay.inMilliseconds) / 420)
                  .clamp(0.0, 1.0);
          return Opacity(
            opacity: delayed,
            child: Transform.translate(offset: Offset(0, 12 * (1 - delayed)), child: child),
          );
        },
      );
}

class FakeQr extends StatelessWidget {
  const FakeQr({super.key, this.size = 88});
  final double size;
  @override
  Widget build(BuildContext context) {
    const pattern = [
      1,1,1,1,0,1,0,1,1,1,1, 1,0,0,1,1,0,1,1,0,0,1,
      1,0,1,1,0,1,0,1,1,0,1, 1,1,1,0,1,0,1,0,1,1,1,
      0,1,0,1,1,1,0,1,0,1,0, 1,0,1,0,1,0,1,1,1,0,1,
      0,1,1,1,0,1,0,0,1,1,0, 1,1,0,1,1,0,1,1,0,1,1,
      1,0,1,0,1,1,0,1,1,0,1, 1,0,0,1,0,1,1,0,0,1,1,
      1,1,1,1,0,1,0,1,1,1,1,
    ];
    return SizedBox(
      width: size,
      height: size,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: 121,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 11),
        itemBuilder: (_, i) => ColoredBox(color: pattern[i] == 1 ? medqurInk : Colors.white),
      ),
    );
  }
}
