import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class MedqurSecurity {
  const MedqurSecurity._();

  static final Random _random = Random.secure();

  /// Generates an opaque credential suitable for QR/badge identifiers.
  /// It contains no staff or patient information by itself.
  static String generateOpaqueToken({int bytes = 24}) {
    final data = List<int>.generate(bytes, (_) => _random.nextInt(256));
    return base64UrlEncode(data).replaceAll('=', '');
  }
}

/// AES-256-GCM envelope helper for sensitive payloads when a real key-management
/// source is available. The key is intentionally supplied by the caller: keys
/// must never be hard-coded into the public Flutter bundle.
class SecureEnvelopeCodec {
  SecureEnvelopeCodec(this.keyBytes)
      : assert(keyBytes.length == 32, 'AES-256 requires a 32-byte key'),
        _secretKey = SecretKey(keyBytes);

  final List<int> keyBytes;
  final SecretKey _secretKey;
  final Cipher _cipher = AesGcm.with256bits();

  Future<String> encryptJson(Map<String, dynamic> payload) async {
    final nonce = _cipher.newNonce();
    final clear = utf8.encode(jsonEncode(payload));
    final box = await _cipher.encrypt(
      clear,
      secretKey: _secretKey,
      nonce: nonce,
    );
    return jsonEncode({
      'v': 1,
      'alg': 'A256GCM',
      'nonce': base64UrlEncode(box.nonce),
      'ciphertext': base64UrlEncode(box.cipherText),
      'mac': base64UrlEncode(box.mac.bytes),
    });
  }

  Future<Map<String, dynamic>> decryptJson(String envelope) async {
    final decoded = jsonDecode(envelope) as Map<String, dynamic>;
    if (decoded['v'] != 1 || decoded['alg'] != 'A256GCM') {
      throw const FormatException('Unsupported secure envelope.');
    }
    final box = SecretBox(
      base64Url.decode(decoded['ciphertext'].toString()),
      nonce: base64Url.decode(decoded['nonce'].toString()),
      mac: Mac(base64Url.decode(decoded['mac'].toString())),
    );
    final clear = await _cipher.decrypt(box, secretKey: _secretKey);
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  }
}
