import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'facility_directory_page.dart';

class FacilityScreen extends StatefulWidget {
  const FacilityScreen({super.key, required this.staff, required this.onBack, required this.onStartShift});
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)),
                    const Spacer(),
                    const MedqurLogo(width: 150),
                  ]),
                  const SizedBox(height: 34),
                  Text('Welcome, ${widget.staff.name}', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose where you are working today. Medqur now carries Jamaica’s hospital A/B/C and health-centre Type 1–5 classifications with the facility context.',
                  ),
                  const SizedBox(height: 24),
                  SoftCard(
                    highlighted: true,
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: medqurBlue.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.near_me_rounded, color: medqurBlue),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text(
                            'Suggested location',
                            style: TextStyle(color: medqurBlue, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            suggested.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: medqurInk),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${suggested.classificationLabel} • ${suggested.area}',
                            style: const TextStyle(color: Color(0xFF748297), fontSize: 13),
                          ),
                        ]),
                      ),
                      const Icon(Icons.verified_rounded, color: medqurGreen),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FacilityDirectoryPage()),
                    ),
                    icon: const Icon(Icons.account_tree_outlined),
                    label: const Text('Browse Jamaica public facility directory'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      foregroundColor: medqurInk,
                      side: const BorderSide(color: medqurLine),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle('Authorized facilities'),
                  const SizedBox(height: 6),
                  const Text(
                    'The directory is informational. Starting a shift remains limited to facilities authorized for this staff profile.',
                    style: TextStyle(color: Color(0xFF748297), fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  ...widget.staff.facilities.map(
                    (facility) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SoftCard(
                        highlighted: selected?.id == facility.id,
                        onTap: () => setState(() => selected = facility),
                        child: Row(children: [
                          Container(
                            width: 54,
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: facility.isHealthCentre
                                  ? medqurGreen.withValues(alpha: .10)
                                  : medqurBlue.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                facility.isHealthCentre ? Icons.local_hospital_outlined : Icons.apartment_rounded,
                                size: 21,
                                color: facility.isHealthCentre ? medqurGreen : medqurBlue,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                facility.classification.shortLabel,
                                style: TextStyle(
                                  color: facility.isHealthCentre ? medqurGreen : medqurBlue,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(
                                facility.name,
                                style: const TextStyle(fontWeight: FontWeight.w800, color: medqurInk, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${facility.classificationLabel} • ${facility.area}',
                                style: const TextStyle(color: Color(0xFF748297), fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                facility.careLevel,
                                style: const TextStyle(color: Color(0xFF8793A4), fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ]),
                          ),
                          Radio<String>(
                            value: facility.id,
                            groupValue: selected?.id,
                            onChanged: (_) => setState(() => selected = facility),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: selected == null ? null : () => widget.onStartShift(selected!),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(selected == null ? 'Select a facility' : 'Start shift at ${selected!.name}'),
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
