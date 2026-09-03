import 'package:flutter_test/flutter_test.dart';
import 'package:medqur/models.dart';
import 'package:medqur/services/medication_identifier.dart';
import 'package:medqur/services/medication_safety.dart';

void main() {
  group('MedicationIdentifierParser', () {
    test('parses common GS1 healthcare application identifiers', () {
      final result = MedicationIdentifierParser.parse(
        '(01)09506000134352(17)271231(10)LOT123(21)SERIAL9',
        formatName: 'dataMatrix',
      );

      expect(result.isGs1, isTrue);
      expect(result.gtin, '09506000134352');
      expect(result.lotNumber, 'LOT123');
      expect(result.serialNumber, 'SERIAL9');
      expect(result.expiryDate, DateTime(2027, 12, 31));
    });

    test('parses compact GS1 FNC1 sequence', () {
      final result = MedicationIdentifierParser.parse(
        '01095060001343521727123110LOT123\u001d21SERIAL9',
        formatName: 'dataMatrix',
      );

      expect(result.gtin, '09506000134352');
      expect(result.lotNumber, 'LOT123');
      expect(result.serialNumber, 'SERIAL9');
      expect(result.expiryDate, DateTime(2027, 12, 31));
    });

    test('normalises EAN/UPC values to GTIN-14', () {
      final result = MedicationIdentifierParser.parse(
        '1234567890128',
        formatName: 'ean13',
      );

      expect(result.gtin, '01234567890128');
      expect(result.isGs1, isTrue);
    });
  });

  group('MedicationSafetyEngine', () {
    Patient patient({List<String> allergies = const ['No known allergies']}) =>
        Patient(
          id: 'PAT-TEST-1',
          encounterId: 'ENC-TEST-1',
          name: 'Test Patient',
          age: 30,
          sex: 'Female',
          nidsStatus: 'Prototype',
          chiefComplaint: 'Test',
          triage: TriageLevel.routine,
          status: PatientStatus.treatment,
          waitMinutes: 0,
          vitals: const {},
          allergies: allergies,
          timeline: [],
          medications: [],
        );

    test('allows the same GTIN even when lot/serial differ', () {
      const order = MedicationOrder(
        name: 'Paracetamol',
        dose: '500 mg',
        route: 'Oral',
        frequency: 'Once',
        orderedBy: 'Dr Test',
        productCode: '(01)09506000134352(17)271231(10)LOT-A',
      );
      final scan = MedicationIdentifierParser.parse(
        '(01)09506000134352(17)271231(10)LOT-B',
      );

      final result = MedicationSafetyEngine.evaluate(
        patient: patient(),
        order: order,
        scan: scan,
        now: DateTime(2026, 9, 3),
      );

      expect(result.allowed, isTrue);
      expect(result.warnings, isNotEmpty);
    });

    test('blocks a wrong GTIN', () {
      const order = MedicationOrder(
        name: 'Paracetamol',
        dose: '500 mg',
        route: 'Oral',
        frequency: 'Once',
        orderedBy: 'Dr Test',
        productCode: '(01)09506000134352',
      );
      final scan = MedicationIdentifierParser.parse('(01)09506000134369');

      final result = MedicationSafetyEngine.evaluate(
        patient: patient(),
        order: order,
        scan: scan,
      );

      expect(result.allowed, isFalse);
      expect(result.blockers.join(' '), contains('GTIN'));
    });

    test('blocks an expired scanned medication', () {
      const order = MedicationOrder(
        name: 'Paracetamol',
        dose: '500 mg',
        route: 'Oral',
        frequency: 'Once',
        orderedBy: 'Dr Test',
        productCode: '(01)09506000134352',
      );
      final scan = MedicationIdentifierParser.parse(
        '(01)09506000134352(17)250101',
      );

      final result = MedicationSafetyEngine.evaluate(
        patient: patient(),
        order: order,
        scan: scan,
        now: DateTime(2026, 9, 3),
      );

      expect(result.allowed, isFalse);
      expect(result.blockers.join(' '), contains('expired'));
    });
  });
}
