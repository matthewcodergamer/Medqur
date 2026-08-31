import '../models.dart';

enum ClinicalAction { viewPatient, createEncounter, assignPatient, createMedicationOrder, administerMedication }

class AccessPolicy {
  const AccessPolicy._();

  static bool allows(StaffRole role, ClinicalAction action) {
    return switch ((role, action)) {
      (_, ClinicalAction.viewPatient) => true,
      (_, ClinicalAction.createEncounter) => true,
      (StaffRole.doctor, ClinicalAction.assignPatient) => true,
      (StaffRole.doctor, ClinicalAction.createMedicationOrder) => true,
      (StaffRole.nurse, ClinicalAction.administerMedication) => true,
      _ => false,
    };
  }
}
