import 'package:flutter/material.dart';

import '../state/medqur_controller.dart';
import '../theme/medqur_theme.dart';
import '../widgets/common.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.controller});

  final MedqurController controller;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  late final AnimationController animationController;
  String scanMode = 'Patient wristband';
  bool resultVisible = false;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeading(
          title: 'Scan',
          subtitle: 'One scanner for patient wristbands, staff badges and medication barcodes.',
        ),
        const SizedBox(height: 18),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  color: const Color(0xFF0E1726),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _ScannerGridPainter()),
                      ),
                      Center(
                        child: SizedBox(
                          width: 240,
                          height: 180,
                          child: Stack(
                            children: [
                              Positioned.fill(child: CustomPaint(painter: _ScannerFramePainter())),
                              AnimatedBuilder(
                                animation: animationController,
                                builder: (context, _) {
                                  return Positioned(
                                    left: 10,
                                    right: 10,
                                    top: 20 + (130 * animationController.value),
                                    child: Container(
                                      height: 2,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF63A2FF),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF63A2FF).withValues(alpha: .4),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: Text(
                          'Camera access is simulated in this public prototype.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Patient wristband', 'Staff badge', 'Medication']
                          .map(
                            (mode) => ChoiceChip(
                              label: Text(mode),
                              selected: scanMode == mode,
                              onSelected: (_) => setState(() {
                                scanMode = mode;
                                resultVisible = false;
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => setState(() => resultVisible = true),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Text('Run demo $scanMode scan'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: resultVisible ? _ScanResult(mode: scanMode) : const SizedBox.shrink(),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: MedqurColors.primaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Patient wristband QR codes should contain a random encounter token, not diagnoses or other confidential medical information. The backend resolves the token only after staff authorization.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MedqurColors.inkMuted,
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanResult extends StatelessWidget {
  const _ScanResult({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      'Medication' => 'Medication matched',
      'Staff badge' => 'Staff credential recognized',
      _ => 'Patient encounter matched',
    };
    final detail = switch (mode) {
      'Medication' => 'Salbutamol 2.5 mg · barcode DEMO-7721',
      'Staff badge' => 'Dr. Maya Brown · MQ-7K4P-92XF · active credential',
      _ => 'Alicia Grant · ENC-26-0831-041 · identity verified',
    };

    return Card(
      key: ValueKey(mode),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFEDF8F2),
              child: Icon(Icons.check_rounded, color: MedqurColors.success),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: MedqurColors.navy, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(detail, style: const TextStyle(color: MedqurColors.inkMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: MedqurColors.primary),
          ],
        ),
      ),
    );
  }
}

class _ScannerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .035)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const length = 28.0;
    final path = Path()
      ..moveTo(0, length)
      ..lineTo(0, 0)
      ..lineTo(length, 0)
      ..moveTo(size.width - length, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, length)
      ..moveTo(size.width, size.height - length)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - length, size.height)
      ..moveTo(length, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height - length);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
