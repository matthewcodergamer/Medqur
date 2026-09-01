import 'package:flutter/material.dart';

import '../app_assets.dart';

/// Ministry of Health & Wellness lockup used by the Medqur prototype.
///
/// The official ministry material uses the green heart/ECG emblem with the
/// yellow/black human figure beside the stacked MINISTRY OF / HEALTH & /
/// WELLNESS wordmark. The asset is kept at its natural proportions and the
/// text is laid out separately so Flutter never stretches or crushes the logo
/// on narrow mobile screens.
class MinistryHealthWordmark extends StatelessWidget {
  const MinistryHealthWordmark({super.key, this.width = 320});

  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * .31;
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: width * .35,
            height: height,
            child: Image.asset(
              AppAssets.ministryLogo,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.favorite_rounded, color: Color(0xFF119447), size: 52),
              ),
            ),
          ),
          SizedBox(width: width * .025),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: const SizedBox(
                width: 300,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'M I N I S T R Y   O F',
                      maxLines: 1,
                      style: TextStyle(
                        color: Color(0xFF211F1E),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'HEALTH &',
                      maxLines: 1,
                      style: TextStyle(
                        color: Color(0xFF211F1E),
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: .92,
                        letterSpacing: -1.1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'WELLNESS',
                      maxLines: 1,
                      style: TextStyle(
                        color: Color(0xFF211F1E),
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: .92,
                        letterSpacing: -1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
