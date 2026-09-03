import 'dart:convert';

import 'package:crypto/crypto.dart';

class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.type,
    required this.actorId,
    required this.facilityId,
    required this.occurredAt,
    required this.subjectReference,
    this.metadata = const {},
  });

  final String id;
  final String type;
  final String actorId;
  final String facilityId;
  final DateTime occurredAt;
  final String subjectReference;
  final Map<String, String> metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'actorId': actorId,
        'facilityId': facilityId,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'subjectReference': subjectReference,
        'metadata': metadata,
      };
}

class AuditPrivacy {
  const AuditPrivacy._();

  /// Use this when an audit record needs to correlate a sensitive identifier
  /// without storing the raw NIN, QR payload, or barcode in the log itself.
  static String fingerprint(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  static Map<String, String> safeScanMetadata({
    required String format,
    required String rawValue,
    String? gtin,
    String? lot,
  }) {
    return {
      'format': format,
      'credentialFingerprint': fingerprint(rawValue),
      if (gtin != null) 'gtin': gtin,
      if (lot != null) 'lot': lot,
    };
  }
}

/// A production implementation should write to a server-side append-only store
/// with integrity protection and retention controls. This interface prevents UI
/// code from depending on a particular audit database.
abstract class AuditSink {
  Future<void> append(AuditEvent event);
}
