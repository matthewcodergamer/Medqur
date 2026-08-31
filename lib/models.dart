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

  String get badgeToken => 'medqur://staff/$id';
}

class Facility {
  const Facility({required this.id, required this.name, required this.area, required this.type, this.suggested = false});
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
    this.productCode,
  });

  final String name;
  final String dose;
  final String route;
  final String frequency;
  final String orderedBy;
  final bool administered;
  final String? productCode;

  MedicationOrder copyWith({bool? administered, String? productCode}) => MedicationOrder(
        name: name,
        dose: dose,
        route: route,
        frequency: frequency,
        orderedBy: orderedBy,
        administered: administered ?? this.administered,
        productCode: productCode ?? this.productCode,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'dose': dose,
        'route': route,
        'frequency': frequency,
        'orderedBy': orderedBy,
        'administered': administered,
        'productCode': productCode,
      };

  factory MedicationOrder.fromJson(Map<String, dynamic> json) => MedicationOrder(
        name: json['name']?.toString() ?? '',
        dose: json['dose']?.toString() ?? '',
        route: json['route']?.toString() ?? '',
        frequency: json['frequency']?.toString() ?? '',
        orderedBy: json['orderedBy']?.toString() ?? '',
        administered: json['administered'] == true,
        productCode: json['productCode']?.toString(),
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
    this.assignedStaffId,
    this.assignedStaffName,
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
  String? assignedStaffId;
  String? assignedStaffName;

  String get encounterToken => 'medqur://encounter/$id';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'sex': sex,
        'nidsStatus': nidsStatus,
        'chiefComplaint': chiefComplaint,
        'triage': triage.name,
        'status': status.name,
        'waitMinutes': waitMinutes,
        'vitals': vitals,
        'allergies': allergies,
        'timeline': timeline,
        'medications': medications.map((item) => item.toJson()).toList(),
        'assignedStaffId': assignedStaffId,
        'assignedStaffName': assignedStaffName,
      };

  factory Patient.fromJson(Map<String, dynamic> json) {
    final triageName = json['triage']?.toString();
    final statusName = json['status']?.toString();
    return Patient(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown patient',
      age: (json['age'] as num?)?.toInt() ?? 0,
      sex: json['sex']?.toString() ?? 'Unknown',
      nidsStatus: json['nidsStatus']?.toString() ?? 'Identity pending',
      chiefComplaint: json['chiefComplaint']?.toString() ?? '',
      triage: TriageLevel.values.firstWhere((item) => item.name == triageName, orElse: () => TriageLevel.routine),
      status: PatientStatus.values.firstWhere((item) => item.name == statusName, orElse: () => PatientStatus.waiting),
      waitMinutes: (json['waitMinutes'] as num?)?.toInt() ?? 0,
      vitals: (json['vitals'] as Map<String, dynamic>? ?? {}).map((key, value) => MapEntry(key, value.toString())),
      allergies: (json['allergies'] as List<dynamic>? ?? []).map((item) => item.toString()).toList(),
      timeline: (json['timeline'] as List<dynamic>? ?? []).map((item) => item.toString()).toList(),
      medications: (json['medications'] as List<dynamic>? ?? [])
          .map((item) => MedicationOrder.fromJson(item as Map<String, dynamic>))
          .toList(),
      assignedStaffId: json['assignedStaffId']?.toString(),
      assignedStaffName: json['assignedStaffName']?.toString(),
    );
  }
}
