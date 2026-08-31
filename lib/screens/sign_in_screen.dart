import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/medqur_controller.dart';
import '../theme/medqur_theme.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.controller});

  final MedqurController controller;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController staffIdController = TextEditingController();
  bool biometricBusy = false;

  @override
  void dispose() {
    staffIdController.dispose();
    super.dispose();
  }

  Future<void> quickUnlock() async {
    if (biometricBusy) return;
    setState(() => biometricBusy = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    widget.controller.signIn();
  }

  void signIn() {
    if (staffIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a staff ID or use the demo account.')),
      );
      return;
    }
    widget.controller.signIn();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 760;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 22 : 40,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: compact
                  ? _LoginCard(
                      controller: widget.controller,
                      staffIdController: staffIdController,
                      biometricBusy: biometricBusy,
                      onQuickUnlock: quickUnlock,
                      onSignIn: signIn,
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _IntroPanel(controller: widget.controller),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 420,
                          child: _LoginCard(
                            controller: widget.controller,
                            staffIdController: staffIdController,
                            biometricBusy: biometricBusy,
                            onQuickUnlock: quickUnlock,
                            onSignIn: signIn,
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

class _IntroPanel extends StatelessWidget {
  const _IntroPanel({required this.controller});

  final MedqurController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(34),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF173F88), Color(0xFF3978E1)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const MedqurLogo(height: 48),
          ),
          const SizedBox(height: 70),
          Text(
            'One secure clinical workflow from arrival to treatment.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.06,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            'A mobile-first concept for identity verification, triage, patient queues, clinical orders and closed-loop medication administration.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: .82),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 32),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _IntroTag(icon: Icons.badge_outlined, label: 'NIDS-ready identity layer'),
              _IntroTag(icon: Icons.qr_code_scanner, label: 'Scan-first workflows'),
              _IntroTag(icon: Icons.medication_outlined, label: 'Medication safety'),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntroTag extends StatelessWidget {
  const _IntroTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.controller,
    required this.staffIdController,
    required this.biometricBusy,
    required this.onQuickUnlock,
    required this.onSignIn,
  });

  final MedqurController controller;
  final TextEditingController staffIdController;
  final bool biometricBusy;
  final VoidCallback onQuickUnlock;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(alignment: Alignment.centerLeft, child: PrototypePill()),
            const SizedBox(height: 28),
            const MedqurLogo(height: 58),
            const SizedBox(height: 24),
            const MinistryBrand(),
            const SizedBox(height: 28),
            Text(
              'Secure staff access',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: MedqurColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Use a staff identifier and device-bound authentication. The biometric remains on the device.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MedqurColors.inkMuted,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: staffIdController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Staff ID',
                hintText: 'MQ-7K4P-92XF',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Demo role',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: MedqurColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 9),
            SegmentedButton<StaffRole>(
              segments: const [
                ButtonSegment(
                  value: StaffRole.doctor,
                  icon: Icon(Icons.stethoscope),
                  label: Text('Doctor'),
                ),
                ButtonSegment(
                  value: StaffRole.nurse,
                  icon: Icon(Icons.medical_services_outlined),
                  label: Text('Nurse'),
                ),
              ],
              selected: {controller.role},
              onSelectionChanged: (values) => controller.setRole(values.first),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Continue securely'),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: biometricBusy ? null : onQuickUnlock,
              icon: biometricBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fingerprint_rounded),
              label: Text(biometricBusy ? 'Checking device…' : 'Demo biometric unlock'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                staffIdController.text = controller.profile.staffId;
              },
              child: Text('Use ${controller.profile.name} demo account'),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: MedqurColors.inkMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This public demo uses mock identities, mock patients and simulated verification only.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: MedqurColors.inkMuted,
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
