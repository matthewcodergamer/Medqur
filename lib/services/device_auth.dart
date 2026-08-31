import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class DeviceAuthResult {
  const DeviceAuthResult({required this.success, required this.supported, required this.message});
  final bool success;
  final bool supported;
  final String message;
}

class DeviceAuthService {
  LocalAuthentication? _auth;

  Future<DeviceAuthResult> authenticate({required String staffId}) async {
    if (kIsWeb) {
      return const DeviceAuthResult(
        success: false,
        supported: false,
        message: 'Secure browser passkey verification needs the Medqur relying-party backend. Native Android and iOS use real device biometrics in V0.2.',
      );
    }

    final auth = _auth ??= LocalAuthentication();
    try {
      final supported = await auth.isDeviceSupported();
      final biometrics = await auth.getAvailableBiometrics();
      if (!supported || biometrics.isEmpty) {
        return const DeviceAuthResult(
          success: false,
          supported: false,
          message: 'No enrolled fingerprint or face authentication is available on this device.',
        );
      }
      final ok = await auth.authenticate(
        localizedReason: 'Verify $staffId to start the Medqur clinical shift',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return DeviceAuthResult(
        success: ok,
        supported: true,
        message: ok ? 'Device identity verified.' : 'Device authentication was cancelled.',
      );
    } catch (error) {
      return DeviceAuthResult(success: false, supported: true, message: 'Device authentication failed: $error');
    }
  }
}
