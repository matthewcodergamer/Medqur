import 'dart:convert';

import 'models.dart';

/// High-level workforce grouping used by the Medqur clinical UI.
///
/// The existing StaffRole enum is intentionally kept stable for compatibility
/// with the current prototype. StaffRole.nurse represents the broader
/// non-pharmacy clinical-support group; the worker's actual discipline is
/// derived from the authoritative role/title when available.
enum StaffCategory {
  doctor,
  clinicalSupport,
  pharmacy,
}

enum ClinicalDiscipline {
  medicine,
  nursing,
  triage,
  pharmacy,
  pharmacyTechnician,
  radiography,
  ctImaging,
  mriImaging,
  laboratory,
  ecg,
  respiratoryTherapy,
  ultrasound,
  otherClinicalSupport,
}

extension ClinicalDisciplineInfo on ClinicalDiscipline {
  String get label => switch (this) {
        ClinicalDiscipline.medicine => 'Medical',
        ClinicalDiscipline.nursing => 'Nursing',
        ClinicalDiscipline.triage => 'Triage nursing',
        ClinicalDiscipline.pharmacy => 'Pharmacy',
        ClinicalDiscipline.pharmacyTechnician => 'Pharmacy technician',
        ClinicalDiscipline.radiography => 'X-ray / radiography',
        ClinicalDiscipline.ctImaging => 'CT imaging',
        ClinicalDiscipline.mriImaging => 'MRI',
        ClinicalDiscipline.laboratory => 'Laboratory',
        ClinicalDiscipline.ecg => 'ECG / cardiac diagnostics',
        ClinicalDiscipline.respiratoryTherapy => 'Respiratory therapy',
        ClinicalDiscipline.ultrasound => 'Ultrasound',
        ClinicalDiscipline.otherClinicalSupport => 'Clinical support',
      };

  IconSemantic get iconSemantic => switch (this) {
        ClinicalDiscipline.medicine => IconSemantic.doctor,
        ClinicalDiscipline.nursing || ClinicalDiscipline.triage =>
          IconSemantic.nursing,
        ClinicalDiscipline.pharmacy || ClinicalDiscipline.pharmacyTechnician =>
          IconSemantic.pharmacy,
        ClinicalDiscipline.radiography ||
        ClinicalDiscipline.ctImaging ||
        ClinicalDiscipline.mriImaging ||
        ClinicalDiscipline.ultrasound =>
          IconSemantic.imaging,
        ClinicalDiscipline.laboratory => IconSemantic.laboratory,
        ClinicalDiscipline.ecg => IconSemantic.cardiac,
        ClinicalDiscipline.respiratoryTherapy => IconSemantic.respiratory,
        ClinicalDiscipline.otherClinicalSupport => IconSemantic.support,
      };
}

/// Lightweight semantic icon category so the model layer does not import
/// Flutter/material.dart.
enum IconSemantic {
  doctor,
  nursing,
  pharmacy,
  imaging,
  laboratory,
  cardiac,
  respiratory,
  support,
}

extension StaffClinicalProfile on StaffProfile {
  StaffCategory get staffCategory => switch (role) {
        StaffRole.doctor => StaffCategory.doctor,
        StaffRole.pharmacist => StaffCategory.pharmacy,
        StaffRole.nurse => StaffCategory.clinicalSupport,
      };

  ClinicalDiscipline get clinicalDiscipline {
    if (role == StaffRole.doctor) return ClinicalDiscipline.medicine;
    if (role == StaffRole.pharmacist) return ClinicalDiscipline.pharmacy;

    final value = '$title $registration'.toLowerCase();
    if (value.contains('triage')) return ClinicalDiscipline.triage;
    if (value.contains('radiograph') ||
        value.contains('x-ray') ||
        value.contains('xray')) {
      return ClinicalDiscipline.radiography;
    }
    if (value.contains('computed tomography') ||
        value.contains('cat scan') ||
        RegExp(r'\bct\b').hasMatch(value)) {
      return ClinicalDiscipline.ctImaging;
    }
    if (value.contains('mri') || value.contains('magnetic resonance')) {
      return ClinicalDiscipline.mriImaging;
    }
    if (value.contains('laboratory') ||
        value.contains('medical technologist') ||
        value.contains('lab tech')) {
      return ClinicalDiscipline.laboratory;
    }
    if (value.contains('ecg') ||
        value.contains('ekg') ||
        value.contains('cardiac technician')) {
      return ClinicalDiscipline.ecg;
    }
    if (value.contains('respiratory')) {
      return ClinicalDiscipline.respiratoryTherapy;
    }
    if (value.contains('ultrasound') || value.contains('sonograph')) {
      return ClinicalDiscipline.ultrasound;
    }
    if (value.contains('nurse') || value.contains('nursing')) {
      return ClinicalDiscipline.nursing;
    }
    return ClinicalDiscipline.otherClinicalSupport;
  }

