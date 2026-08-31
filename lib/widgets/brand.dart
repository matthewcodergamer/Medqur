import 'package:flutter/material.dart';

import '../theme/medqur_theme.dart';

class MedqurLogo extends StatelessWidget {
  const MedqurLogo({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/medqur_logo.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class MedqurMark extends StatelessWidget {
  const MedqurMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .24),
      child: Image.asset(
        'assets/branding/medqur_mark.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class MinistryBrand extends StatelessWidget {
  const MinistryBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 32 : 42,
          height: compact ? 32 : 42,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBF7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MedqurColors.border),
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.favorite_rounded, color: Color(0xFF0A9B4B), size: 26),
              Icon(Icons.monitor_heart_outlined, color: Color(0xFFFFC107), size: 19),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ministry of Health & Wellness',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: MedqurColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (!compact)
                Text(
                  'Jamaica · concept integration',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MedqurColors.inkMuted,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
