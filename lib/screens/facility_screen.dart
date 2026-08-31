import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';

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
    selected = widget.staff.facilities.firstWhere((f) => f.suggested, orElse: () => widget.staff.facilities.first);
  }

  @override
  Widget build(BuildContext context) {
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
                  Row(children: [IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)), const Spacer(), const MedqurLogo(width: 150)]),
                  const SizedBox(height: 34),
                  Text('Welcome, ${widget.staff.name}', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Choose where you are working today. Medqur can suggest a site from approved device/location signals, but you stay in control.'),
                  const SizedBox(height: 24),
                  SoftCard(
                    highlighted: true,
                    child: Row(children: [
                      Container(width: 48, height: 48, decoration: BoxDecoration(color: medqurBlue.withValues(alpha: .10), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.near_me_rounded, color: medqurBlue)),
                      const SizedBox(width: 14),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Suggested location', style: TextStyle(color: medqurBlue, fontSize: 12, fontWeight: FontWeight.w800)),
                        SizedBox(height: 4),
                        Text('Mandeville Regional Hospital', style: TextStyle(fontWeight: FontWeight.w800, color: medqurInk)),
                        SizedBox(height: 3),
                        Text('Based on approved workplace signal • Demo', style: TextStyle(color: Color(0xFF748297), fontSize: 13)),
                      ])),
                      const Icon(Icons.verified_rounded, color: medqurGreen),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  const SectionTitle('Authorized facilities'),
                  const SizedBox(height: 12),
                  ...widget.staff.facilities.map((facility) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SoftCard(
                      highlighted: selected?.id == facility.id,
                      onTap: () => setState(() => selected = facility),
                      child: Row(children: [
                        Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFF2F5FA), borderRadius: BorderRadius.circular(16)), child: Icon(facility.type.contains('Centre') ? Icons.local_hospital_outlined : Icons.apartment_rounded, color: medqurNavy)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(facility.name, style: const TextStyle(fontWeight: FontWeight.w800, color: medqurInk, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('${facility.type} • ${facility.area}', style: const TextStyle(color: Color(0xFF748297), fontSize: 13)),
                        ])),
                        Radio<String>(value: facility.id, groupValue: selected?.id, onChanged: (_) => setState(() => selected = facility)),
                      ]),
                    ),
                  )),
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
