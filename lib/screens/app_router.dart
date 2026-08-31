import 'package:flutter/material.dart';

import '../state/medqur_controller.dart';
import 'facility_screen.dart';
import 'home_shell.dart';
import 'sign_in_screen.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key, required this.controller});

  final MedqurController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        Widget child;
        if (!controller.signedIn) {
          child = SignInScreen(controller: controller);
        } else if (controller.activeFacility == null) {
          child = FacilityScreen(controller: controller);
        } else {
          child = HomeShell(controller: controller);
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey('${controller.signedIn}-${controller.activeFacility?.name}'),
            child: child,
          ),
        );
      },
    );
  }
}
