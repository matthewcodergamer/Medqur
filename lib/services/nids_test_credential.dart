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

  /// Compact V2 payload designed for small ID-card printing.
  ///
  /// Previous versions embedded base64 encoded JSON, which made the QR much
  /// denser than necessary. V2 keeps the same test data but uses a compact,
  /// escaped pipe-delimited representation. It is transport encoding only,
  /// not encryption, authentication, or NIRA verification.
  String encode() {
    String e(String value) => Uri.encodeComponent(value.trim());
    final compactDob = dateOfBirth.replaceAll('-', '');
    return 'MQN2|${e(nationalIdNumber)}|$compactDob|${e(givenNames)}|${e(surname)}';
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
      String d(String value) => Uri.decodeComponent(value).trim();
      final nin = d(parts[1]);
      final compactDob = parts[2].trim();
      final given = d(parts[3]);
      final surname = d(parts[4]);
      if (compactDob.length != 8) return null;
      final dob = '${compactDob.substring(0, 4)}-${compactDob.substring(4, 6)}-${compactDob.substring(6, 8)}';
      if (nin.isEmpty || given.isEmpty || surname.isEmpty || DateTime.tryParse(dob) == null) return null;
      return NidsTestCredential(
        givenNames: given,
        surname: surname,
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
      if (uri.pathSegments.length != 2 || uri.pathSegments.first != 'v1') return null;
      var payload = uri.pathSegments.last;
      final padding = payload.length % 4;
      if (padding != 0) payload = payload.padRight(payload.length + (4 - padding), '=');
      final decoded = jsonDecode(utf8.decode(base64Url.decode(payload)));
      if (decoded is! Map<String, dynamic> || decoded['test'] != true || decoded['v'] != 1) return null;
      final given = decoded['givenNames']?.toString().trim() ?? '';
      final surname = decoded['surname']?.toString().trim() ?? '';
      final dob = decoded['dateOfBirth']?.toString().trim() ?? '';
      final nin = decoded['nationalIdNumber']?.toString().trim() ?? '';
      if (given.isEmpty || surname.isEmpty || nin.isEmpty || DateTime.tryParse(dob) == null) return null;
      return NidsTestCredential(
        givenNames: given,
        surname: surname,
        dateOfBirth: dob,
        nationalIdNumber: nin,
      );
    } catch (_) {
      return null;
    }
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
