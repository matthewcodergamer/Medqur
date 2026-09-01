import 'dart:convert';

/// TEST-ONLY credential used by the public Medqur prototype.
///
/// This is deliberately separate from Jamaica's production NIDS/NIRA
/// verification. Production Medqur should consume an approved NIRA
/// verification response or an opaque server-side token rather than placing
/// identity data directly into a client-generated QR code.
class NidsTestCredential {
  const NidsTestCredential({
    required this.givenNames,
    required this.surname,
    required this.dateOfBirth,
    required this.nationalIdNumber,
  });

  final String givenNames;
  final String surname;
  final String dateOfBirth; // ISO yyyy-MM-dd in the prototype.
  final String nationalIdNumber;

  String get fullName => '$givenNames $surname'.trim();

  Map<String, dynamic> toJson() => {
        'v': 1,
        'test': true,
        'givenNames': givenNames,
        'surname': surname,
        'dateOfBirth': dateOfBirth,
        'nationalIdNumber': nationalIdNumber,
      };

  /// Self-contained payload for printed TEST cards only.
  ///
  /// Base64URL is transport encoding, not encryption or authentication.
  String encode() {
    final payload = base64Url.encode(utf8.encode(jsonEncode(toJson()))).replaceAll('=', '');
    return 'medqur://nids-test/v1/$payload';
  }

  static NidsTestCredential? tryParse(String raw) {
    try {
      final uri = Uri.parse(raw.trim());
      if (uri.scheme != 'medqur' || uri.host != 'nids-test') return null;
      if (uri.pathSegments.length != 2 || uri.pathSegments.first != 'v1') return null;

      var payload = uri.pathSegments.last;
      final padding = payload.length % 4;
      if (padding != 0) payload = payload.padRight(payload.length + (4 - padding), '=');

      final decoded = jsonDecode(utf8.decode(base64Url.decode(payload)));
      if (decoded is! Map<String, dynamic> || decoded['test'] != true || decoded['v'] != 1) return null;

      final givenNames = decoded['givenNames']?.toString().trim() ?? '';
      final surname = decoded['surname']?.toString().trim() ?? '';
      final dob = decoded['dateOfBirth']?.toString().trim() ?? '';
      final nin = decoded['nationalIdNumber']?.toString().trim() ?? '';
      if (givenNames.isEmpty || surname.isEmpty || dob.isEmpty || nin.isEmpty) return null;
      if (DateTime.tryParse(dob) == null) return null;

      return NidsTestCredential(
        givenNames: givenNames,
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
    final birthdayPassed = today.month > dob.month || (today.month == dob.month && today.day >= dob.day);
    if (!birthdayPassed) age--;
    return age < 0 ? 0 : age;
  }
}
