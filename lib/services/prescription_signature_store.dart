import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/prescription_signature_pad.dart';

class PrescriptionSignatureStore {
  static const _prefix = 'medqur_prescription_signature_v1_';

  Future<void> save({
    required String orderKey,
    required PrescriptionSignature signature,
    required String prescriberId,
    required String patientId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$orderKey',
      jsonEncode({
        'version': 1,
        'payload': signature.payload,
        'digest': signature.digest,
        'signedAt': signature.signedAt.toIso8601String(),
        'prescriberId': prescriberId,
        'patientId': patientId,
      }),
    );
  }

  Future<Map<String, dynamic>?> load(String orderKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$orderKey');
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }
}
