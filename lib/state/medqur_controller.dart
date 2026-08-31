import 'package:flutter/foundation.dart';

import '../models/demo_data.dart';
import '../models/models.dart';

class MedqurController extends ChangeNotifier {
  StaffRole role = StaffRole.doctor;
  Facility? activeFacility;
  bool signedIn = false;
  int tabIndex = 0;

  final List<Patient> patients = List<Patient>.from(demoPatients);
  final List<MedicationTask> medicationTasks = <MedicationTask>[
    MedicationTask(
      id: 'MED-101',
      patientId: 'PT-10041',
      patientName: 'Alicia Grant',
      medication: 'Salbutamol',
      dose: '2.5 mg',
      route: 'Nebulized',
      frequency: 'Now',
      orderedBy: 'Dr. Maya Brown',
      orderedAt: DateTime(2026, 8, 31, 4, 12),
    ),
  ];

  final List<AuditEntry> auditEntries = <AuditEntry>[
    AuditEntry(
      title: 'Patient identity verified',
      detail: 'Alicia Grant · consented identity verification · demo NIDS result',
      timestamp: DateTime(2026, 8, 31, 4, 8),
      kind: 'identity',
    ),
    AuditEntry(
      title: 'Triage completed',
      detail: 'Alicia Grant · Manchester triage desk',
      timestamp: DateTime(2026, 8, 31, 4, 10),
      kind: 'triage',
    ),
    AuditEntry(
      title: 'Medication order signed',
      detail: 'Salbutamol 2.5 mg · nebulized · ordered by Dr. Maya Brown',
      timestamp: DateTime(2026, 8, 31, 4, 12),
      kind: 'medication',
    ),
  ];

  StaffProfile get profile {
    if (role == StaffRole.doctor) {
      return const StaffProfile(
        name: 'Dr. Maya Brown',
        role: StaffRole.doctor,
        staffId: 'MQ-7K4P-92XF',
        registration: 'Medical Council · DEMO-20418',
      );
    }
    return const StaffProfile(
      name: 'Nurse Renee Clarke',
      role: StaffRole.nurse,
      staffId: 'MQ-3R9N-61LX',
      registration: 'Nursing Council · DEMO-11872',
    );
  }

  void setRole(StaffRole value) {
    role = value;
    notifyListeners();
  }

  void signIn() {
    signedIn = true;
    notifyListeners();
  }

  void startShift(Facility facility) {
    activeFacility = facility;
    tabIndex = 0;
    auditEntries.insert(
      0,
      AuditEntry(
        title: 'Shift started',
        detail: '${profile.name} · ${facility.name}',
        timestamp: DateTime.now(),
        kind: 'session',
      ),
    );
    notifyListeners();
  }

  void selectTab(int value) {
    tabIndex = value;
    notifyListeners();
  }

  void clearFacility() {
    activeFacility = null;
    tabIndex = 0;
    notifyListeners();
  }

  void signOut() {
    signedIn = false;
    activeFacility = null;
    tabIndex = 0;
    notifyListeners();
  }

  void placeMedicationOrder({
    required Patient patient,
    required String medication,
    required String dose,
    required String route,
  }) {
    final task = MedicationTask(
      id: 'MED-${100 + medicationTasks.length + 1}',
      patientId: patient.id,
      patientName: patient.name,
      medication: medication,
      dose: dose,
      route: route,
      frequency: 'Now',
      orderedBy: profile.name,
      orderedAt: DateTime.now(),
    );
    medicationTasks.insert(0, task);
    auditEntries.insert(
      0,
      AuditEntry(
        title: 'Medication order signed',
        detail: '${patient.name} · $medication $dose · $route',
        timestamp: DateTime.now(),
        kind: 'medication',
      ),
    );
    notifyListeners();
  }

  void administerMedication(String taskId) {
    final index = medicationTasks.indexWhere((task) => task.id == taskId);
    if (index == -1) return;
    final old = medicationTasks[index];
    medicationTasks[index] = old.copyWith(status: MedicationTaskStatus.administered);
    auditEntries.insert(
      0,
      AuditEntry(
        title: 'Medication administered',
        detail: '${old.patientName} · ${old.medication} ${old.dose} · ${profile.name}',
        timestamp: DateTime.now(),
        kind: 'medication',
      ),
    );
    notifyListeners();
  }
}
