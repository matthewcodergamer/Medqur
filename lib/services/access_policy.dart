import '../clinical_models.dart';
import '../models.dart';

enum ClinicalAction {
  viewPatient,
  createEncounter,
  assignPatient,
  createMedicationOrder,
  administerMedication,
  createDiagnosticOrder,
  viewClinicalOrders,
  workDiagnosticOrder,
  uploadDiagnosticResult,
  receiveMedicationStock,
  verifyMedicationProduct,
  dispenseMedication,
  viewInventory,
  searchRecalls,
  generateUnitDoseLabel,
}

class AccessPolicy {
  const AccessPolicy._();

  /// Role-level baseline. The more specific discipline check is applied for
  /// diagnostic work through [allowsForStaff]/[canWorkOnDiagnosticOrder].
  static bool allows(StaffRole role, ClinicalAction action) {
    return switch ((role, action)) {
      (_, ClinicalAction.viewPatient) => true,

      // Doctors originate prescriptions and investigations. The voice-note
      // workflow also requires doctors to be able to administer medication.
      (StaffRole.doctor, ClinicalAction.createEncounter) => true,
      (StaffRole.doctor, ClinicalAction.assignPatient) => true,
      (StaffRole.doctor, ClinicalAction.createMedicationOrder) => true,
      (StaffRole.doctor, ClinicalAction.administerMedication) => true,
      (StaffRole.doctor, ClinicalAction.createDiagnosticOrder) => true,
      (StaffRole.doctor, ClinicalAction.viewClinicalOrders) => true,

      // Nursing / clinical-support staff can see orders and complete tasks that
      // are routed to their discipline, but cannot prescribe or order tests.
      (StaffRole.nurse, ClinicalAction.createEncounter) => true,
      (StaffRole.nurse, ClinicalAction.administerMedication) => true,
      (StaffRole.nurse, ClinicalAction.viewClinicalOrders) => true,
      (StaffRole.nurse, ClinicalAction.workDiagnosticOrder) => true,
      (StaffRole.nurse, ClinicalAction.uploadDiagnosticResult) => true,
      (StaffRole.nurse, ClinicalAction.viewInventory) => true,

      // Pharmacy is restricted to prescription fulfilment / medication and the
      // patient information required to do that safely.
      (StaffRole.pharmacist, ClinicalAction.receiveMedicationStock) => true,
      (StaffRole.pharmacist, ClinicalAction.verifyMedicationProduct) => true,
      (StaffRole.pharmacist, ClinicalAction.dispenseMedication) => true,
      (StaffRole.pharmacist, ClinicalAction.viewInventory) => true,
      (StaffRole.pharmacist, ClinicalAction.searchRecalls) => true,
      (StaffRole.pharmacist, ClinicalAction.generateUnitDoseLabel) => true,
      _ => false,
    };
  }

  static bool allowsForStaff(StaffProfile staff, ClinicalAction action) {
    if (!allows(staff.role, action)) return false;
    if (staff.role != StaffRole.nurse) return true;

    switch (action) {
      case ClinicalAction.workDiagnosticOrder:
      case ClinicalAction.uploadDiagnosticResult:
        return staff.staffCategory == StaffCategory.clinicalSupport;
      default:
        return true;
    }
  }

  /// Only the discipline that owns a task may complete it. Registered nurses
  /// may complete bedside ECG/EKG tasks in the prototype, matching the workflow
  /// described in the supplied voice note. They do not inherit imaging/lab
  /// permissions.
  static bool canWorkOnDiagnosticOrder(
    StaffProfile staff,
    DiagnosticOrder order,
  ) {
    if (staff.role == StaffRole.doctor) return false;
    if (staff.role != StaffRole.nurse) return false;

    final discipline = staff.clinicalDiscipline;
    final target = order.assignedDiscipline;
    if (discipline == target) return true;

    if ((discipline == ClinicalDiscipline.nursing ||
            discipline == ClinicalDiscipline.triage) &&
        target == ClinicalDiscipline.ecg) {
      return true;
    }

    // Generic support accounts are useful for a demo, but production workforce
    // identity must assign the exact discipline before this fallback is enabled.
    return discipline == ClinicalDiscipline.otherClinicalSupport;
  }

  static bool canCreateDiagnosticOrder(StaffProfile staff) =>
      allowsForStaff(staff, ClinicalAction.createDiagnosticOrder);

  static bool canAdministerMedication(StaffProfile staff) =>
      allowsForStaff(staff, ClinicalAction.administerMedication);
}
