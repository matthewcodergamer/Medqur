import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'nids_test_credential.dart';

enum NidsCredentialKind {
  medqurTest,
  opaqueCredential,
  structuredUnverified,
}

class NidsScanEnvelope {
  const NidsScanEnvelope({
    required this.rawValue,
    required this.kind,
    required this.fingerprint,
    this.testCredential,
  });

  final String rawValue;
  final NidsCredentialKind kind;
  final String fingerprint;
  final NidsTestCredential? testCredential;

  bool get isPrototypeVerified => testCredential != null;
  bool get requiresAuthoritativeVerification => !isPrototypeVerified;

  String get safeLabel => switch (kind) {
        NidsCredentialKind.medqurTest => 'Medqur NIDS test credential',
        NidsCredentialKind.structuredUnverified =>
          'Structured identity payload — authoritative verification required',
        NidsCredentialKind.opaqueCredential =>
          'NIC credential captured — authoritative verification required',
      };
}

class NidsIdentityDecoder {
  const NidsIdentityDecoder._();

  static NidsScanEnvelope decode(String raw) {
    final value = raw.trim();
    final test = NidsTestCredential.tryParse(value);
    if (test != null) {
      return NidsScanEnvelope(
        rawValue: value,
        kind: NidsCredentialKind.medqurTest,
        fingerprint: fingerprint(value),
        testCredential: test,
      );
    }

    return NidsScanEnvelope(
      rawValue: value,
      kind: _looksStructured(value)
          ? NidsCredentialKind.structuredUnverified
          : NidsCredentialKind.opaqueCredential,
      fingerprint: fingerprint(value),
    );
  }

  static String fingerprint(String raw) {
    final digest = sha256.convert(utf8.encode(raw)).toString();
    return digest.substring(0, 16).toUpperCase();
  }

  static bool _looksStructured(String value) {
    if (value.startsWith('{') && value.endsWith('}')) return true;
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    return uri.hasScheme && uri.queryParameters.isNotEmpty;
  }
}

class VerifiedNidsIdentity {
  const VerifiedNidsIdentity({
    required this.fullName,
    required this.dateOfBirth,
    required this.nationalIdNumber,
    required this.source,
  });

  final String fullName;
  final String dateOfBirth;
  final String nationalIdNumber;
  final String source;
}

abstract class NidsVerificationGateway {
  Future<VerifiedNidsIdentity?> verify(NidsScanEnvelope credential);
}

/// Development verifier. Only the explicitly marked Medqur test credential is
/// trusted locally. Real NIC codes must go to an approved NIRA verifier.
class PrototypeNidsVerificationGateway implements NidsVerificationGateway {
  const PrototypeNidsVerificationGateway();

  @override
  Future<VerifiedNidsIdentity?> verify(NidsScanEnvelope credential) async {
    final test = credential.testCredential;
    if (test == null) return null;
    return VerifiedNidsIdentity(
      fullName: test.fullName,
      dateOfBirth: test.dateOfBirth,
      nationalIdNumber: test.nationalIdNumber,
      source: 'Medqur test credential',
    );
  }
}

/// Production seam for Jamaica's authoritative NIC verification service.
/// No endpoint, key, or assumed QR schema is hard-coded in the public app.
class NiraVerificationGateway implements NidsVerificationGateway {
  const NiraVerificationGateway();

  @override
  Future<VerifiedNidsIdentity?> verify(NidsScanEnvelope credential) {
    throw StateError(
      'NIRA verification is not configured. Supply the approved NIRA endpoint, authentication material, consent flow, and response profile before enabling real NIC autofill.',
    );
  }
}
