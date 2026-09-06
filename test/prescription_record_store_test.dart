import 'package:flutter_test/flutter_test.dart';
import 'package:medqur/services/prescription_record_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

PrescriptionRecord _record({
  required String id,
  required int revision,
  String status = 'active',
  String? supersedesId,
  String? reason,
}) =>
    PrescriptionRecord(
      id: id,
      patientId: 'MQP-TEST',
      encounterId: 'ENC-TEST',
      facilityId: 'MRH',
      medication: 'Amoxicillin',
      dose: '5 mg',
      route: 'Oral',
      frequency: revision == 1 ? '1x per day' : '3x per day',
      duration: '7 days',
      instructions: 'Take with water',
      orderedById: '482731',
      orderedByName: 'Dr. Maya Brown',
      orderedAt: DateTime.utc(2026, 9, 6, 1, revision),
      signatureDigest: 'a' * 64,
      signatureSignedAt: DateTime.utc(2026, 9, 6, 1, revision),
      signatureMethod: 'stored-drawn',
      copyNumber: 'RX-TEST-R$revision',
      revision: revision,
      status: status,
      supersedesId: supersedesId,
      amendmentReason: reason,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('amendment keeps old signed revision and supersedes it', () async {
    const store = PrescriptionRecordStore();
    final first = _record(id: 'RXO-1', revision: 1);
    final second = _record(
      id: 'RXO-2',
      revision: 2,
      supersedesId: first.id,
      reason: 'Increase frequency after reassessment',
    );

    await store.add(first);
    await store.addRevision(previous: first, revision: second);

    final history = await store.forPatient('MQP-TEST');
    expect(history.length, 2);
    expect(history.first.id, 'RXO-2');
    expect(history.first.isActive, isTrue);
    expect(history.first.amendmentReason,
        'Increase frequency after reassessment');
    expect(history.last.id, 'RXO-1');
    expect(history.last.isSuperseded, isTrue);
  });

  test('dispensing marks prescription and keeps dispense audit fields', () async {
    const store = PrescriptionRecordStore();
    final record = _record(id: 'RXO-1', revision: 1);
    await store.add(record);

    await store.markDispensed(
      record: record,
      staffId: '739182',
      dispenseId: 'DSP-TEST-1',
    );

    final records = await store.forFacility('MRH');
    expect(records.single.isDispensed, isTrue);
    expect(records.single.dispensedById, '739182');
    expect(records.single.dispenseId, 'DSP-TEST-1');
    expect(records.single.dispensedAt, isNotNull);
  });
}
