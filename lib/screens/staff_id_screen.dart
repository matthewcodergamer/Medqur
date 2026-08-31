import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/medqur_controller.dart';
import '../theme/medqur_theme.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class StaffIdScreen extends StatelessWidget {
  const StaffIdScreen({super.key, required this.controller});

  final MedqurController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeading(
          title: 'Digital staff ID',
          subtitle: 'Credential display for quick identification — not a standalone login secret.',
        ),
        const SizedBox(height: 18),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF173F88), Color(0xFF3978E1)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: MedqurColors.primaryDark.withValues(alpha: .16),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const MedqurMark(size: 40),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'ACTIVE SHIFT',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.white,
                          child: Text(
                            profile.name.split(' ').last.substring(0, 1),
                            style: const TextStyle(
                              color: MedqurColors.primaryDark,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                profile.roleLabel,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: CustomPaint(painter: _DemoQrPainter(seed: profile.staffId.hashCode)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('STAFF ID', style: TextStyle(color: MedqurColors.inkMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(profile.staffId, style: const TextStyle(color: MedqurColors.navy, fontWeight: FontWeight.w800, fontSize: 18)),
                                const SizedBox(height: 8),
                                Text(profile.registration, style: const TextStyle(color: MedqurColors.inkMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      controller.activeFacility!.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    const Text('Credential QR is a demo signed identifier, not a password.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.fingerprint_rounded, color: MedqurColors.primaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'In production, Face ID / fingerprint should only unlock a device-bound cryptographic credential. Medqur should never receive or store the biometric template itself.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MedqurColors.inkMuted, height: 1.45),
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

class _DemoQrPainter extends CustomPainter {
  const _DemoQrPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    const cells = 17;
    final cell = size.width / cells;
    final paint = Paint()..color = MedqurColors.navy;

    for (var row = 0; row < cells; row++) {
      for (var col = 0; col < cells; col++) {
        final finder = (row < 5 && col < 5) || (row < 5 && col >= cells - 5) || (row >= cells - 5 && col < 5);
        final on = finder
            ? (row == 0 || col == 0 || row == 4 || col == 4 || (row >= 2 && row <= 3 && col >= 2 && col <= 3))
            : random.nextBool();
        if (on) {
          canvas.drawRect(Rect.fromLTWH(col * cell, row * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DemoQrPainter oldDelegate) => oldDelegate.seed != seed;
}
