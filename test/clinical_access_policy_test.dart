import 'package:flutter_test/flutter_test.dart';
import 'package:medqur/clinical_models.dart';
import 'package:medqur/mock_data.dart';
import 'package:medqur/services/access_policy.dart';

void main() {
  test('doctor owns prescribing and test ordering and may administer medication', () {
    expect(
      AccessPolicy.allowsForStaff(
        demoDoctor,
        ClinicalAction.createMedicationOrder,
      ),
      isTrue,
    );
    expect(
      AccessPolicy.allowsForStaff(
        demoDoctor,
        ClinicalAction.createDiagnosticOrder,
      ),
      isTrue,
    );
    expect(AccessPolicy.canAdministerMedication(demoDoctor), isTrue);
  });

  test('nurse can administer but cannot prescribe or originate tests', () {
    expect(AccessPolicy.canAdministerMedication(demoNurse), isTrue);
    expect(
      AccessPolicy.allowsForStaff(
        demoNurse,
        ClinicalAction.createMedicationOrder,
      ),
      isFalse,
    );
    expect(
      AccessPolicy.allowsForStaff(
        demoNurse,
        ClinicalAction.createDiagnosticOrder,
      ),
      isFalse,
    );
  });

  test('clinical support work is discipline routed', () {
    final xray = DiagnosticOrder(
      id: 'DX-1',
      patientId: 'P1',
      encounterId: 'E1',
      facilityId: 'MRH',
      type: DiagnosticOrderType.xray,
      studyName: 'Chest X-ray',
      instructions: '',
      priority: DiagnosticOrderPriority.routine,
      orderedBy: demoDoctor.name,
      orderedAt: DateTime(2026, 9, 5),
    );
    final ecg = DiagnosticOrder(
      id: 'DX-2',
      patientId: 'P1',
      encounterId: 'E1',
      facilityId: 'MRH',
      type: DiagnosticOrderType.ecg,
      studyName: '12-lead ECG',
      instructions: '',
      priority: DiagnosticOrderPriority.urgent,
      orderedBy: demoDoctor.name,
      orderedAt: DateTime(2026, 9, 5),
    );

    expect(AccessPolicy.canWorkOnDiagnosticOrder(demoRadiographer, xray), isTrue);
    expect(AccessPolicy.canWorkOnDiagnosticOrder(demoNurse, xray), isFalse);
    expect(AccessPolicy.canWorkOnDiagnosticOrder(demoNurse, ecg), isTrue);
    expect(AccessPolicy.canWorkOnDiagnosticOrder(demoLabTechnologist, xray), isFalse);
  });

  test('pharmacy can view patients but cannot prescribe or perform tests', () {
    expect(
      AccessPolicy.allowsForStaff(demoPharmacist, ClinicalAction.viewPatient),
      isTrue,
    );
    expect(
      AccessPolicy.allowsForStaff(
        demoPharmacist,
        ClinicalAction.createMedicationOrder,
      ),
      isFalse,
    );
    expect(
      AccessPolicy.allowsForStaff(
        demoPharmacist,
        ClinicalAction.createDiagnosticOrder,
      ),
      isFalse,
    );
    expect(AccessPolicy.canAdministerMedication(demoPharmacist), isFalse);
  });
}
