import 'package:flutter/material.dart';

import '../app_assets.dart';

/// Responsive Ministry of Health & Wellness lockup for the Medqur prototype.
///
/// The repository's ministry_health_logo.png is the coloured heart/health
/// emblem. The official-style wordmark is composed beside it in Flutter so it
/// remains sharp and correctly proportioned on web, Android and iOS instead of
/// squeezing the entire lockup into a tiny square.
class MinistryHealthWordmark extends StatelessWidget {
  const MinistryHealthWordmark({
    super.key,
    this.width = 320,
  });

  final double width;

  static const double _designWidth = 512;
  static const double _designHeight = 174;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * (_designHeight / _designWidth),
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: _designWidth,
          height: _designHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 174,
                child: Image.asset(
                  AppAssets.ministryLogo,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'M I N I S T R Y   O F',
                        maxLines: 1,
                        style: TextStyle(
                          color: Color(0xFF211F1E),
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'HEALTH &',
                        maxLines: 1,
                        style: TextStyle(
                          color: Color(0xFF211F1E),
                          fontSize: 45,
                          fontWeight: FontWeight.w900,
                          height: .86,
                          letterSpacing: -1.6,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'WELLNESS',
                        maxLines: 1,
                        style: TextStyle(
                          color: Color(0xFF211F1E),
                          fontSize: 45,
                          fontWeight: FontWeight.w900,
                          height: .86,
                          letterSpacing: -1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
