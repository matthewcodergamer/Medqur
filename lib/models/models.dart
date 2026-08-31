enum StaffRole { doctor, nurse }

enum TriageLevel { critical, urgent, standard, low }

enum MedicationTaskStatus { pending, administered }

class StaffProfile {
  const StaffProfile({
    required this.name,
    required this.role,
    required this.staffId,
    required this.registration,
  });

  final String name;
  final StaffRole role;
  final String staffId;
  final String registration;

  String get roleLabel => role == StaffRole.doctor ? 'Doctor' : 'Registered Nurse';
}

class Facility {
  const Facility({
    required this.name,
    required this.type,
    required this.parish,
    this.suggested = false,
  });

  final String name;
  final String type;
  final String parish;
  final bool suggested;
}

class Patient {
  const Patient({
    required this.id,
    required this.encounterId,
    required this.name,
    required this.age,
    required this.sex,
    required this.chiefComplaint,
    required this.triageLevel,
    required this.waitMinutes,
    required this.vitals,
    required this.allergies,
    required this.history,
    required this.triageNote,
    required this.nidsVerified,
  });

  final String id;
  final String encounterId;
  final String name;
  final int age;
  final String sex;
  final String chiefComplaint;
  final TriageLevel triageLevel;
  final int waitMinutes;
  final Map<String, String> vitals;
  final List<String> allergies;
  final List<String> history;
  final String triageNote;
  final bool nidsVerified;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }
}

class MedicationTask {
  const MedicationTask({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.medication,
    required this.dose,
    required this.route,
    required this.frequency,
    required this.orderedBy,
    required this.orderedAt,
    this.status = MedicationTaskStatus.pending,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String medication;
  final String dose;
  final String route;
  final String frequency;
  final String orderedBy;
  final DateTime orderedAt;
  final MedicationTaskStatus status;

  MedicationTask copyWith({MedicationTaskStatus? status}) {
    return MedicationTask(
      id: id,
      patientId: patientId,
      patientName: patientName,
      medication: medication,
      dose: dose,
      route: route,
      frequency: frequency,
      orderedBy: orderedBy,
      orderedAt: orderedAt,
      status: status ?? this.status,
    );
  }
}

class AuditEntry {
  const AuditEntry({
    required this.title,
    required this.detail,
    required this.timestamp,
    required this.kind,
  });

  final String title;
  final String detail;
  final DateTime timestamp;
  final String kind;
}
