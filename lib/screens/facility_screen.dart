import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';
import '../widgets/medqur_responsive.dart';
import 'facility_directory_page.dart';

class FacilityScreen extends StatefulWidget {
  const FacilityScreen({
    super.key,
    required this.staff,
    required this.onBack,
    required this.onStartShift,
  });

  final StaffProfile staff;
  final VoidCallback onBack;
  final ValueChanged<Facility> onStartShift;

  @override
  State<FacilityScreen> createState() => _FacilityScreenState();
}

class _FacilityScreenState extends State<FacilityScreen> {
  Facility? selected;

  @override
  void initState() {
    super.initState();
    selected = widget.staff.facilities.firstWhere(
      (f) => f.suggested,
      orElse: () => widget.staff.facilities.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggested = widget.staff.facilities.firstWhere(
      (f) => f.suggested,
      orElse: () => widget.staff.facilities.first,
    );
    final phone = MedqurResponsive.isPhone(context);
    final tiny = MedqurResponsive.isTiny(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: SingleChildScrollView(
              padding: MedqurResponsive.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Spacer(),
                      MedqurLogo(width: tiny ? 105 : 135),
                    ],
                  ),
                  SizedBox(height: phone ? 22 : 30),
                  Text(
                    'Welcome, ${widget.staff.name}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Choose your facility for this shift.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF697585),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SoftCard(
                    highlighted: true,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 390;
                        return Row(
                          children: [
                            Container(
                              width: narrow ? 42 : 48,
                              height: narrow ? 42 : 48,
                              decoration: BoxDecoration(
                                color: medqurBlue.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.near_me_rounded,
                                color: medqurBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Suggested',
                                    style: TextStyle(
                                      color: medqurBlue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    suggested.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: medqurInk,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${suggested.classification.shortLabel} • ${suggested.area}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF748297),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!narrow)
                              const Icon(
                                Icons.verified_rounded,
                                color: medqurGreen,
                                size: 20,
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FacilityDirectoryPage(),
                      ),
                    ),
                    icon: const Icon(Icons.account_tree_outlined),
                    label: Text(phone ? 'Facility directory' : 'Browse public facility directory'),
                  ),
                  const SizedBox(height: 22),
                  const SectionTitle('Authorized facilities'),
                  const SizedBox(height: 5),
                  const CompactHelperText(
                    'Only facilities assigned to this staff profile can start a shift.',
                    maxLinesPhone: 2,
                  ),
                  const SizedBox(height: 11),
                  ResponsiveGrid(
                    minItemWidth: 310,
                    maxColumns: 2,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final facility in widget.staff.facilities)
                        _FacilityChoice(
                          facility: facility,
                          selected: selected?.id == facility.id,
                          onTap: () => setState(() => selected = facility),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: selected == null
                        ? null
                        : () => widget.onStartShift(selected!),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      selected == null
                          ? 'Select a facility'
                          : phone
                              ? 'Start shift'
                              : 'Start shift at ${selected!.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _FacilityChoice extends StatelessWidget {
  const _FacilityChoice({
    required this.facility,
    required this.selected,
    required this.onTap,
  });

  final Facility facility;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = facility.isHealthCentre ? medqurGreen : medqurBlue;
    return SoftCard(
      highlighted: selected,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              facility.isHealthCentre
                  ? Icons.local_hospital_outlined
                  : Icons.apartment_rounded,
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facility.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: medqurInk,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${facility.classification.shortLabel} • ${facility.area}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF748297),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? medqurBlue : const Color(0xFFA0A8B2),
            size: 21,
          ),
        ],
      ),
    );
  }
}
