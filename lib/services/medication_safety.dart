import '../models.dart';
import 'medication_identifier.dart';

class MedicationSafetyResult {
  const MedicationSafetyResult({
    required this.allowed,
    this.blockers = const [],
    this.warnings = const [],
  });

  final bool allowed;
  final List<String> blockers;
  final List<String> warnings;
}

class MedicationSafetyEngine {
  const MedicationSafetyEngine._();

  static MedicationSafetyResult evaluate({
    required Patient patient,
    required MedicationOrder order,
    required MedicationIdentifier scan,
    DateTime? now,
  }) {
    final blockers = <String>[];
    final warnings = <String>[];

    if (order.administered) {
      blockers.add('This medication order is already recorded as administered.');
    }

    final mappedRaw = order.productCode;
    if (mappedRaw == null || mappedRaw.isEmpty) {
      blockers.add('The order does not have an approved medication product identifier mapped.');
    } else {
      final mapped = MedicationIdentifierParser.parse(mappedRaw);
      if (mapped.gtin != null && scan.gtin != null) {
        if (mapped.gtin != scan.gtin) {
          blockers.add('Wrong medication product: scanned GTIN does not match the signed order.');
        }
      } else if (mapped.rawValue != scan.rawValue) {
        blockers.add('Wrong medication product: scanned code does not match the mapped package.');
      }

      if (mapped.lotNumber != null &&
          scan.lotNumber != null &&
          mapped.lotNumber != scan.lotNumber) {
        warnings.add('Scanned lot differs from the lot originally mapped to the order.');
      }
    }

    if (scan.isExpired(now)) {
      blockers.add('Medication is expired according to the scanned GS1 expiry date.');
    }

    if (!scan.isGs1 && scan.gtin == null) {
      warnings.add('This code is not a parsed GS1 identifier; traceability fields could not be verified.');
    }

    if (scan.gtin != null && scan.lotNumber == null) {
      warnings.add('Product identified, but no lot number was available in the scanned code.');
    }

    if (scan.gtin != null && scan.expiryDate == null) {
      warnings.add('Product identified, but no machine-readable expiry date was available.');
    }

    final medicationName = _normalize(order.name);
    for (final allergy in patient.allergies) {
      final normalized = _normalize(allergy);
      if (normalized.isEmpty ||
          normalized.contains('no known') ||
          normalized == 'nkda' ||
          normalized == 'unknown') {
        continue;
      }
      if (normalized == medicationName || medicationName.contains(normalized)) {
        blockers.add('Allergy conflict: ${order.name} matches a documented patient allergy.');
      }
    }

    return MedicationSafetyResult(
      allowed: blockers.isEmpty,
      blockers: List.unmodifiable(blockers),
      warnings: List.unmodifiable(warnings),
    );
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}
