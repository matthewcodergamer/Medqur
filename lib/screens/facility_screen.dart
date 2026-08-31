import 'package:flutter/material.dart';

import '../models/demo_data.dart';
import '../models/models.dart';
import '../state/medqur_controller.dart';
import '../theme/medqur_theme.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class FacilityScreen extends StatefulWidget {
  const FacilityScreen({super.key, required this.controller});

  final MedqurController controller;

  @override
  State<FacilityScreen> createState() => _FacilityScreenState();
}

class _FacilityScreenState extends State<FacilityScreen> {
  Facility selected = facilities.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const MedqurLogo(height: 42),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: widget.controller.signOut,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const PrototypePill(),
                  const SizedBox(height: 18),
                  Text(
                    'Start your shift',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: MedqurColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.controller.profile.name} · choose the facility where you are working now.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: MedqurColors.inkMuted,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF8F2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFCDEAD9)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: MedqurColors.success),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Suggested by device location',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: MedqurColors.success,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Mandeville Regional Hospital',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: MedqurColors.navy,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.verified_rounded, color: MedqurColors.success),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...facilities.map((facility) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FacilityTile(
                          facility: facility,
                          selected: selected.name == facility.name,
                          onTap: () => setState(() => selected = facility),
                        ),
                      )),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => widget.controller.startShift(selected),
                    icon: const Icon(Icons.login_rounded),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text('Start shift at ${selected.name}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Location is a convenience signal only. Staff authorization is still controlled by role and facility privileges.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MedqurColors.inkMuted,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FacilityTile extends StatelessWidget {
  const _FacilityTile({
    required this.facility,
    required this.selected,
    required this.onTap,
  });

  final Facility facility;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF2F7FF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? MedqurColors.primary : MedqurColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MedqurColors.border),
                ),
                child: Icon(
                  facility.type.contains('hospital') ? Icons.local_hospital_outlined : Icons.health_and_safety_outlined,
                  color: MedqurColors.primaryDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facility.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: MedqurColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${facility.type} · ${facility.parish}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: MedqurColors.inkMuted,
                          ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: selected
                    ? const Icon(Icons.check_circle_rounded, key: ValueKey('yes'), color: MedqurColors.primary)
                    : const Icon(Icons.circle_outlined, key: ValueKey('no'), color: MedqurColors.border),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
