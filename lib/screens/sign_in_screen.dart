import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mock_data.dart';
import '../models.dart';
import '../services/device_auth.dart';
import '../services/staff_identity.dart';
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
  final _staffIdentity = StaffIdentityClient();
  bool _authenticating = false;

  StaffProfile? _resolveStaff(String input) {
    final id = StaffBadgeCodec.normalizeStaffNumber(input);
    if (id == demoDoctor.id) return demoDoctor;
    if (id == demoNurse.id) return demoNurse;
    if (id == demoPharmacist.id) return demoPharmacist;
    return null;
  }

  Future<void> _continue() async {
    final number = StaffBadgeCodec.normalizeStaffNumber(_controller.text);
    if (!StaffBadgeCodec.isSixDigitStaffNumber(number)) {
      _message('Staff ID must contain exactly six digits.');
      return;
    }
    final staff = _resolveStaff(number);
    if (staff == null) {
      _message(
        _staffIdentity.isConfigured
            ? 'This six-digit ID is not in the local prototype profile cache. Scan the worker’s signed staff QR or use the production identity sign-in flow.'
            : 'Enter one of the registered six-digit Medqur prototype staff IDs.',
      );
      return;
    }
    await _authenticateStaff(staff);
  }

  Future<void> _authenticateStaff(StaffProfile staff) async {
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
            'The staff QR can be scanned and cryptographically checked by the configured identity service. Production browser sign-in still needs the government/Medqur passkey or OIDC service, so this public prototype does not claim that a browser biometric occurred.',
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

    final raw = capture.value.trim();
    if (StaffBadgeCodec.looksSigned(raw)) {
      if (!_staffIdentity.isConfigured) {
        _message(
          'This is a signed Medqur staff badge, but MEDQUR_IDENTITY_API_BASE is not configured in this build, so the signature cannot be trusted yet.',
        );
        return;
      }
      setState(() => _authenticating = true);
      final verification = await _staffIdentity.verifyBadge(raw);
      if (!mounted) return;
      setState(() => _authenticating = false);
      if (!verification.valid) {
        _message(verification.error ?? 'Staff badge could not be verified.');
        return;
      }
      final staff = _profileFromVerification(verification);
      if (staff == null) {
        _message('The badge is valid, but its clinical role is not supported by this prototype screen yet.');
        return;
      }
      _controller.text = verification.staffNumber;
      await _authenticateStaff(staff);
      return;
    }

    final number = StaffBadgeCodec.prototypeStaffNumber(raw);
    if (number == null) {
      _message('The scanned code is not a recognized Medqur staff badge.');
      return;
    }
    _controller.text = number;
    final staff = _resolveStaff(number);
    if (staff == null) {
      _message('Prototype staff badge is not registered on this device.');
      return;
    }
    await _authenticateStaff(staff);
  }

  StaffProfile? _profileFromVerification(StaffBadgeVerification verification) {
    StaffRole? role;
    for (final permission in verification.permissions) {
      role ??= switch (permission.role) {
        'doctor' => StaffRole.doctor,
        'nurse' || 'triage_nurse' => StaffRole.nurse,
        'pharmacist' || 'pharmacy_technician' => StaffRole.pharmacist,
        _ => null,
      };
      if (role != null) break;
    }
    if (role == null) return null;

    final facilityIds = verification.permissions
        .map((permission) => permission.facilityId)
        .where((value) => value.isNotEmpty)
        .toSet();
    final assignedFacilities = facilities
        .where((facility) => facilityIds.contains(facility.id))
        .toList(growable: false);

    return StaffProfile(
      id: verification.staffNumber,
      name: verification.displayName.isEmpty
          ? 'Verified health worker'
          : verification.displayName,
      role: role,
      title: switch (role) {
        StaffRole.doctor => 'Medical Officer',
        StaffRole.nurse => 'Registered Nurse',
        StaffRole.pharmacist => 'Pharmacist',
      },
      registration: verification.professionalRegistration,
      facilities: assignedFacilities.isEmpty ? facilities : assignedFacilities,
    );
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
    _staffIdentity.dispose();
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
                                Icon(Icons.health_and_safety_outlined, size: 15, color: medqurGreen),
                                SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    'Jamaica • healthcare staff access',
                                    style: TextStyle(color: Color(0xFF748297), fontSize: 12, fontWeight: FontWeight.w600),
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
                          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: medqurInk, letterSpacing: -1),
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Use your unique 6-digit health-worker ID, or scan your signed staff QR.',
                        style: TextStyle(fontSize: 15, color: Color(0xFF65748A)),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _controller,
                        keyboardType: TextInputType.number,
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: const [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onSubmitted: (_) => _continue(),
                        decoration: const InputDecoration(
                          labelText: '6-digit Staff ID',
                          hintText: '482731',
                          counterText: '',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        maxLength: 6,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _controller.text = demoDoctor.id),
                            child: const Text('Demo doctor'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _controller.text = demoNurse.id),
                            child: const Text('Demo nurse'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _controller.text = demoPharmacist.id),
                            child: const Text('Demo pharmacist'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _authenticating ? null : _continue,
                        icon: _authenticating
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : const Icon(Icons.fingerprint_rounded),
                        label: Text(_authenticating ? 'Verifying…' : 'Verify & continue'),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _authenticating ? null : _scanBadge,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan secure staff QR'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          foregroundColor: medqurInk,
                          side: const BorderSide(color: medqurLine),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SoftCard(
                        padding: EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_user_outlined, size: 18, color: medqurGreen),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Signed staff QR credentials are verified server-side for signature, expiry, revocation and active employment. The QR does not carry the worker’s name, role, registration, facility or patient data. Badge verification is followed by device biometric/passkey authentication.',
                                style: TextStyle(color: Color(0xFF65748A), fontSize: 11.5, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, color: medqurGreen, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Prototype identities only',
                            style: TextStyle(color: Color(0xFF8793A4), fontSize: 12, fontWeight: FontWeight.w700),
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
