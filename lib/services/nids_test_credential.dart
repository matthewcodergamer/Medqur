import 'dart:convert';

/// TEST-ONLY credential used by the public Medqur prototype.
///
/// Production Medqur must use an approved NIRA verification response or an
/// opaque server-side token. This class intentionally remains prototype-only.
class NidsTestCredential {
  const NidsTestCredential({
    required this.givenNames,
    required this.surname,
    required this.dateOfBirth,
    required this.nationalIdNumber,
  });

  final String givenNames;
  final String surname;
  final String dateOfBirth;
  final String nationalIdNumber;

  String get fullName => '$givenNames $surname'.trim();

  /// Compact V2 payload designed specifically for small ID-card printing.
  ///
  /// Format: MQN2|NIN|YYYYMMDD|SURNAME|GIVEN~NAMES
  ///
  /// Spaces become a single '~' and punctuation in the test NIN is removed.
  /// This keeps the QR significantly smaller and less visually dense than the
  /// older URI + base64 JSON format while preserving the fields needed by the
  /// prototype's front/back cross-check.
  String encode() {
    final nin = _compactId(nationalIdNumber);
    final dob = dateOfBirth.replaceAll('-', '');
    final surnameValue = _packText(surname);
    final givenValue = _packText(givenNames);
    return 'MQN2|$nin|$dob|$surnameValue|$givenValue';
  }

  static NidsTestCredential? tryParse(String raw) {
    final value = raw.trim();
    final compact = _tryParseCompact(value);
    if (compact != null) return compact;
    return _tryParseLegacy(value);
  }

  static NidsTestCredential? _tryParseCompact(String raw) {
    try {
      final parts = raw.split('|');
      if (parts.length != 5 || parts.first != 'MQN2') return null;

      final nin = _prettyId(parts[1]);
      final compactDob = parts[2].trim();
      final surnameValue = _unpackText(parts[3]);
      final givenValue = _unpackText(parts[4]);
      if (compactDob.length != 8) return null;

      final dob =
          '${compactDob.substring(0, 4)}-${compactDob.substring(4, 6)}-${compactDob.substring(6, 8)}';
      if (nin.isEmpty ||
          givenValue.isEmpty ||
          surnameValue.isEmpty ||
          DateTime.tryParse(dob) == null) {
        return null;
      }

      return NidsTestCredential(
        givenNames: _toTitleCase(givenValue),
        surname: _toTitleCase(surnameValue),
        dateOfBirth: dob,
        nationalIdNumber: nin,
      );
    } catch (_) {
      return null;
    }
  }

  /// Keeps older printed Medqur TEST cards readable during migration.
  static NidsTestCredential? _tryParseLegacy(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != 'medqur' || uri.host != 'nids-test') return null;
      if (uri.pathSegments.length != 2 || uri.pathSegments.first != 'v1') {
        return null;
      }
      var payload = uri.pathSegments.last;
      final padding = payload.length % 4;
      if (padding != 0) {
        payload = payload.padRight(payload.length + (4 - padding), '=');
      }
      final decoded = jsonDecode(utf8.decode(base64Url.decode(payload)));
      if (decoded is! Map<String, dynamic> ||
          decoded['test'] != true ||
          decoded['v'] != 1) {
        return null;
      }
      final given = decoded['givenNames']?.toString().trim() ?? '';
      final surnameValue = decoded['surname']?.toString().trim() ?? '';
      final dob = decoded['dateOfBirth']?.toString().trim() ?? '';
      final nin = decoded['nationalIdNumber']?.toString().trim() ?? '';
      if (given.isEmpty ||
          surnameValue.isEmpty ||
          nin.isEmpty ||
          DateTime.tryParse(dob) == null) {
        return null;
      }
      return NidsTestCredential(
        givenNames: given,
        surname: surnameValue,
        dateOfBirth: dob,
        nationalIdNumber: nin,
      );
    } catch (_) {
      return null;
    }
  }

  static String _packText(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '~')
        .replaceAll('|', '');
  }

  static String _unpackText(String value) => value.replaceAll('~', ' ').trim();

  static String _compactId(String value) {
    return value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static String _prettyId(String value) {
    final cleaned = _compactId(value);
    if (cleaned.startsWith('TEST') && cleaned.length > 4) {
      return 'TEST-${cleaned.substring(4)}';
    }
    return cleaned;
  }

  static String _toTitleCase(String value) {
    return value
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) =>
            '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  static int ageFromIsoDate(String dateOfBirth, {DateTime? now}) {
    final dob = DateTime.tryParse(dateOfBirth);
    if (dob == null) return 0;
    final today = now ?? DateTime.now();
    var age = today.year - dob.year;
    final birthdayPassed = today.month > dob.month ||
        (today.month == dob.month && today.day >= dob.day);
    if (!birthdayPassed) age--;
    return age < 0 ? 0 : age;
  }
}
