import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/medqur_controller.dart';
import '../theme/medqur_theme.dart';
import '../widgets/brand.dart';
import 'activity_screen.dart';
import 'queue_screen.dart';
import 'scan_screen.dart';
import 'staff_id_screen.dart';
import 'tasks_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.controller});

  final MedqurController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pages = [
          QueueScreen(controller: controller),
          ScanScreen(controller: controller),
          TasksScreen(controller: controller),
          ActivityScreen(controller: controller),
          StaffIdScreen(controller: controller),
        ];
        final wide = MediaQuery.sizeOf(context).width >= 900;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            titleSpacing: wide ? 24 : 16,
            title: Row(
              children: [
                const MedqurMark(size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medqur',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: MedqurColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        controller.activeFacility!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: MedqurColors.inkMuted,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (wide)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Center(
                    child: Text(
                      '${controller.profile.name} · ${controller.profile.roleLabel}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: MedqurColors.inkMuted,
                          ),
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'Account menu',
                onSelected: (value) {
                  if (value == 'change') {
                    controller.clearFacility();
                  }
                  if (value == 'signout') controller.signOut();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'change', child: Text('Change facility')),
                  PopupMenuItem(value: 'signout', child: Text('Sign out')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFEFF5FF),
                    child: Text(
                      controller.profile.name.split(' ').last.substring(0, 1),
                      style: const TextStyle(
                        color: MedqurColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1),
            ),
          ),
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: controller.tabIndex,
                      onDestinationSelected: controller.selectTab,
                      labelType: NavigationRailLabelType.all,
                      groupAlignment: -0.75,
                      destinations: _railDestinations(controller.role),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: IndexedStack(index: controller.tabIndex, children: pages),
                    ),
                  ],
                )
              : IndexedStack(index: controller.tabIndex, children: pages),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: controller.tabIndex,
                  onDestinationSelected: controller.selectTab,
                  destinations: _barDestinations(controller.role),
                ),
        );
      },
    );
  }

  static List<NavigationRailDestination> _railDestinations(StaffRole role) {
    return [
      const NavigationRailDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: Text('Queue'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.qr_code_scanner_outlined),
        selectedIcon: Icon(Icons.qr_code_scanner),
        label: Text('Scan'),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.medication_outlined),
        selectedIcon: const Icon(Icons.medication),
        label: Text(role == StaffRole.nurse ? 'Medication' : 'Orders'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: Text('Activity'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.badge_outlined),
        selectedIcon: Icon(Icons.badge),
        label: Text('Staff ID'),
      ),
    ];
  }

  static List<NavigationDestination> _barDestinations(StaffRole role) {
    return [
      const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Queue'),
      const NavigationDestination(icon: Icon(Icons.qr_code_scanner_outlined), selectedIcon: Icon(Icons.qr_code_scanner), label: 'Scan'),
      NavigationDestination(
        icon: const Icon(Icons.medication_outlined),
        selectedIcon: const Icon(Icons.medication),
        label: role == StaffRole.nurse ? 'Meds' : 'Orders',
      ),
      const NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Activity'),
      const NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge), label: 'ID'),
    ];
  }
}
