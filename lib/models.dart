enum StaffRole { doctor, nurse, pharmacist }

enum TriageLevel { critical, urgent, moderate, routine }

enum PatientStatus { waiting, triaged, withDoctor, treatment, discharge }

enum FacilityClass {
  typeAHospital,
  typeBHospital,
  typeCHospital,
  specialistHospital,
  type1HealthCentre,
  type2HealthCentre,
  type3HealthCentre,
  type4HealthCentre,
  type5HealthCentre,
  other,
}

extension FacilityClassInfo on FacilityClass {
  String get label => switch (this) {
        FacilityClass.typeAHospital => 'Type A hospital',
        FacilityClass.typeBHospital => 'Type B hospital',
        FacilityClass.typeCHospital => 'Type C hospital',
        FacilityClass.specialistHospital => 'Specialist hospital',
        FacilityClass.type1HealthCentre => 'Type 1 health centre',
        FacilityClass.type2HealthCentre => 'Type 2 health centre',
        FacilityClass.type3HealthCentre => 'Type 3 health centre',
        FacilityClass.type4HealthCentre => 'Type 4 health centre',
        FacilityClass.type5HealthCentre => 'Type 5 health centre',
        FacilityClass.other => 'Other facility',
      };

  String get shortLabel => switch (this) {
        FacilityClass.typeAHospital => 'Type A',
        FacilityClass.typeBHospital => 'Type B',
        FacilityClass.typeCHospital => 'Type C',
        FacilityClass.specialistHospital => 'Specialist',
        FacilityClass.type1HealthCentre => 'Type 1',
        FacilityClass.type2HealthCentre => 'Type 2',
        FacilityClass.type3HealthCentre => 'Type 3',
        FacilityClass.type4HealthCentre => 'Type 4',
        FacilityClass.type5HealthCentre => 'Type 5',
        FacilityClass.other => 'Other',
      };

  String get careLevel => switch (this) {
        FacilityClass.typeAHospital => 'Comprehensive tertiary & secondary care',
        FacilityClass.typeBHospital => 'Standard secondary care',
        FacilityClass.typeCHospital => 'Basic district secondary care',
        FacilityClass.specialistHospital => 'National specialist care',
        FacilityClass.type1HealthCentre => 'Community preventive / primary care',
        FacilityClass.type2HealthCentre => 'Standard community primary care',
        FacilityClass.type3HealthCentre => 'Full-service district primary care',
        FacilityClass.type4HealthCentre => 'Parish-level comprehensive primary care',
        FacilityClass.type5HealthCentre => 'Comprehensive urban primary care hub',
        FacilityClass.other => 'Facility-specific care',
      };

  String? get populationBand => switch (this) {
        FacilityClass.type1HealthCentre => 'Typically under 4,000 people',
        FacilityClass.type2HealthCentre => 'Typically up to 12,000 people',
        FacilityClass.type3HealthCentre => 'Typically up to 20,000 people',
        FacilityClass.type4HealthCentre => 'Typically 20,000–30,000 people',
        FacilityClass.type5HealthCentre => 'Typically over 30,000 people',
        _ => null,
      };

  String get capabilitySummary => switch (this) {
        FacilityClass.typeAHospital =>
          'Major medical fields, subspecialties, advanced diagnostics, intensive care and blood-banking capability.',
        FacilityClass.typeBHospital =>
          'Core secondary disciplines including medicine, surgery, obstetrics/gynaecology, paediatrics, anaesthesia and emergency care.',
        FacilityClass.typeCHospital =>
          'General medicine, basic inpatient care, minor procedures, maternity/child care, basic imaging and laboratory support.',
        FacilityClass.specialistHospital =>
          'Focused national or regional services for a defined specialty or patient population.',
        FacilityClass.type1HealthCentre =>
          'Maternal and child health, routine immunisation, health education and basic first aid with visiting clinical staff.',
        FacilityClass.type2HealthCentre =>
          'Family health, routine curative care, basic pharmacy/dispensing, dental and environmental-health support.',
        FacilityClass.type3HealthCentre =>
          'Full-time medical officers plus expanded family health, dental, mental health, sexual health and disease-surveillance services.',
        FacilityClass.type4HealthCentre =>
          'High-volume parish services plus administration and coordination of community health programmes.',
        FacilityClass.type5HealthCentre =>
          'Large urban outpatient hub with multidisciplinary teams, diagnostics, specialised clinics and often extended hours.',
        FacilityClass.other => 'Capabilities vary by facility.',
      };

