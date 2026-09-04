import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class DeviceAuthResult {
  const DeviceAuthResult({
    required this.success,
    required this.supported,
    required this.message,
  });

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
        message:
            'Secure browser passkey verification needs the Medqur relying-party backend. Native Android and iOS use device biometrics.',
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
          message:
              'No enrolled biometric is available. Medqur does not fall back to the phone PIN, pattern or passcode; enroll fingerprint, Face ID or Touch ID first.',
        );
      }

      final method = _biometricLabel(biometrics);
      final ok = await auth.authenticate(
        localizedReason: 'Verify $staffId to start the Medqur clinical shift',
        // Native clinical unlock is intentionally biometric-only. When a phone
        // has fingerprint/Face ID/Touch ID enrolled, Android/iOS must not replace
        // this prompt with the device PIN, pattern or passcode.
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      return DeviceAuthResult(
        success: ok,
        supported: true,
        message: ok
            ? '$method verified.'
            : '$method authentication was cancelled. Device passcode fallback is disabled.',
      );
    } catch (error) {
      return DeviceAuthResult(
        success: false,
        supported: true,
        message:
            'Biometric authentication failed: $error. Medqur will not fall back to the device passcode.',
      );
    }
  }

  static String _biometricLabel(List<BiometricType> biometrics) {
    final hasFace = biometrics.contains(BiometricType.face);
    final hasFingerprint = biometrics.contains(BiometricType.fingerprint);

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (hasFace) return 'Face ID';
      if (hasFingerprint) return 'Touch ID';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (hasFingerprint) return 'Fingerprint';
      if (hasFace) return 'Face authentication';
    }
    if (hasFingerprint) return 'Fingerprint';
    if (hasFace) return 'Face authentication';
    return 'Device biometric';
  }
}
