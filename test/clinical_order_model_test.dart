import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medqur/clinical_models.dart';

void main() {
  test('diagnostic order round-trips with result attachments', () {
    final order = DiagnosticOrder(
      id: 'DX-100',
      patientId: 'MQP-1',
      encounterId: 'ENC-1',
      facilityId: 'MRH',
      type: DiagnosticOrderType.ecg,
      studyName: '12-lead ECG',
      instructions: 'Chest pain',
      priority: DiagnosticOrderPriority.urgent,
      orderedBy: 'Dr. Test',
      orderedAt: DateTime.utc(2026, 9, 5, 12),
      status: DiagnosticOrderStatus.completed,
      resultSummary: 'Sinus rhythm',
      attachments: [
        DiagnosticAttachment(
          id: 'ATT-1',
          fileName: 'ecg.jpg',
          mimeType: 'image/jpeg',
          base64Data: base64Encode([1, 2, 3, 4]),
          uploadedBy: 'Nurse Test',
          uploadedAt: DateTime.utc(2026, 9, 5, 12, 10),
        ),
      ],
      completedBy: 'Nurse Test',
      completedAt: DateTime.utc(2026, 9, 5, 12, 11),
    );

    final restored = DiagnosticOrder.fromJson(order.toJson());
    expect(restored.type, DiagnosticOrderType.ecg);
    expect(restored.assignedDiscipline, ClinicalDiscipline.ecg);
    expect(restored.status, DiagnosticOrderStatus.completed);
    expect(restored.resultSummary, 'Sinus rhythm');
    expect(restored.attachments, hasLength(1));
    expect(restored.attachments.single.byteLength, 4);
  });

  test('diagnostic order types route to the correct support disciplines', () {
    expect(DiagnosticOrderType.xray.targetDiscipline,
        ClinicalDiscipline.radiography);
    expect(DiagnosticOrderType.ctScan.targetDiscipline,
        ClinicalDiscipline.ctImaging);
    expect(DiagnosticOrderType.laboratory.targetDiscipline,
        ClinicalDiscipline.laboratory);
    expect(DiagnosticOrderType.ecg.targetDiscipline, ClinicalDiscipline.ecg);
  });
}
