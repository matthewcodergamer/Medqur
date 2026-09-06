import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mock_data.dart';
import '../models.dart';
import '../services/browser_pin.dart';
import '../services/device_auth.dart';
import '../services/staff_identity.dart';
import '../widgets/common.dart';
import '../widgets/ministry_health_wordmark.dart';
import 'live_scanner_page.dart';

/// Sign-in screen with the same native biometric / browser-PIN boundaries as
/// V0.11, plus synthetic clinical-support workers for the new worklist demo.
class SignInScreenV2 extends StatefulWidget {
  const SignInScreenV2({super.key, required this.onSignedIn});
  final ValueChanged<StaffProfile> onSignedIn;

  @override
  State<SignInScreenV2> createState() => _SignInScreenV2State();
}

class _SignInScreenV2State extends State<SignInScreenV2> {
  final _controller = TextEditingController();
  final _deviceAuth = DeviceAuthService();
  final _browserPin = BrowserPinService();
  final _staffIdentity = StaffIdentityClient();
  bool _busy = false;

  StaffProfile? _resolve(String input) {
    final number = StaffBadgeCodec.normalizeStaffNumber(input);
    for (final staff in demoStaffProfiles) {
      if (staff.id == number) return staff;
    }
    return null;
  }

  Future<void> _continue() async {
    final number = StaffBadgeCodec.normalizeStaffNumber(_controller.text);
    if (!StaffBadgeCodec.isSixDigitStaffNumber(number)) {
      _message('Enter your 6-digit staff ID.');
      return;
    }
    final staff = _resolve(number);
    if (staff == null) {
      _message('This prototype build does not contain that staff ID.');
      return;
    }
    await _authenticate(staff);
  }

  Future<void> _authenticate(StaffProfile staff) async {
    if (kIsWeb) {
      await _authenticateWeb(staff);
      return;
    }
    setState(() => _busy = true);
    final result = await _deviceAuth.authenticate(staffId: staff.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.success) {
      widget.onSignedIn(staff);
    } else {
      _message(result.message);
    }
  }

  Future<void> _authenticateWeb(StaffProfile staff) async {
    setState(() => _busy = true);
    final hasPin = await _browserPin.hasPin(staff.id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!hasPin) {
      final pin = await _pinDialog(
        title: 'Create browser PIN',
        staff: staff,
        confirm: true,
      );
      if (pin == null || !mounted) return;
      setState(() => _busy = true);
      try {
        await _browserPin.setPin(staffId: staff.id, pin: pin);
      } on Object catch (error) {
        if (mounted) _message('Browser PIN could not be saved: $error');
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (mounted) widget.onSignedIn(staff);
      return;
    }

    final pin = await _pinDialog(
      title: 'Unlock browser session',
      staff: staff,
      confirm: false,
    );
    if (pin == null || !mounted) return;
    setState(() => _busy = true);
    final result = await _browserPin.verify(staffId: staff.id, pin: pin);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.success) {
      widget.onSignedIn(staff);
    } else {
      _message(result.message);
    }
  }

