import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../models.dart';
import '../services/device_auth.dart';
import '../widgets/common.dart';
import '../widgets/ministry_health_wordmark.dart';
import 'live_scanner_page.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.onSignedIn});
  final ValueChanged<StaffProfile> onSignedIn;
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _controller = TextEditingController();
  final _deviceAuth = DeviceAuthService();
  bool _authenticating = false;

  StaffProfile? _resolveStaff(String input) {
    final id = input.trim().toUpperCase();
    if (id == demoDoctor.id) return demoDoctor;
    if (id == demoNurse.id) return demoNurse;
    return null;
  }

  Future<void> _continue() async {
    final staff = _resolveStaff(_controller.text);
    if (staff == null) {
      _message('Enter a valid Medqur staff ID.');
      return;
    }
    setState(() => _authenticating = true);
    final result = await _deviceAuth.authenticate(staffId: staff.id);
    if (!mounted) return;
    setState(() => _authenticating = false);

    if (result.success) {
      widget.onSignedIn(staff);
      return;
    }
    if (kIsWeb && !result.supported) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.key_rounded, color: medqurBlue),
          title: const Text('Browser prototype'),
          content: const Text(
            'Camera scanning works in the web build. Secure browser passkeys need the Medqur authentication server, so this public prototype cannot pretend a biometric check succeeded.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue prototype'),
            ),
          ],
        ),
      );
      if (proceed == true && mounted) widget.onSignedIn(staff);
      return;
    }
    _message(result.message);
  }

  Future<void> _scanBadge() async {
    final capture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(
        builder: (_) => const LiveScannerPage(
          purpose: ScanPurpose.staffBadge,
        ),
      ),
    );
    if (capture == null || !mounted) return;
    var value = capture.value.trim();
    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.scheme == 'medqur' &&
        uri.host == 'staff' &&
        uri.pathSegments.isNotEmpty) {
      value = uri.pathSegments.last;
    }
    _controller.text = value.toUpperCase();
    await _continue();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 40 : 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: MedqurLogo(width: wide ? 215 : 188)),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          border: Border.all(color: medqurLine),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, logoConstraints) {
                                final logoWidth = logoConstraints.maxWidth > 340
                                    ? 340.0
                                    : logoConstraints.maxWidth;
                                return MinistryHealthWordmark(width: logoWidth);
                              },
                            ),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(
                                  Icons.health_and_safety_outlined,
                                  size: 15,
                                  color: medqurGreen,
                                ),
                                SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    'Jamaica • healthcare staff access',
                                    style: TextStyle(
                                      color: Color(0xFF748297),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const FadeSlideIn(
                        child: Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: medqurInk,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Enter your staff ID, then verify on this device.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF65748A),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        enableSuggestions: false,
                        onSubmitted: (_) => _continue(),
                        decoration: const InputDecoration(
                          labelText: 'Staff ID',
                          hintText: 'MQ-XXXX-XXXX',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(
                            () => _controller.text = demoDoctor.id,
                          ),
                          child: const Text('Use demo ID'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _authenticating ? null : _continue,
                        icon: _authenticating
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.fingerprint_rounded),
                        label: Text(
                          _authenticating ? 'Verifying…' : 'Verify & continue',
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _authenticating ? null : _scanBadge,
                        icon: const Icon(Icons.badge_outlined),
                        label: const Text('Scan staff ID'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          foregroundColor: medqurInk,
                          side: const BorderSide(color: medqurLine),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: medqurGreen,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Prototype data only',
                            style: TextStyle(
                              color: Color(0xFF8793A4),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
