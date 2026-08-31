import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../models.dart';
import '../widgets/common.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.onSignedIn});
  final ValueChanged<StaffProfile> onSignedIn;
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _controller = TextEditingController(text: 'MQ-7K4P-92XF');
  StaffRole _role = StaffRole.doctor;
  bool _authenticating = false;

  Future<void> _signIn() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _authenticating = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    widget.onSignedIn(_role == StaffRole.doctor ? demoDoctor : demoNurse);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 860;
            if (wide) {
              return Row(children: [Expanded(child: _brandPanel()), Expanded(child: _formPanel(maxWidth: 500))]);
            }
            return _formPanel(maxWidth: 520, showBrandHeader: true);
          },
        ),
      ),
    );
  }

  Widget _brandPanel() => Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(44),
        decoration: BoxDecoration(color: const Color(0xFFF1F6FF), borderRadius: BorderRadius.circular(32)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MedqurLogo(width: 230),
            const Spacer(),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.health_and_safety_rounded, color: medqurBlue, size: 34),
            ),
            const SizedBox(height: 22),
            const Text('Connected care.\nSafer decisions.', style: TextStyle(fontSize: 38, height: 1.08, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: medqurInk)),
            const SizedBox(height: 16),
            const Text('A clinical workflow prototype for faster patient flow, clear medication orders, and secure identity verification.', style: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF5C6B7D))),
            const Spacer(),
            const Row(children: [Icon(Icons.lock_outline_rounded, size: 18, color: medqurGreen), SizedBox(width: 8), Text('Prototype uses simulated data only', style: TextStyle(color: Color(0xFF5C6B7D), fontWeight: FontWeight.w700))]),
          ],
        ),
      );

  Widget _formPanel({required double maxWidth, bool showBrandHeader = false}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showBrandHeader) ...[
                const Center(child: MedqurLogo(width: 190)),
                const SizedBox(height: 28),
              ],
              const FadeSlideIn(
                child: Row(children: [
                  MinistryLogo(size: 56),
                  SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Healthcare staff access', style: TextStyle(fontSize: 13, color: Color(0xFF738196), fontWeight: FontWeight.w700)),
                    SizedBox(height: 3),
                    Text('Medqur clinical workspace', style: TextStyle(fontSize: 17, color: medqurInk, fontWeight: FontWeight.w800)),
                  ])),
                ]),
              ),
              const SizedBox(height: 34),
              const FadeSlideIn(delay: Duration(milliseconds: 80), child: Text('Sign in for your shift', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: medqurInk, letterSpacing: -.8))),
              const SizedBox(height: 10),
              const FadeSlideIn(delay: Duration(milliseconds: 120), child: Text('Use your Medqur staff ID and device authentication. Your ID is an identifier, not your password.', style: TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF65748A)))),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Staff ID', prefixIcon: Icon(Icons.badge_outlined), hintText: 'MQ-7K4P-92XF'),
              ),
              const SizedBox(height: 14),
              SegmentedButton<StaffRole>(
                segments: const [
                  ButtonSegment(value: StaffRole.doctor, icon: Icon(Icons.medical_services_outlined), label: Text('Doctor demo')),
                  ButtonSegment(value: StaffRole.nurse, icon: Icon(Icons.medical_services_outlined), label: Text('Nurse demo')),
                ],
                selected: {_role},
                onSelectionChanged: (value) {
                  setState(() {
                    _role = value.first;
                    _controller.text = _role == StaffRole.doctor ? 'MQ-7K4P-92XF' : 'MQ-2N8R-41KD';
                  });
                },
                style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48), selectedBackgroundColor: const Color(0xFFEAF2FF), selectedForegroundColor: medqurBlue),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _authenticating ? null : _signIn,
                icon: _authenticating ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)) : const Icon(Icons.fingerprint_rounded),
                label: Text(_authenticating ? 'Authenticating…' : 'Continue with device authentication'),
              ),
              const SizedBox(height: 18),
              const Row(children: [Expanded(child: Divider(color: medqurLine)), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: Color(0xFF8390A2)))), Expanded(child: Divider(color: medqurLine))]),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _signIn,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan staff badge'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), side: const BorderSide(color: medqurLine), foregroundColor: medqurInk, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
              const SizedBox(height: 24),
              const Text('Demo authentication only. Production would use passkeys / device biometrics and Ministry-approved identity controls.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8793A4), fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}