  Future<String?> _pinDialog({
    required String title,
    required StaffProfile staff,
    required bool confirm,
  }) async {
    final pin = TextEditingController();
    final confirmation = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: !confirm,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 330,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${staff.name} • ${staff.id}',
                  style: const TextStyle(
                    color: Color(0xFF687587),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pin,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(BrowserPinService.pinLength),
                  ],
                  decoration: const InputDecoration(
                    labelText: '6-digit PIN',
                    counterText: '',
                  ),
                  maxLength: BrowserPinService.pinLength,
                ),
                if (confirm) ...[
                  const SizedBox(height: 9),
                  TextField(
                    controller: confirmation,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(BrowserPinService.pinLength),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Confirm PIN',
                      counterText: '',
                    ),
                    maxLength: BrowserPinService.pinLength,
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 7),
                  Text(error!,
                      style: const TextStyle(color: medqurRed, fontSize: 11.5)),
                ],
                if (confirm) ...[
                  const SizedBox(height: 9),
                  const Text(
                    'Prototype browser guard only. Production web access uses approved OIDC/WebAuthn/passkeys.',
                    style: TextStyle(
                      color: Color(0xFF7A8798),
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (pin.text.length != BrowserPinService.pinLength) {
                  setDialogState(() => error = 'Use exactly six digits.');
                  return;
                }
                if (confirm && pin.text != confirmation.text) {
                  setDialogState(() => error = 'The PINs do not match.');
                  return;
                }
                Navigator.pop(dialogContext, pin.text);
              },
              child: Text(confirm ? 'Create PIN' : 'Unlock'),
            ),
          ],
        ),
      ),
    );
    pin.dispose();
    confirmation.dispose();
    return result;
  }

  Future<void> _chooseDemo() async {
    final staff = await showModalBottomSheet<StaffProfile>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .72,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            children: [
              const Text(
                'Demo health workers',
                style: TextStyle(
                  color: medqurInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Synthetic identities for testing doctor, nursing, pharmacy, X-ray, CT, laboratory and ECG workflows.',
                style: TextStyle(color: Color(0xFF718095), fontSize: 11.5),
              ),
              const SizedBox(height: 8),
              for (final item in demoStaffProfiles)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                  title: Text(item.name),
                  subtitle: Text('${item.title} • ${item.id}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(sheetContext, item),
                ),
            ],
          ),
        ),
      ),
    );
    if (staff != null) _controller.text = staff.id;
  }

  Future<void> _scanBadge() async {
    final capture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(
        builder: (_) => const LiveScannerPage(purpose: ScanPurpose.staffBadge),
      ),
    );
    if (capture == null || !mounted) return;

    final raw = capture.value.trim();
    if (StaffBadgeCodec.looksSigned(raw) && _staffIdentity.isConfigured) {
      setState(() => _busy = true);
      final verification = await _staffIdentity.verifyBadge(raw);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!verification.valid) {
        _message(verification.error ?? 'Staff badge verification failed.');
        return;
      }
      final staff = _profileFromVerification(verification);
      if (staff == null) {
        _message('Verified role is not supported by this prototype.');
        return;
      }
      _controller.text = staff.id;
      await _authenticate(staff);
      return;
    }

    final number = StaffBadgeCodec.prototypeStaffNumber(raw);
    final staff = number == null ? null : _resolve(number);
    if (staff == null) {
      _message('The scanned code is not a registered prototype staff badge.');
      return;
    }
    _controller.text = staff.id;
    await _authenticate(staff);
  }

  StaffProfile? _profileFromVerification(StaffBadgeVerification verification) {
    if (verification.permissions.isEmpty) return null;
    final roleName = verification.permissions.first.role;
    final role = switch (roleName) {
      'doctor' => StaffRole.doctor,
      'pharmacist' || 'pharmacy_technician' => StaffRole.pharmacist,
      'nurse' ||
      'triage_nurse' ||
      'radiology_technologist' ||
      'ct_technologist' ||
      'mri_technologist' ||
      'lab_technologist' ||
      'ecg_technician' ||
      'respiratory_therapist' ||
      'sonographer' ||
      'clinical_support' => StaffRole.nurse,
      _ => null,
    };
    if (role == null) return null;

    final title = switch (roleName) {
      'doctor' => 'Medical Officer',
      'nurse' => 'Registered Nurse',
      'triage_nurse' => 'Triage Nurse',
      'pharmacist' => 'Pharmacist',
      'pharmacy_technician' => 'Pharmacy Technician',
      'radiology_technologist' => 'Radiography Technologist',
      'ct_technologist' => 'CT Technologist',
      'mri_technologist' => 'MRI Technologist',
      'lab_technologist' => 'Medical Laboratory Technologist',
      'ecg_technician' => 'ECG Technician',
      'respiratory_therapist' => 'Respiratory Therapist',
      'sonographer' => 'Sonographer',
      _ => 'Clinical Support',
    };

    final facilityIds = verification.permissions
        .map((permission) => permission.facilityId)
        .toSet();
    final assigned = facilities
        .where((facility) => facilityIds.contains(facility.id))
        .toList();

    return StaffProfile(
      id: verification.staffNumber,
      name: verification.displayName.isEmpty
          ? 'Verified health worker'
          : verification.displayName,
      role: role,
      title: title,
      registration: verification.professionalRegistration,
      facilities: assigned.isEmpty ? facilities : assigned,
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
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
    final primaryLabel = kIsWeb ? 'Unlock browser' : 'Use Face ID / fingerprint';
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: MedqurLogo(width: 150)),
                  const SizedBox(height: 18),
                  const Center(child: MinistryHealthWordmark(width: 235)),
                  const SizedBox(height: 30),
                  Text(
                    'Staff sign in',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your health-worker ID to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF687587), fontSize: 13),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    maxLength: 6,
                    onSubmitted: (_) => _continue(),
                    decoration: const InputDecoration(
                      labelText: '6-digit Staff ID',
                      counterText: '',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 11),
                  FilledButton.icon(
                    onPressed: _busy ? null : _continue,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(kIsWeb ? Icons.pin_outlined : Icons.fingerprint_rounded),
                    label: Text(_busy ? 'Verifying…' : primaryLabel),
                  ),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _scanBadge,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan staff QR'),
                  ),
                  const SizedBox(height: 5),
                  TextButton(
                    onPressed: _busy ? null : _chooseDemo,
                    child: const Text('Choose demo health worker'),
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
