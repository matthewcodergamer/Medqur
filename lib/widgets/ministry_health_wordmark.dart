import 'package:flutter/material.dart';

import '../app_assets.dart';
import 'common.dart';

/// Responsive Ministry of Health & Wellness branding.
///
/// The supplied Ministry artwork is already the authoritative wide wordmark.
/// This widget deliberately does not redraw, crop or stretch it. That keeps the
/// heart/ECG mark and typography consistent across Safari, Android, iOS and
/// desktop web while allowing compact layouts to fall back to the emblem area.
class MinistryHealthWordmark extends StatelessWidget {
  const MinistryHealthWordmark({
    super.key,
    this.width = 320,
    this.compact = false,
  });

  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return MinistryHealthEmblem(width: width);
    }
    return Semantics(
      label: 'Ministry of Health and Wellness Jamaica',
      image: true,
      child: SizedBox(
        width: width,
        height: width / 2.82,
        child: Image.asset(
          AppAssets.ministryLogo,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          errorBuilder: (_, __, ___) => _FallbackWordmark(width: width),
        ),
      ),
    );
  }
}

/// Compact emblem for places where the full horizontal Ministry wordmark would
/// be too small to remain readable. It uses the same supplied image and clips
/// only the emblem region; it does not attempt to recreate the official logo.
class MinistryHealthEmblem extends StatelessWidget {
  const MinistryHealthEmblem({super.key, this.width = 74});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ministry of Health and Wellness',
      image: true,
      child: SizedBox(
        width: width,
        height: width * .72,
        child: ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: SizedBox(
              width: width * 3.45,
              height: width * .72,
              child: Image.asset(
                AppAssets.ministryLogo,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.health_and_safety_rounded,
                  color: medqurGreen,
                  size: width * .58,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackWordmark extends StatelessWidget {
  const _FallbackWordmark({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(Icons.health_and_safety_rounded, color: medqurGreen, size: width * .13),
          SizedBox(width: width * .035),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MINISTRY OF',
                  style: TextStyle(color: Color(0xFF292625), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2),
                ),
                Text(
                  'HEALTH & WELLNESS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF292625), fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      );
}