  String get referralRole => switch (this) {
        FacilityClass.typeAHospital =>
          'Highest general referral tier for cases requiring tertiary or advanced multidisciplinary care.',
        FacilityClass.typeBHospital =>
          'Secondary referral centre; escalate cases beyond core secondary capability to an appropriate Type A or specialist hospital.',
        FacilityClass.typeCHospital =>
          'District hospital; stabilise and transfer cases needing services beyond local capability to Type B, Type A or specialist care.',
        FacilityClass.specialistHospital =>
          'Receive referrals matching the hospital’s specialist service; other emergencies follow the general hospital network.',
        FacilityClass.type1HealthCentre ||
        FacilityClass.type2HealthCentre ||
        FacilityClass.type3HealthCentre ||
        FacilityClass.type4HealthCentre ||
        FacilityClass.type5HealthCentre =>
          'Primary-care entry point; refer or transfer patients who need hospital-level emergency, inpatient or specialist services.',
        FacilityClass.other =>
          'Referral pathway depends on the facility’s approved service scope.',
      };

  bool get isHospital => switch (this) {
        FacilityClass.typeAHospital ||
        FacilityClass.typeBHospital ||
        FacilityClass.typeCHospital ||
        FacilityClass.specialistHospital => true,
        _ => false,
      };

  bool get isHealthCentre => switch (this) {
        FacilityClass.type1HealthCentre ||
        FacilityClass.type2HealthCentre ||
        FacilityClass.type3HealthCentre ||
        FacilityClass.type4HealthCentre ||
        FacilityClass.type5HealthCentre => true,
        _ => false,
      };
}

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

  /// Short QR token: fewer modules than the legacy medqur://staff URI.
  String get badgeToken => 'MQS|$id';
}

