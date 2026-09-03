import 'package:flutter_test/flutter_test.dart';
import 'package:medqur/mock_data.dart';
import 'package:medqur/services/nids_test_credential.dart';
import 'package:medqur/services/staff_identity.dart';

void main() {
  group('six-digit health worker identity', () {
    test('all demo health workers use unique six-digit IDs', () {
      final ids = [demoDoctor.id, demoNurse.id, demoPharmacist.id];
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(StaffBadgeCodec.isSixDigitStaffNumber(id), isTrue);
      }
    });

    test('prototype staff QR round trips only the staff number', () {
      final token = StaffBadgeCodec.prototypeToken('482731');
      expect(token, 'MQS1|482731');
      expect(StaffBadgeCodec.prototypeStaffNumber(token), '482731');
      expect(token, isNot(contains('Maya')));
      expect(token, isNot(contains('doctor')));
    });

    test('signed credentials are never accepted as unsafely parsed local IDs', () {
      const token = 'MQW1.eyJ2IjoxLCJ0Ijoic3RhZmYifQ.signature';
      expect(StaffBadgeCodec.looksSigned(token), isTrue);
      expect(StaffBadgeCodec.prototypeStaffNumber(token), isNull);
    });
  });

  group('NIDS prototype credential', () {
    test('compact test credential round trips the registration fields', () {
      const credential = NidsTestCredential(
        givenNames: 'Test Patient',
        surname: 'Brown',
        dateOfBirth: '2001-08-14',
        nationalIdNumber: 'TEST-123456789',
      );
      final encoded = credential.encode();
      final decoded = NidsTestCredential.tryParse(encoded);

      expect(encoded.startsWith('MQN2|'), isTrue);
      expect(decoded, isNotNull);
      expect(decoded!.fullName, 'Test Patient Brown');
      expect(decoded.dateOfBirth, '2001-08-14');
      expect(decoded.nationalIdNumber, 'TEST-123456789');
    });
  });
}
