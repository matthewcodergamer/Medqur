import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

/// Prototype-only persistence. This is intentionally not a PHI/medical-record
/// datastore; production Medqur must use an approved encrypted backend.
class PatientStore {
  static const _key = 'medqur.prototype.patients.v2';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<List<Patient>?> load() async {
    final raw = await _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((item) => Patient.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> save(List<Patient> patients) async {
    final payload = jsonEncode(patients.map((patient) => patient.toJson()).toList());
    await _preferences.setString(_key, payload);
  }

  Future<void> reset() => _preferences.remove(_key);
}
