import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Durable local prescription ledger used by the Flutter prototype.
///
/// A prescription is never silently overwritten. Amendments append a new
/// revision and mark the previous revision superseded, so doctors/pharmacy can
/// reopen the order and see who signed it and what changed.
class PrescriptionRecord {
  const PrescriptionRecord({
    required this.id,
    required this.patientId,
    required this.encounterId,
    required this.facilityId,
    required this.medication,
    required this.dose,
    required this.route,
    required this.frequency,
    required this.duration,
    required this.instructions,
    required this.orderedById,
    required this.orderedByName,
    required this.orderedAt,
    required this.signatureDigest,
    required this.signatureSignedAt,
    required this.signatureMethod,
    required this.copyNumber,
    required this.revision,
    this.status = 'active',
    this.backendOrderId,
    this.amendmentReason,
    this.supersedesId,
    this.dispensedAt,
    this.dispensedById,
    this.dispenseId,
  });

  final String id;
  final String patientId;
  final String encounterId;
  final String facilityId;
  final String medication;
  final String dose;
  final String route;
  final String frequency;
  final String duration;
  final String instructions;
  final String orderedById;
  final String orderedByName;
  final DateTime orderedAt;
  final String signatureDigest;
  final DateTime signatureSignedAt;
  final String signatureMethod;
  final String copyNumber;
  final int revision;
  final String status;
  final String? backendOrderId;
  final String? amendmentReason;
  final String? supersedesId;
  final DateTime? dispensedAt;
  final String? dispensedById;
  final String? dispenseId;

  bool get isActive => status == 'active';
  bool get isDispensed => status == 'dispensed';
  bool get isSuperseded => status == 'superseded';
  String get orderKey => backendOrderId?.trim().isNotEmpty == true
      ? backendOrderId!
      : id;

  PrescriptionRecord copyWith({
    String? status,
    DateTime? dispensedAt,
    String? dispensedById,
    String? dispenseId,
  }) =>
      PrescriptionRecord(
        id: id,
        patientId: patientId,
        encounterId: encounterId,
        facilityId: facilityId,
        medication: medication,
        dose: dose,
        route: route,
        frequency: frequency,
        duration: duration,
        instructions: instructions,
        orderedById: orderedById,
        orderedByName: orderedByName,
        orderedAt: orderedAt,
        signatureDigest: signatureDigest,
        signatureSignedAt: signatureSignedAt,
        signatureMethod: signatureMethod,
        copyNumber: copyNumber,
        revision: revision,
        status: status ?? this.status,
        backendOrderId: backendOrderId,
        amendmentReason: amendmentReason,
        supersedesId: supersedesId,
        dispensedAt: dispensedAt ?? this.dispensedAt,
        dispensedById: dispensedById ?? this.dispensedById,
        dispenseId: dispenseId ?? this.dispenseId,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        'id': id,
        'patientId': patientId,
        'encounterId': encounterId,
        'facilityId': facilityId,
        'medication': medication,
        'dose': dose,
        'route': route,
        'frequency': frequency,
        'duration': duration,
        'instructions': instructions,
        'orderedById': orderedById,
        'orderedByName': orderedByName,
        'orderedAt': orderedAt.toUtc().toIso8601String(),
        'signatureDigest': signatureDigest,
        'signatureSignedAt': signatureSignedAt.toUtc().toIso8601String(),
        'signatureMethod': signatureMethod,
        'copyNumber': copyNumber,
        'revision': revision,
        'status': status,
        'backendOrderId': backendOrderId,
        'amendmentReason': amendmentReason,
        'supersedesId': supersedesId,
        'dispensedAt': dispensedAt?.toUtc().toIso8601String(),
        'dispensedById': dispensedById,
        'dispenseId': dispenseId,
      };

