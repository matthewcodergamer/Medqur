import '../models.dart';

enum ClinicalAction {
  viewPatient,
  createEncounter,
  assignPatient,
  createMedicationOrder,
  administerMedication,
  receiveMedicationStock,
  verifyMedicationProduct,
  dispenseMedication,
  viewInventory,
  searchRecalls,
  generateUnitDoseLabel,
}

class AccessPolicy {
  const AccessPolicy._();

  static bool allows(StaffRole role, ClinicalAction action) {
    return switch ((role, action)) {
      (_, ClinicalAction.viewPatient) => true,
      (StaffRole.doctor || StaffRole.nurse, ClinicalAction.createEncounter) => true,
      (StaffRole.doctor, ClinicalAction.assignPatient) => true,
      (StaffRole.doctor, ClinicalAction.createMedicationOrder) => true,
      (StaffRole.nurse, ClinicalAction.administerMedication) => true,
      (StaffRole.pharmacist, ClinicalAction.receiveMedicationStock) => true,
      (StaffRole.pharmacist, ClinicalAction.verifyMedicationProduct) => true,
      (StaffRole.pharmacist, ClinicalAction.dispenseMedication) => true,
      (StaffRole.pharmacist || StaffRole.nurse, ClinicalAction.viewInventory) => true,
      (StaffRole.pharmacist, ClinicalAction.searchRecalls) => true,
      (StaffRole.pharmacist, ClinicalAction.generateUnitDoseLabel) => true,
      _ => false,
    };
  }
}
