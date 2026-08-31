import 'dart:async';
import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.patient,
    required this.onOpenPatient,
  });

  final Patient patient;
  final ValueChanged<Patient> onOpenPatient;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  String mode = 'Patient wristband';
  bool found = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void simulate() {
    setState(() => found = false);
    Timer(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => found = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('Scan', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text(
          'Use one scanner for patient identity, wristbands, staff badges, and medication checks.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              'Patient wristband',
              'NIDS / NIC demo',
              'Medication',
              'Staff badge',
            ])
              ChoiceChip(
                label: Text(item),
                selected: mode == item,
                onSelected: (_) => setState(() {
                  mode = item;
                  found = false;
                }),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AspectRatio(
              aspectRatio: 1.05,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1728),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withValues(alpha: .65), width: 2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (_, __) => Align(
                          alignment: Alignment(0, -0.62 + controller.value * 1.24),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 70),
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFF69A0FF),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF69A0FF).withValues(alpha: .5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 22,
                      right: 22,
                      top: 18,
                      child: Text(
                        'Camera preview simulated in prototype',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFB9C7D8), fontSize: 12),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      right: 22,
                      bottom: 22,
                      child: FilledButton.icon(
                        onPressed: simulate,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text('Simulate $mode scan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: found
              ? SoftCard(
                  key: const ValueKey('found'),
                  highlighted: true,
                  onTap: () => widget.onOpenPatient(widget.patient),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: medqurGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Match found',
                              style: TextStyle(color: medqurGreen, fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                            const SizedBox(height: 3),
                            Text(widget.patient.name, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900)),
                            Text(
                              '${widget.patient.id} • ${widget.patient.nidsStatus}',
                              style: const TextStyle(color: Color(0xFF748297), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 18),
        const SoftCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: medqurBlue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Production scanning would validate signed encounter tokens and authorized NIDS/NIC verification responses. No live government service is connected in this demo.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