  factory PrescriptionRecord.fromJson(Map<String, dynamic> json) =>
      PrescriptionRecord(
        id: json['id']?.toString() ?? '',
        patientId: json['patientId']?.toString() ?? '',
        encounterId: json['encounterId']?.toString() ?? '',
        facilityId: json['facilityId']?.toString() ?? '',
        medication: json['medication']?.toString() ?? '',
        dose: json['dose']?.toString() ?? '',
        route: json['route']?.toString() ?? '',
        frequency: json['frequency']?.toString() ?? '',
        duration: json['duration']?.toString() ?? '',
        instructions: json['instructions']?.toString() ?? '',
        orderedById: json['orderedById']?.toString() ?? '',
        orderedByName: json['orderedByName']?.toString() ?? '',
        orderedAt: DateTime.tryParse(json['orderedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        signatureDigest: json['signatureDigest']?.toString() ?? '',
        signatureSignedAt:
            DateTime.tryParse(json['signatureSignedAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        signatureMethod: json['signatureMethod']?.toString() ?? '',
        copyNumber: json['copyNumber']?.toString() ?? '',
        revision: (json['revision'] as num?)?.toInt() ?? 1,
        status: json['status']?.toString() ?? 'active',
        backendOrderId: json['backendOrderId']?.toString(),
        amendmentReason: json['amendmentReason']?.toString(),
        supersedesId: json['supersedesId']?.toString(),
        dispensedAt:
            DateTime.tryParse(json['dispensedAt']?.toString() ?? ''),
        dispensedById: json['dispensedById']?.toString(),
        dispenseId: json['dispenseId']?.toString(),
      );
}

class PrescriptionRecordStore {
  const PrescriptionRecordStore();
  static const _key = 'medqur_prescription_records_v1';

  Future<List<PrescriptionRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return const [];
      final records = decoded
          .whereType<Map<String, dynamic>>()
          .map(PrescriptionRecord.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList();
      records.sort((a, b) => b.orderedAt.compareTo(a.orderedAt));
      return records;
    } on Object {
      return const [];
    }
  }

  Future<void> _save(List<PrescriptionRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(records.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> add(PrescriptionRecord record) async {
    final records = (await loadAll()).toList();
    records.removeWhere((item) => item.id == record.id);
    records.add(record);
    await _save(records);
  }

  Future<void> addRevision({
    required PrescriptionRecord previous,
    required PrescriptionRecord revision,
  }) async {
    final records = (await loadAll()).toList();
    final index = records.indexWhere((item) => item.id == previous.id);
    final superseded = previous.copyWith(status: 'superseded');
    if (index >= 0) {
      records[index] = superseded;
    } else {
      records.add(superseded);
    }
    records.removeWhere((item) => item.id == revision.id);
    records.add(revision);
    await _save(records);
  }

  Future<List<PrescriptionRecord>> forPatient(String patientId) async {
    final records = (await loadAll())
        .where((item) => item.patientId == patientId)
        .toList();
    records.sort((a, b) {
      final rev = b.revision.compareTo(a.revision);
      return rev != 0 ? rev : b.orderedAt.compareTo(a.orderedAt);
    });
    return records;
  }

  Future<List<PrescriptionRecord>> forFacility(String facilityId) async {
    final records = (await loadAll())
        .where((item) => item.facilityId == facilityId)
        .toList();
    records.sort((a, b) => b.orderedAt.compareTo(a.orderedAt));
    return records;
  }

  Future<PrescriptionRecord?> latestForMedication({
    required String patientId,
    required MedicationOrder order,
  }) async {
    final records = await forPatient(patientId);
    final direct = records.where((record) {
      final orderId = order.orderId?.trim();
      if (orderId == null || orderId.isEmpty) return false;
      return record.id == orderId || record.backendOrderId == orderId;
    });
    if (direct.isNotEmpty) return direct.first;

    final matched = records.where(
      (record) =>
          !record.isSuperseded &&
          record.medication == order.name &&
          record.dose == order.dose &&
          record.route == order.route &&
          record.frequency == order.frequency &&
          record.orderedByName == order.orderedBy,
    );
    return matched.isEmpty ? null : matched.first;
  }

  Future<void> markDispensed({
    required PrescriptionRecord record,
    required String staffId,
    required String dispenseId,
  }) async {
    final records = (await loadAll()).toList();
    final index = records.indexWhere((item) => item.id == record.id);
    final next = record.copyWith(
      status: 'dispensed',
      dispensedAt: DateTime.now().toUtc(),
      dispensedById: staffId,
      dispenseId: dispenseId,
    );
    if (index >= 0) {
      records[index] = next;
    } else {
      records.add(next);
    }
    await _save(records);
  }
}
