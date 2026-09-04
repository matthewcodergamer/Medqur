import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BrowserPinResult {
  const BrowserPinResult({
    required this.success,
    required this.message,
    this.lockedUntil,
  });

  final bool success;
  final String message;
  final DateTime? lockedUntil;
}

/// Local browser session guard used by the public/prototype web build.
///
/// This is deliberately not described as production identity authentication.
/// A production Medqur browser deployment should use an approved OIDC/WebAuthn
/// relying party so the browser can authenticate with a passkey/security key.
class BrowserPinService {
  static const _prefix = 'medqur_browser_pin_v1_';
  static const pinLength = 6;
  static const maxAttempts = 5;
  static const lockDuration = Duration(minutes: 1);

  String _key(String staffId, String suffix) => '$_prefix${staffId}_$suffix';

  Future<bool> hasPin(String staffId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_key(staffId, 'hash')) ?? '').isNotEmpty &&
        (prefs.getString(_key(staffId, 'salt')) ?? '').isNotEmpty;
  }

  Future<void> setPin({required String staffId, required String pin}) async {
    _validatePin(pin);
    final prefs = await SharedPreferences.getInstance();
    final random = Random.secure();
    final saltBytes = List<int>.generate(24, (_) => random.nextInt(256));
    final salt = base64UrlEncode(saltBytes);
    final hash = _digest(staffId: staffId, salt: salt, pin: pin);
    await prefs.setString(_key(staffId, 'salt'), salt);
    await prefs.setString(_key(staffId, 'hash'), hash);
    await prefs.setInt(_key(staffId, 'attempts'), 0);
    await prefs.remove(_key(staffId, 'lockedUntil'));
  }

  Future<BrowserPinResult> verify({
    required String staffId,
    required String pin,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      return const BrowserPinResult(
        success: false,
        message: 'Enter your 6-digit browser PIN.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final lockValue = prefs.getString(_key(staffId, 'lockedUntil'));
    final lockedUntil = DateTime.tryParse(lockValue ?? '');
    final now = DateTime.now().toUtc();
    if (lockedUntil != null && now.isBefore(lockedUntil)) {
      final seconds = lockedUntil.difference(now).inSeconds.clamp(1, 60);
      return BrowserPinResult(
        success: false,
        message: 'Too many attempts. Try again in $seconds seconds.',
        lockedUntil: lockedUntil,
      );
    }

    final salt = prefs.getString(_key(staffId, 'salt')) ?? '';
    final stored = prefs.getString(_key(staffId, 'hash')) ?? '';
    if (salt.isEmpty || stored.isEmpty) {
      return const BrowserPinResult(
        success: false,
        message: 'No browser PIN is set for this staff profile.',
      );
    }

    final candidate = _digest(staffId: staffId, salt: salt, pin: pin);
    if (_constantTimeEquals(stored, candidate)) {
      await prefs.setInt(_key(staffId, 'attempts'), 0);
      await prefs.remove(_key(staffId, 'lockedUntil'));
      return const BrowserPinResult(
        success: true,
        message: 'Browser session unlocked.',
      );
    }

    final attempts = (prefs.getInt(_key(staffId, 'attempts')) ?? 0) + 1;
    if (attempts >= maxAttempts) {
      final until = now.add(lockDuration);
      await prefs.setInt(_key(staffId, 'attempts'), 0);
      await prefs.setString(_key(staffId, 'lockedUntil'), until.toIso8601String());
      return BrowserPinResult(
        success: false,
        message: 'Too many incorrect attempts. Browser access is locked for 1 minute.',
        lockedUntil: until,
      );
    }

    await prefs.setInt(_key(staffId, 'attempts'), attempts);
    return BrowserPinResult(
      success: false,
      message: 'Incorrect PIN. ${maxAttempts - attempts} attempts remaining.',
    );
  }

  String _digest({
    required String staffId,
    required String salt,
    required String pin,
  }) {
    return sha256.convert(utf8.encode('$staffId|$salt|$pin')).toString();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const FormatException('Browser PIN must be exactly six digits.');
    }
  }
}
