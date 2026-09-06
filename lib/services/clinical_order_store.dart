import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../clinical_models.dart';

/// Local prototype persistence for diagnostic/procedure orders.
///
/// Production deployments synchronize these records to the clinical backend;
/// large diagnostic media belongs in approved PACS/DICOM/object storage rather
/// than SharedPreferences.
class ClinicalOrderStore {
  const ClinicalOrderStore();

  static const _key = 'medqur_diagnostic_orders_v1';

  Future<List<DiagnosticOrder>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.trim().isEmpty) return <DiagnosticOrder>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <DiagnosticOrder>[];
      return decoded
          .whereType<Map>()
          .map((item) => DiagnosticOrder.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ))
          .toList();
    } catch (_) {
      return <DiagnosticOrder>[];
    }
  }

  Future<void> save(List<DiagnosticOrder> orders) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(orders.map((order) => order.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
