import 'package:flutter_test/flutter_test.dart';
import 'package:medqur/services/security_foundation.dart';

void main() {
  test('opaque credentials contain no embedded profile data', () {
    final first = MedqurSecurity.generateOpaqueToken();
    final second = MedqurSecurity.generateOpaqueToken();

    expect(first, isNotEmpty);
    expect(second, isNotEmpty);
    expect(first, isNot(second));
    expect(first, isNot(contains('staff')));
    expect(first, isNot(contains('patient')));
  });

  test('AES-256-GCM secure envelope round trips JSON', () async {
    final codec = SecureEnvelopeCodec(List<int>.generate(32, (index) => index));
    final encrypted = await codec.encryptJson({
      'credential': 'opaque-value',
      'scope': 'prototype-test',
    });

    expect(encrypted, isNot(contains('opaque-value')));

    final decrypted = await codec.decryptJson(encrypted);
    expect(decrypted['credential'], 'opaque-value');
    expect(decrypted['scope'], 'prototype-test');
  });
}
