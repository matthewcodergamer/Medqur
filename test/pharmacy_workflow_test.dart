import 'package:flutter_test/flutter_test.dart';
import 'package:medqur/models.dart';
import 'package:medqur/services/access_policy.dart';
import 'package:medqur/services/medication_identifier.dart';
import 'package:medqur/services/medication_safety.dart';

void main() {
  Patient patient() => Patient(
        id: 'PAT-PHARM-1',
        encounterId: 'ENC-PHARM-1',
        name: 'Prototype Patient',
        age: 38,
        sex: 'Female',
        nidsStatus: 'Prototype',
        chiefComplaint: 'Test',
        triage: TriageLevel.routine,
        status: PatientStatus.treatment,
        waitMinutes: 0,
        vitals: const {},
        allergies: const ['No known allergies'],
        timeline: [],
        medications: [],
      );

  group('AccessPolicy pharmacy roles', () {
    test('pharmacist can receive, verify and dispense but cannot prescribe', () {
      expect(
        AccessPolicy.allows(
          StaffRole.pharmacist,
          ClinicalAction.receiveMedicationStock,
        ),
        isTrue,
      );
      expect(
        AccessPolicy.allows(
          StaffRole.pharmacist,
          ClinicalAction.verifyMedicationProduct,
        ),
        isTrue,
      );
      expect(
        AccessPolicy.allows(
          StaffRole.pharmacist,
          ClinicalAction.dispenseMedication,
        ),
        isTrue,
      );
      expect(
        AccessPolicy.allows(
          StaffRole.pharmacist,
          ClinicalAction.createMedicationOrder,
        ),
        isFalse,
      );
      expect(
        AccessPolicy.allows(
          StaffRole.pharmacist,
          ClinicalAction.administerMedication,
        ),
        isFalse,
      );
    });
  });

  group('Medication scheduling safeguards', () {
    const validCode = '(01)09506000134352(17)271231(10)LOT-A';

    test('blocks administration before configured early window', () {
      final order = MedicationOrder(
        name: 'Prototype Medicine',
        dose: '1 tablet',
        route: 'Oral',
        frequency: 'Once',
        orderedBy: 'Dr Test',
        productCode: validCode,
        productVerified: true,
        scheduledAt: DateTime(2026, 9, 3, 12),
        earlyGraceMinutes: 30,
        lateGraceMinutes: 60,
      );
      final result = MedicationSafetyEngine.evaluate(
        patient: patient(),
        order: order,
        scan: MedicationIdentifierParser.parse(validCode),
        now: DateTime(2026, 9, 3, 11),
      );
      expect(result.allowed, isFalse);
      expect(result.blockers.join(' '), contains('earlier'));
    });

    test('allows a matching verified product inside the dose window', () {
      final order = MedicationOrder(
        name: 'Prototype Medicine',
        dose: '1 tablet',
        route: 'Oral',
        frequency: 'Once',
        orderedBy: 'Dr Test',
        productCode: validCode,
        productVerified: true,
        scheduledAt: DateTime(2026, 9, 3, 12),
      );
      final result = MedicationSafetyEngine.evaluate(
        patient: patient(),
        order: order,
        scan: MedicationIdentifierParser.parse(validCode),
        now: DateTime(2026, 9, 3, 12, 15),
      );
      expect(result.allowed, isTrue);
    });

    test('warns when a dose is late', () {
      final order = MedicationOrder(
        name: 'Prototype Medicine',
        dose: '1 tablet',
        route: 'Oral',
        frequency: 'Once',
        orderedBy: 'Dr Test',
        productCode: validCode,
        productVerified: true,
        scheduledAt: DateTime(2026, 9, 3, 12),
        lateGraceMinutes: 60,
      );
      final result = MedicationSafetyEngine.evaluate(
        patient: patient(),
        order: order,
        scan: MedicationIdentifierParser.parse(validCode),
        now: DateTime(2026, 9, 3, 13, 30),
      );
      expect(result.allowed, isTrue);
      expect(result.warnings.join(' '), contains('later'));
    });
  });
}
