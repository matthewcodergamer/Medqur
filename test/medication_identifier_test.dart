import 'package:flutter_test/flutter_test.dart';
import 'package:medqur/models.dart';
import 'package:medqur/services/medication_identifier.dart';
import 'package:medqur/services/medication_master.dart';
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
      expect(result.gtinCheckDigitValid, isTrue);
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

    test('parses manufacture and expiry fields from a healthcare package', () {
      final result = MedicationIdentifierParser.parse(
        '(01)18904215101509(11)250301(17)270200(10)NBA7002(21)NBA7002002985',
        formatName: 'dataMatrix',
      );

      expect(result.gtin, '18904215101509');
      expect(result.gtinCheckDigitValid, isTrue);
      expect(result.manufactureDate, DateTime(2025, 3, 1));
      expect(result.expiryDate, DateTime(2027, 2, 28));
      expect(result.lotNumber, 'NBA7002');
      expect(result.serialNumber, 'NBA7002002985');
    });

    test('parses bracket-colon DataMatrix HRI returned by real package scanner', () {
      final result = MedicationIdentifierParser.parse(
        '[01]:18904215101509[10]:NBA7002[11]:MAR.2025[17]:FEB.2027[21]:NBA7002002985',
        formatName: 'dataMatrix',
      );

      expect(result.isGs1, isTrue);
      expect(result.gtin, '18904215101509');
      expect(result.gtinCheckDigitValid, isTrue);
      expect(result.lotNumber, 'NBA7002');
      expect(result.manufactureDate, DateTime(2025, 3, 1));
      expect(result.expiryDate, DateTime(2027, 2, 28));
      expect(result.serialNumber, 'NBA7002002985');
      expect(result.kind, MedicationCodeKind.gs1DataMatrix);

      final product = MedicationMasterCatalog.lookup(result);
      expect(product?.brandName, 'Neurobalin-75');
      expect(product?.genericName, 'Pregabalin');
    });

    test('normalises EAN/UPC values to GTIN-14', () {
      final result = MedicationIdentifierParser.parse(
        '8906102700515',
        formatName: 'ean13',
      );

      expect(result.gtin, '08906102700515');
      expect(result.gtinCheckDigitValid, isTrue);
      expect(result.isGs1, isTrue);
    });

    test('flags an invalid GTIN check digit', () {
      final result = MedicationIdentifierParser.parse(
        '8906102700514',
        formatName: 'ean13',
      );
      expect(result.gtinCheckDigitValid, isFalse);
    });
  });

  group('MedicationMasterCatalog observed package fixtures', () {
    test('matches Neurobalin-75 DataMatrix GTIN from prototype package', () {
      final identifier = MedicationIdentifierParser.parse(
        '(01)18904215101509(17)270200(10)NBA7002(21)NBA7002002985',
        formatName: 'dataMatrix',
      );
      final product = MedicationMasterCatalog.lookup(identifier);
      expect(product?.brandName, 'Neurobalin-75');
      expect(product?.genericName, 'Pregabalin');
      expect(product?.clinicallyVerified, isFalse);
    });

    test('matches CEFUR EAN-13 from prototype package', () {
      final identifier = MedicationIdentifierParser.parse(
        '8906102700515',
        formatName: 'ean13',
      );
      final product = MedicationMasterCatalog.lookup(identifier);
      expect(product?.brandName, 'CEFUR');
      expect(product?.genericName, 'Cefuroxime axetil');
    });

    test('matches Mucinex DM UPC from prototype package', () {
      final identifier = MedicationIdentifierParser.parse(
        '363824050287',
        formatName: 'upcA',
      );
      final product = MedicationMasterCatalog.lookup(identifier);
      expect(product?.brandName, 'Mucinex DM Maximum Strength');
    });

    test('searches local medication fixtures by brand generic and class', () {
      expect(
        MedicationMasterCatalog.search('pregabalin').first.brandName,
        'Neurobalin-75',
      );
      expect(
        MedicationMasterCatalog.search('cephalosporin')
            .any((item) => item.brandName == 'CEFUR'),
        isTrue,
      );
      expect(
        MedicationMasterCatalog.search('Mucinex').first.genericName,
        contains('Guaifenesin'),
      );
    });

    test('expanded prototype catalogue supports common name/form searches', () {
      expect(
        MedicationMasterCatalog.search('amlodipine 5 mg')
            .any((item) => item.genericName == 'Amlodipine'),
        isTrue,
      );
      expect(
        MedicationMasterCatalog.search('inhaler')
            .any((item) => item.genericName == 'Salbutamol'),
        isTrue,
      );
      expect(
        MedicationMasterCatalog.search('ceftriaxone')
            .every((item) => item.clinicallyVerified == false),
        isTrue,
      );
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

    test('blocks an invalid GTIN even if a package is otherwise scanned', () {
      const order = MedicationOrder(
        name: 'Test drug',
        dose: '1 tablet',
        route: 'Oral',
        frequency: 'Once',
        orderedBy: 'Dr Test',
        productCode: '8906102700514',
      );
      final scan = MedicationIdentifierParser.parse('8906102700514');
      final result = MedicationSafetyEngine.evaluate(
        patient: patient(),
        order: order,
        scan: scan,
      );
      expect(result.allowed, isFalse);
      expect(result.blockers.join(' '), contains('check digit'));
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
