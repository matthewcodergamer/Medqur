enum StaffRole { doctor, nurse }

enum TriageLevel { critical, urgent, moderate, routine }

enum PatientStatus { waiting, triaged, withDoctor, treatment, discharge }

class StaffProfile {
  const StaffProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.title,
    required this.registration,
    required this.facilities,
  });

  final String id;
  final String name;
  final StaffRole role;
  final String title;
  final String registration;
  final List<Facility> facilities;
}

class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.area,
    required this.type,
    this.suggested = false,
  });

  final String id;
  final String name;
  final String area;
  final String type;
  final bool suggested;
}

class MedicationOrder {
  const MedicationOrder({
    required this.name,
    required this.dose,
    required this.route,
    required this.frequency,
    required this.orderedBy,
    this.administered = false,
  });

  final String name;
  final String dose;
  final String route;
  final String frequency;
  final String orderedBy;
  final bool administered;

  MedicationOrder copyWith({bool? administered}) => MedicationOrder(
        name: name,
        dose: dose,
        route: route,
        frequency: frequency,
        orderedBy: orderedBy,
        administered: administered ?? this.administered,
      );
}

class Patient {
  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.sex,
    required this.nidsStatus,
    required this.chiefComplaint,
    required this.triage,
    required this.status,
    required this.waitMinutes,
    required this.vitals,
    required this.allergies,
    required this.timeline,
    required this.medications,
  });

  final String id;
  final String name;
  final int age;
  final String sex;
  final String nidsStatus;
  final String chiefComplaint;
  final TriageLevel triage;
  PatientStatus status;
  int waitMinutes;
  final Map<String, String> vitals;
  final List<String> allergies;
  final List<String> timeline;
  final List<MedicationOrder> medications;
}
