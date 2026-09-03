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
    this.gtinCheckDigitValid,
    this.lotNumber,
    this.expiryDate,
    this.manufactureDate,
    this.bestBeforeDate,
    this.serialNumber,
    this.applicationIdentifiers = const {},
  });

  final String rawValue;
  final MedicationCodeKind kind;
  final bool isGs1;
  final String? gtin;
  final bool? gtinCheckDigitValid;
  final String? lotNumber;
  final DateTime? expiryDate;
  final DateTime? manufactureDate;
  final DateTime? bestBeforeDate;
  final String? serialNumber;
  final Map<String, String> applicationIdentifiers;

  bool get hasTraceabilityData =>
      lotNumber != null ||
      expiryDate != null ||
      manufactureDate != null ||
      bestBeforeDate != null ||
      serialNumber != null;

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
    if (gtin != null) {
      parts.add('GTIN $gtin${gtinCheckDigitValid == false ? ' (invalid check digit)' : ''}');
    }
    if (lotNumber != null) parts.add('Lot $lotNumber');
    if (manufactureDate != null) parts.add('Mfg ${_date(manufactureDate!)}');
    if (expiryDate != null) parts.add('Exp ${_date(expiryDate!)}');
    if (bestBeforeDate != null) parts.add('Best before ${_date(bestBeforeDate!)}');
    if (serialNumber != null) parts.add('Serial $serialNumber');
    return parts.isEmpty ? rawValue : parts.join(' • ');
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
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

    // AIM symbology identifiers commonly exposed by healthcare scanners.
    if (value.length >= 3 && value.startsWith(']')) {
      final prefix = value.substring(0, 3).toLowerCase();
      if (prefix == ']d2' || prefix == ']c1') value = value.substring(3);
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
      final normalized = value.padLeft(14, '0');
      return MedicationIdentifier(
        rawValue: original,
        kind: MedicationCodeKind.eanUpc,
        isGs1: true,
        gtin: normalized,
        gtinCheckDigitValid: isValidGtin(normalized),
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
    final gtin = ais['01'];
    return MedicationIdentifier(
      rawValue: raw,
      kind: kind,
      isGs1: true,
      gtin: gtin,
      gtinCheckDigitValid: gtin == null ? null : isValidGtin(gtin),
      lotNumber: ais['10'],
      manufactureDate: _parseGs1Date(ais['11'], allowDayZero: false),
      bestBeforeDate: _parseGs1Date(ais['15'], allowDayZero: true),
      expiryDate: _parseGs1Date(ais['17'], allowDayZero: true),
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
    // Common healthcare GS1 payload: AI 01 (GTIN) followed by fixed dates and
    // variable lot/serial values separated with FNC1/ASCII GS when required.
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

      var matchedFixed = false;
      for (final ai in const ['11', '15', '17']) {
        if (value.startsWith(ai, cursor)) {
          final date = readFixed(ai, 6);
          if (date != null) result[ai] = date;
          matchedFixed = true;
          break;
        }
      }
      if (matchedFixed) continue;

      if (value.startsWith('10', cursor) || value.startsWith('21', cursor)) {
        final ai = value.substring(cursor, cursor + 2);
        cursor += 2;
        final separator = value.indexOf(_groupSeparator, cursor);
        final end = separator == -1 ? value.length : separator;
        final cappedEnd = math.min(end, cursor + 20);
        if (cappedEnd > cursor) result[ai] = value.substring(cursor, cappedEnd);
        cursor = end;
        continue;
      }

      // Unknown AI: stop instead of guessing variable-length field boundaries.
      break;
    }
    return result;
  }

  static DateTime? _parseGs1Date(
    String? value, {
    required bool allowDayZero,
  }) {
    if (value == null || value.length != 6 || !RegExp(r'^\d{6}$').hasMatch(value)) {
      return null;
    }
    final year = 2000 + int.parse(value.substring(0, 2));
    final month = int.parse(value.substring(2, 4));
    var day = int.parse(value.substring(4, 6));
    if (month < 1 || month > 12) return null;
    if (day == 0) {
      if (!allowDayZero) return null;
      day = DateTime(year, month + 1, 0).day;
    }
    final maxDay = DateTime(year, month + 1, 0).day;
    if (day < 1 || day > maxDay) return null;
    return DateTime(year, month, day);
  }

  /// Validates the GS1/GTIN modulo-10 check digit. Works with GTIN-8/12/13/14;
  /// callers may safely left-pad shorter forms with zeros before validation.
  static bool isValidGtin(String value) {
    if (!RegExp(r'^\d{8,14}$').hasMatch(value)) return false;
    final digits = value.split('').map(int.parse).toList();
    final check = digits.removeLast();
    var sum = 0;
    for (var i = digits.length - 1, position = 0; i >= 0; i--, position++) {
      sum += digits[i] * (position.isEven ? 3 : 1);
    }
    final expected = (10 - (sum % 10)) % 10;
    return check == expected;
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
