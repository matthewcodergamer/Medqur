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

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.onSignedIn});
  final ValueChanged<StaffProfile> onSignedIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _controller = TextEditingController();
  final _deviceAuth = DeviceAuthService();
  final _browserPin = BrowserPinService();
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
      _message('Enter your 6-digit staff ID.');
      return;
    }
    final staff = _resolveStaff(number);
    if (staff == null) {
      _message(
        _staffIdentity.isConfigured
            ? 'This staff ID is not available in the local profile cache. Scan the signed staff QR or use the production identity service.'
            : 'This prototype build does not contain that staff ID.',
      );
      return;
    }
    await _authenticateStaff(staff);
  }

  Future<void> _authenticateStaff(StaffProfile staff) async {
    if (kIsWeb) {
      await _authenticateBrowser(staff);
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
    _message(result.message);
  }

  Future<void> _authenticateBrowser(StaffProfile staff) async {
    setState(() => _authenticating = true);
    final hasPin = await _browserPin.hasPin(staff.id);
    if (!mounted) return;
    setState(() => _authenticating = false);

    if (!hasPin) {
      final pin = await _showPinSetup(staff);
      if (pin == null || !mounted) return;
      setState(() => _authenticating = true);
      try {
        await _browserPin.setPin(staffId: staff.id, pin: pin);
      } on Object catch (error) {
        if (mounted) _message('Browser PIN could not be saved: $error');
        return;
      } finally {
        if (mounted) setState(() => _authenticating = false);
      }
      if (mounted) widget.onSignedIn(staff);
      return;
    }

    final pin = await _showPinEntry(staff);
    if (pin == null || !mounted) return;
    setState(() => _authenticating = true);
    final result = await _browserPin.verify(staffId: staff.id, pin: pin);
    if (!mounted) return;
    setState(() => _authenticating = false);
    if (result.success) {
      widget.onSignedIn(staff);
    } else {
      _message(result.message);
    }
  }

  Future<String?> _showPinSetup(StaffProfile staff) async {
    final pin = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final value = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create browser PIN'),
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
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pin,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: BrowserPinService.pinLength,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(BrowserPinService.pinLength),
                  ],
                  decoration: const InputDecoration(
                    labelText: '6-digit PIN',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirm,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: BrowserPinService.pinLength,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(BrowserPinService.pinLength),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
                    counterText: '',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: const TextStyle(color: medqurRed, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'This PIN protects the local prototype browser session. Production web access will use an approved passkey/OIDC service rather than a locally stored PIN.',
                  style: TextStyle(
                    color: Color(0xFF7A8798),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
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
                if (pin.text != confirm.text) {
                  setDialogState(() => error = 'The PINs do not match.');
                  return;
                }
                Navigator.pop(dialogContext, pin.text);
              },
              child: const Text('Create PIN'),
            ),
          ],
        ),
      ),
    );
    pin.dispose();
    confirm.dispose();
    return value;
  }

  Future<String?> _showPinEntry(StaffProfile staff) async {
    final pin = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unlock browser session'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${staff.name} • ${staff.id}',
                style: const TextStyle(
                  color: Color(0xFF687587),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pin,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: BrowserPinService.pinLength,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(BrowserPinService.pinLength),
                ],
                decoration: const InputDecoration(
                  labelText: 'Browser PIN',
                  counterText: '',
                ),
                onSubmitted: (value) {
                  if (value.length == BrowserPinService.pinLength) {
                    Navigator.pop(dialogContext, value);
                  }
                },
              ),
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
              if (pin.text.length == BrowserPinService.pinLength) {
                Navigator.pop(dialogContext, pin.text);
              }
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    pin.dispose();
    return value;
  }

  Future<void> _chooseDemo() async {
    final staff = await showModalBottomSheet<StaffProfile>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Demo staff',
                  style: TextStyle(
                    color: medqurInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final item in [demoDoctor, demoNurse, demoPharmacist])
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
    if (staff == null || !mounted) return;
    _controller.text = staff.id;
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
          'This signed staff badge needs the Medqur identity service before it can be trusted.',
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
        _message('This verified clinical role is not supported by this screen.');
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
    final actionLabel = kIsWeb ? 'Unlock browser' : 'Use Face ID / fingerprint';
    final actionIcon = kIsWeb ? Icons.pin_outlined : Icons.fingerprint_rounded;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: MedqurLogo(width: 152)),
                  const SizedBox(height: 20),
                  const Center(child: MinistryHealthWordmark(width: 245)),
                  const SizedBox(height: 34),
                  Text(
                    'Staff sign in',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.6,
                        ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Enter your health-worker ID to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF687587),
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: [
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
                  FilledButton.icon(
                    onPressed: _authenticating ? null : _continue,
                    icon: _authenticating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(actionIcon),
                    label: Text(_authenticating ? 'Verifying…' : actionLabel),
                  ),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: _authenticating ? null : _scanBadge,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan staff QR'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _authenticating ? null : _chooseDemo,
                    child: const Text('Use demo account'),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE3E7EC)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 17,
                          color: Color(0xFF4B596A),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            kIsWeb
                                ? 'Browser builds use a 6-digit local session PIN in this prototype. Production web access requires approved passkey/OIDC authentication.'
                                : 'iPhone/iPad use Face ID or Touch ID when enrolled. Android uses the device biometric prompt for fingerprint or supported face authentication.',
                            style: const TextStyle(
                              color: Color(0xFF707C8B),
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Medqur prototype • no production patient credentials',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9AA3AF),
                      fontSize: 10.5,
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