  String get workforceLabel => switch (staffCategory) {
        StaffCategory.doctor => 'Doctor',
        StaffCategory.pharmacy => 'Pharmacy',
        StaffCategory.clinicalSupport => 'Clinical support',
      };
}

enum DiagnosticOrderType {
  xray,
  ctScan,
  mri,
  ultrasound,
  laboratory,
  ecg,
  respiratory,
  other,
}

extension DiagnosticOrderTypeInfo on DiagnosticOrderType {
  String get label => switch (this) {
        DiagnosticOrderType.xray => 'X-ray',
        DiagnosticOrderType.ctScan => 'CT scan',
        DiagnosticOrderType.mri => 'MRI',
        DiagnosticOrderType.ultrasound => 'Ultrasound',
        DiagnosticOrderType.laboratory => 'Laboratory test',
        DiagnosticOrderType.ecg => 'ECG / EKG',
        DiagnosticOrderType.respiratory => 'Respiratory test',
        DiagnosticOrderType.other => 'Other clinical test',
      };

  ClinicalDiscipline get targetDiscipline => switch (this) {
        DiagnosticOrderType.xray => ClinicalDiscipline.radiography,
        DiagnosticOrderType.ctScan => ClinicalDiscipline.ctImaging,
        DiagnosticOrderType.mri => ClinicalDiscipline.mriImaging,
        DiagnosticOrderType.ultrasound => ClinicalDiscipline.ultrasound,
        DiagnosticOrderType.laboratory => ClinicalDiscipline.laboratory,
        DiagnosticOrderType.ecg => ClinicalDiscipline.ecg,
        DiagnosticOrderType.respiratory => ClinicalDiscipline.respiratoryTherapy,
        DiagnosticOrderType.other => ClinicalDiscipline.otherClinicalSupport,
      };

  String get defaultStudyName => switch (this) {
        DiagnosticOrderType.xray => 'X-ray examination',
        DiagnosticOrderType.ctScan => 'CT examination',
        DiagnosticOrderType.mri => 'MRI examination',
        DiagnosticOrderType.ultrasound => 'Ultrasound examination',
        DiagnosticOrderType.laboratory => 'Laboratory investigation',
        DiagnosticOrderType.ecg => '12-lead ECG',
        DiagnosticOrderType.respiratory => 'Respiratory assessment',
        DiagnosticOrderType.other => 'Clinical investigation',
      };
}

enum DiagnosticOrderPriority {
  routine,
  urgent,
  stat,
}

extension DiagnosticOrderPriorityInfo on DiagnosticOrderPriority {
  String get label => switch (this) {
        DiagnosticOrderPriority.routine => 'Routine',
        DiagnosticOrderPriority.urgent => 'Urgent',
        DiagnosticOrderPriority.stat => 'STAT',
      };
}

enum DiagnosticOrderStatus {
  ordered,
  inProgress,
  completed,
  cancelled,
}

extension DiagnosticOrderStatusInfo on DiagnosticOrderStatus {
  String get label => switch (this) {
        DiagnosticOrderStatus.ordered => 'Ordered',
        DiagnosticOrderStatus.inProgress => 'In progress',
        DiagnosticOrderStatus.completed => 'Completed',
        DiagnosticOrderStatus.cancelled => 'Cancelled',
      };
}

