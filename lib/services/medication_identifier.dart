import 'dart:math' as math;

enum MedicationCodeKind {
  gs1DataMatrix,
  gs1Linear,
  eanUpc,
  qr,
  code128,
  other,
}

class MedicationIdentifier {
  const MedicationIdentifier({
    required this.rawValue,
    required this.kind,
    required this.isGs1,
    this.gtin,
    this.lotNumber,
    this.expiryDate,
    this.serialNumber,
    this.applicationIdentifiers = const {},
  });

  final String rawValue;
  final MedicationCodeKind kind;
  final bool isGs1;
  final String? gtin;
  final String? lotNumber;
  final DateTime? expiryDate;
  final String? serialNumber;
  final Map<String, String> applicationIdentifiers;

  bool get hasTraceabilityData =>
      lotNumber != null || expiryDate != null || serialNumber != null;

  bool isExpired([DateTime? at]) {
    if (expiryDate == null) return false;
    final now = at ?? DateTime.now();
    final end = DateTime(
      expiryDate!.year,
      expiryDate!.month,
      expiryDate!.day,
      23,
      59,
      59,
    );
    return now.isAfter(end);
  }

  String get summary {
    final parts = <String>[];
    if (gtin != null) parts.add('GTIN $gtin');
    if (lotNumber != null) parts.add('Lot $lotNumber');
    if (expiryDate != null) {
      parts.add(
        'Exp ${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}',
      );
    }
    if (serialNumber != null) parts.add('Serial $serialNumber');
    return parts.isEmpty ? rawValue : parts.join(' • ');
  }
}

class MedicationIdentifierParser {
  const MedicationIdentifierParser._();

  static const String _groupSeparator = '\u001d';

  static MedicationIdentifier parse(
    String raw, {
    String? formatName,
  }) {
    final original = raw.trim();
    var value = original;
    final lowerFormat = (formatName ?? '').toLowerCase();

    // AIM symbology identifiers commonly exposed by scanners.
    if (value.startsWith(']d2') || value.startsWith(']C1')) {
      value = value.substring(3);
    }

    final parenthesized = _parseParenthesizedGs1(value);
    if (parenthesized.isNotEmpty) {
      return _fromAis(
        original,
        parenthesized,
        kind: lowerFormat.contains('matrix')
            ? MedicationCodeKind.gs1DataMatrix
            : MedicationCodeKind.gs1Linear,
      );
    }

    final compact = _parseCompactGs1(value);
    if (compact.isNotEmpty) {
      return _fromAis(
        original,
        compact,
        kind: lowerFormat.contains('matrix')
            ? MedicationCodeKind.gs1DataMatrix
            : MedicationCodeKind.gs1Linear,
      );
    }

    final digitsOnly = RegExp(r'^\d+$').hasMatch(value);
    if (digitsOnly && const {8, 12, 13, 14}.contains(value.length)) {
      return MedicationIdentifier(
        rawValue: original,
        kind: MedicationCodeKind.eanUpc,
        isGs1: true,
        gtin: value.padLeft(14, '0'),
      );
    }

    return MedicationIdentifier(
      rawValue: original,
      kind: _kindFromFormat(lowerFormat),
      isGs1: false,
    );
  }

  static MedicationIdentifier _fromAis(
    String raw,
    Map<String, String> ais, {
    required MedicationCodeKind kind,
  }) {
    return MedicationIdentifier(
      rawValue: raw,
      kind: kind,
      isGs1: true,
      gtin: ais['01'],
      lotNumber: ais['10'],
      expiryDate: _parseGs1Date(ais['17']),
      serialNumber: ais['21'],
      applicationIdentifiers: Map.unmodifiable(ais),
    );
  }

  static Map<String, String> _parseParenthesizedGs1(String value) {
    final matches = RegExp(r'\((\d{2,4})\)').allMatches(value).toList();
    if (matches.isEmpty) return const {};
    final result = <String, String>{};
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final ai = match.group(1)!;
      final start = match.end;
      final end = i + 1 < matches.length ? matches[i + 1].start : value.length;
      final data = value.substring(start, end).replaceAll(_groupSeparator, '').trim();
      if (data.isNotEmpty) result[ai] = data;
    }
    return result.containsKey('01') ? result : const {};
  }

  static Map<String, String> _parseCompactGs1(String value) {
    // The most common healthcare sequence is 01 (GTIN), optional 17 (expiry),
    // then variable-length 10 (lot) and/or 21 (serial), delimited by FNC1/GS.
    if (!value.startsWith('01') || value.length < 16) return const {};
    final result = <String, String>{};
    var cursor = 0;

    String? readFixed(String ai, int length) {
      if (cursor + ai.length + length > value.length ||
          !value.startsWith(ai, cursor)) {
        return null;
      }
      cursor += ai.length;
      final data = value.substring(cursor, cursor + length);
      cursor += length;
      return data;
    }

    final gtin = readFixed('01', 14);
    if (gtin == null || !RegExp(r'^\d{14}$').hasMatch(gtin)) return const {};
    result['01'] = gtin;

    while (cursor < value.length) {
      if (value[cursor] == _groupSeparator) {
        cursor++;
        continue;
      }
      if (value.startsWith('17', cursor)) {
        final expiry = readFixed('17', 6);
        if (expiry != null) result['17'] = expiry;
        continue;
      }
      if (value.startsWith('10', cursor) || value.startsWith('21', cursor)) {
        final ai = value.substring(cursor, cursor + 2);
        cursor += 2;
        final separator = value.indexOf(_groupSeparator, cursor);
        final end = separator == -1 ? value.length : separator;
        final maxLength = ai == '10' ? 20 : 20;
        final cappedEnd = math.min(end, cursor + maxLength);
        if (cappedEnd > cursor) result[ai] = value.substring(cursor, cappedEnd);
        cursor = end;
        continue;
      }
      // Unknown AI: stop rather than guessing field boundaries.
      break;
    }
    return result;
  }

  static DateTime? _parseGs1Date(String? value) {
    if (value == null || value.length != 6 || !RegExp(r'^\d{6}$').hasMatch(value)) {
      return null;
    }
    final year = 2000 + int.parse(value.substring(0, 2));
    final month = int.parse(value.substring(2, 4));
    var day = int.parse(value.substring(4, 6));
    if (month < 1 || month > 12) return null;
    if (day == 0) {
      day = DateTime(year, month + 1, 0).day;
    }
    final maxDay = DateTime(year, month + 1, 0).day;
    if (day < 1 || day > maxDay) return null;
    return DateTime(year, month, day);
  }

  static MedicationCodeKind _kindFromFormat(String format) {
    if (format.contains('matrix')) return MedicationCodeKind.other;
    if (format.contains('qr')) return MedicationCodeKind.qr;
    if (format.contains('128')) return MedicationCodeKind.code128;
    if (format.contains('ean') || format.contains('upc')) {
      return MedicationCodeKind.eanUpc;
    }
    return MedicationCodeKind.other;
  }
}