class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.area,
    required this.type,
    this.classification = FacilityClass.other,
    this.parish = '',
    this.specialty,
    this.suggested = false,
  });

  final String id;
  final String name;
  final String area;
  final String type;
  final FacilityClass classification;
  final String parish;
  final String? specialty;
  final bool suggested;

  String get classificationLabel => classification.label;
  String get careLevel => classification.careLevel;
  String get capabilitySummary => specialty == null || specialty!.isEmpty
      ? classification.capabilitySummary
      : '${classification.capabilitySummary} Focus: $specialty.';
  String get referralRole => classification.referralRole;
  String? get populationBand => classification.populationBand;
  bool get isHospital => classification.isHospital;
  bool get isHealthCentre => classification.isHealthCentre;
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
    this.orderId,
    this.productId,
    this.dispenseId,
    this.lotId,
    this.scheduledAt,
    this.earlyGraceMinutes = 30,
    this.lateGraceMinutes = 60,
    this.productVerified = false,
  });

  final String name;
  final String dose;
  final String route;
  final String frequency;
  final String orderedBy;
  final bool administered;
  final String? productCode;
  final String? orderId;
  final String? productId;
  final String? dispenseId;
  final String? lotId;
  final DateTime? scheduledAt;
  final int earlyGraceMinutes;
  final int lateGraceMinutes;
  final bool productVerified;

  bool isTooEarly([DateTime? at]) {
    if (scheduledAt == null) return false;
    final now = at ?? DateTime.now();
    return now.isBefore(scheduledAt!.subtract(Duration(minutes: earlyGraceMinutes)));
  }

  bool isLate([DateTime? at]) {
    if (scheduledAt == null) return false;
    final now = at ?? DateTime.now();
    return now.isAfter(scheduledAt!.add(Duration(minutes: lateGraceMinutes)));
  }

  MedicationOrder copyWith({
    bool? administered,
    String? productCode,
    String? orderId,
    String? productId,
    String? dispenseId,
    String? lotId,
    DateTime? scheduledAt,
    int? earlyGraceMinutes,
    int? lateGraceMinutes,
    bool? productVerified,
  }) =>
      MedicationOrder(
        name: name,
        dose: dose,
        route: route,
        frequency: frequency,
        orderedBy: orderedBy,
        administered: administered ?? this.administered,
        productCode: productCode ?? this.productCode,
        orderId: orderId ?? this.orderId,
        productId: productId ?? this.productId,
        dispenseId: dispenseId ?? this.dispenseId,
        lotId: lotId ?? this.lotId,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        earlyGraceMinutes: earlyGraceMinutes ?? this.earlyGraceMinutes,
        lateGraceMinutes: lateGraceMinutes ?? this.lateGraceMinutes,
        productVerified: productVerified ?? this.productVerified,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'dose': dose,
        'route': route,
        'frequency': frequency,
        'orderedBy': orderedBy,
        'administered': administered,
        'productCode': productCode,
        'orderId': orderId,
        'productId': productId,
        'dispenseId': dispenseId,
        'lotId': lotId,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'earlyGraceMinutes': earlyGraceMinutes,
        'lateGraceMinutes': lateGraceMinutes,
        'productVerified': productVerified,
      };

  factory MedicationOrder.fromJson(Map<String, dynamic> json) =>
      MedicationOrder(
        name: json['name']?.toString() ?? '',
        dose: json['dose']?.toString() ?? '',
        route: json['route']?.toString() ?? '',
        frequency: json['frequency']?.toString() ?? '',
        orderedBy: json['orderedBy']?.toString() ?? '',
        administered: json['administered'] == true,
        productCode: json['productCode']?.toString(),
        orderId: json['orderId']?.toString(),
        productId: json['productId']?.toString(),
        dispenseId: json['dispenseId']?.toString(),
        lotId: json['lotId']?.toString(),
        scheduledAt: DateTime.tryParse(json['scheduledAt']?.toString() ?? ''),
        earlyGraceMinutes: (json['earlyGraceMinutes'] as num?)?.toInt() ?? 30,
        lateGraceMinutes: (json['lateGraceMinutes'] as num?)?.toInt() ?? 60,
        productVerified: json['productVerified'] == true,
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
    this.dateOfBirth,
    this.nationalIdNumber,
    this.encounterId,
    this.facilityName,
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
  final String? dateOfBirth;
  final String? nationalIdNumber;
  final String? encounterId;
  final String? facilityName;
  String? assignedStaffId;
  String? assignedStaffName;

  String get effectiveEncounterId =>
      encounterId == null || encounterId!.trim().isEmpty
          ? 'ENC-$id'
          : encounterId!;

  /// Short QR token: the printed code does not contain patient/clinical data.
  String get encounterToken => 'MQE|$effectiveEncounterId';

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
        'dateOfBirth': dateOfBirth,
        'nationalIdNumber': nationalIdNumber,
        'encounterId': encounterId,
        'facilityName': facilityName,
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
      triage: TriageLevel.values.firstWhere(
        (item) => item.name == triageName,
        orElse: () => TriageLevel.routine,
      ),
      status: PatientStatus.values.firstWhere(
        (item) => item.name == statusName,
        orElse: () => PatientStatus.waiting,
      ),
      waitMinutes: (json['waitMinutes'] as num?)?.toInt() ?? 0,
      vitals: (json['vitals'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, value.toString())),
      allergies: (json['allergies'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      timeline: (json['timeline'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      medications: (json['medications'] as List<dynamic>? ?? [])
          .map((item) => MedicationOrder.fromJson(item as Map<String, dynamic>))
          .toList(),
      dateOfBirth: json['dateOfBirth']?.toString(),
      nationalIdNumber: json['nationalIdNumber']?.toString(),
      encounterId: json['encounterId']?.toString(),
      facilityName: json['facilityName']?.toString(),
      assignedStaffId: json['assignedStaffId']?.toString(),
      assignedStaffName: json['assignedStaffName']?.toString(),
    );
  }
}
