import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OfflineMedicationCatalog {
  const OfflineMedicationCatalog({
    required this.version,
    required this.generatedAt,
    required this.products,
    required this.sha256,
    required this.signingKeyId,
  });

  final int version;
  final DateTime generatedAt;
  final List<Map<String, dynamic>> products;
  final String sha256;
  final String signingKeyId;
}

class OfflineMedicationCatalogStore {
  OfflineMedicationCatalogStore({http.Client? client})
      : _client = client ?? http.Client();

  static const String _base =
      String.fromEnvironment('MEDQUR_API_BASE', defaultValue: '');
  static const String _catalogPublicKey =
      String.fromEnvironment('MEDQUR_CATALOG_PUBLIC_KEY_BASE64', defaultValue: '');
  static const String _payloadKey = 'medqur.medicationCatalog.payload';
  static const String _metadataKey = 'medqur.medicationCatalog.metadata';

  final http.Client _client;

  bool get canVerify => _catalogPublicKey.trim().isNotEmpty;

  Future<OfflineMedicationCatalog?> refresh({
    Map<String, String> headers = const {},
  }) async {
    if (_base.trim().isEmpty || !canVerify) return null;
    final base = Uri.parse(_base.endsWith('/') ? _base : '$_base/');
    final response = await _client.get(
      base.resolve('v1/catalog/latest'),
      headers: {'Accept': 'application/json', ...headers},
    );
    if (response.statusCode != 200) return null;
    final envelope = jsonDecode(response.body);
    if (envelope is! Map<String, dynamic>) return null;

    final payloadValue = envelope['payload'];
    final payloadString = payloadValue is String
        ? payloadValue
        : jsonEncode(payloadValue);
    final signatureText = envelope['signature_base64']?.toString() ?? '';
    final keyId = envelope['signing_key_id']?.toString() ?? '';
    final expectedHash = envelope['payload_sha256']?.toString() ?? '';
    if (signatureText.isEmpty || keyId.isEmpty || expectedHash.isEmpty) return null;

    final bytes = utf8.encode(payloadString);
    final calculated = await Sha256().hash(bytes);
    final calculatedHex = calculated.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    if (calculatedHex != expectedHash.toLowerCase()) return null;

    final publicKey = SimplePublicKey(
      base64Decode(_catalogPublicKey),
      type: KeyPairType.ed25519,
    );
    final signature = Signature(
      base64Decode(signatureText),
      publicKey: publicKey,
    );
    final verified = await Ed25519().verify(bytes, signature: signature);
    if (!verified) return null;

    final decodedPayload = jsonDecode(payloadString);
    if (decodedPayload is! Map<String, dynamic>) return null;
    final version = (decodedPayload['version'] as num?)?.toInt() ?? 0;
    final generatedAt = DateTime.tryParse(
          decodedPayload['generatedAt']?.toString() ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final products = (decodedPayload['products'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final prefs = await SharedPreferences.getInstance();
    final previous = await load();
    if (previous != null && version < previous.version) {
      return previous;
    }
    await prefs.setString(_payloadKey, payloadString);
    await prefs.setString(
      _metadataKey,
      jsonEncode({
        'version': version,
        'generatedAt': generatedAt.toIso8601String(),
        'sha256': calculatedHex,
        'signingKeyId': keyId,
      }),
    );
    return OfflineMedicationCatalog(
      version: version,
      generatedAt: generatedAt,
      products: products,
      sha256: calculatedHex,
      signingKeyId: keyId,
    );
  }

  Future<OfflineMedicationCatalog?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final payloadString = prefs.getString(_payloadKey);
    final metadataString = prefs.getString(_metadataKey);
    if (payloadString == null || metadataString == null) return null;
    try {
      final payload = jsonDecode(payloadString) as Map<String, dynamic>;
      final metadata = jsonDecode(metadataString) as Map<String, dynamic>;
      return OfflineMedicationCatalog(
        version: (metadata['version'] as num?)?.toInt() ?? 0,
        generatedAt: DateTime.tryParse(metadata['generatedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        products: (payload['products'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
        sha256: metadata['sha256']?.toString() ?? '',
        signingKeyId: metadata['signingKeyId']?.toString() ?? '',
      );
    } on Object {
      return null;
    }
  }

  Future<Map<String, dynamic>?> findByGtin(String gtin14) async {
    final catalog = await load();
    if (catalog == null) return null;
    for (final product in catalog.products) {
      final identifiers = product['identifiers'];
      if (identifiers is! List) continue;
      for (final raw in identifiers) {
        if (raw is Map && raw['gtin14']?.toString() == gtin14) {
          return product;
        }
      }
    }
    return null;
  }

  void dispose() => _client.close();
}