class DiagnosticAttachment {
  const DiagnosticAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.base64Data,
    required this.uploadedBy,
    required this.uploadedAt,
    this.note = '',
  });

  final String id;
  final String fileName;
  final String mimeType;
  final String base64Data;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String note;

  int get byteLength {
    try {
      return base64Decode(base64Data).length;
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'mimeType': mimeType,
        'base64Data': base64Data,
        'uploadedBy': uploadedBy,
        'uploadedAt': uploadedAt.toIso8601String(),
        'note': note,
      };

  factory DiagnosticAttachment.fromJson(Map<String, dynamic> json) =>
      DiagnosticAttachment(
        id: json['id']?.toString() ?? '',
        fileName: json['fileName']?.toString() ?? 'attachment',
        mimeType: json['mimeType']?.toString() ?? 'application/octet-stream',
        base64Data: json['base64Data']?.toString() ?? '',
        uploadedBy: json['uploadedBy']?.toString() ?? 'Unknown',
        uploadedAt: DateTime.tryParse(json['uploadedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        note: json['note']?.toString() ?? '',
      );
}

class DiagnosticOrder {
  DiagnosticOrder({
    required this.id,
    required this.patientId,
    required this.encounterId,
    required this.facilityId,
    required this.type,
    required this.studyName,
    required this.instructions,
    required this.priority,
    required this.orderedBy,
    required this.orderedAt,
    this.status = DiagnosticOrderStatus.ordered,
    this.resultSummary = '',
    List<DiagnosticAttachment>? attachments,
    this.startedBy,
    this.startedAt,
    this.completedBy,
    this.completedAt,
  }) : attachments = attachments ?? <DiagnosticAttachment>[];

  final String id;
  final String patientId;
  final String encounterId;
  final String facilityId;
  final DiagnosticOrderType type;
  final String studyName;
  final String instructions;
  final DiagnosticOrderPriority priority;
  final String orderedBy;
  final DateTime orderedAt;

  DiagnosticOrderStatus status;
  String resultSummary;
  final List<DiagnosticAttachment> attachments;
  String? startedBy;
  DateTime? startedAt;
  String? completedBy;
  DateTime? completedAt;

  ClinicalDiscipline get assignedDiscipline => type.targetDiscipline;

  bool get isOpen =>
      status == DiagnosticOrderStatus.ordered ||
      status == DiagnosticOrderStatus.inProgress;

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'encounterId': encounterId,
        'facilityId': facilityId,
        'type': type.name,
        'studyName': studyName,
        'instructions': instructions,
        'priority': priority.name,
        'orderedBy': orderedBy,
        'orderedAt': orderedAt.toIso8601String(),
        'status': status.name,
        'resultSummary': resultSummary,
        'attachments': attachments.map((item) => item.toJson()).toList(),
        'startedBy': startedBy,
        'startedAt': startedAt?.toIso8601String(),
        'completedBy': completedBy,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory DiagnosticOrder.fromJson(Map<String, dynamic> json) =>
      DiagnosticOrder(
        id: json['id']?.toString() ?? '',
        patientId: json['patientId']?.toString() ?? '',
        encounterId: json['encounterId']?.toString() ?? '',
        facilityId: json['facilityId']?.toString() ?? '',
        type: DiagnosticOrderType.values.firstWhere(
          (item) => item.name == json['type']?.toString(),
          orElse: () => DiagnosticOrderType.other,
        ),
        studyName: json['studyName']?.toString() ?? 'Clinical investigation',
        instructions: json['instructions']?.toString() ?? '',
        priority: DiagnosticOrderPriority.values.firstWhere(
          (item) => item.name == json['priority']?.toString(),
          orElse: () => DiagnosticOrderPriority.routine,
        ),
        orderedBy: json['orderedBy']?.toString() ?? '',
        orderedAt: DateTime.tryParse(json['orderedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        status: DiagnosticOrderStatus.values.firstWhere(
          (item) => item.name == json['status']?.toString(),
          orElse: () => DiagnosticOrderStatus.ordered,
        ),
        resultSummary: json['resultSummary']?.toString() ?? '',
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => DiagnosticAttachment.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ))
            .toList(),
        startedBy: json['startedBy']?.toString(),
        startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? ''),
        completedBy: json['completedBy']?.toString(),
        completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
      );
}
