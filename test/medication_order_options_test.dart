import 'package:flutter_test/flutter_test.dart';
import 'package:medqur/clinical_clock.dart';
import 'package:medqur/medication_order_options.dart';

void main() {
  group('structured medication directions', () {
    test('dose selector is exactly 1 through 100', () {
      expect(StructuredMedicationDirections.doseValues.length, 100);
      expect(StructuredMedicationDirections.doseValues.first, 1);
      expect(StructuredMedicationDirections.doseValues.last, 100);
      expect(
        StructuredMedicationDirections.doseValues,
        orderedEquals(List<int>.generate(100, (index) => index + 1)),
      );
    });

    test('frequency selector is 1x through 10x per period', () {
      expect(
        StructuredMedicationDirections.frequencyCounts,
        orderedEquals(List<int>.generate(10, (index) => index + 1)),
      );
      const directions = StructuredMedicationDirections(
        doseValue: 5,
        doseUnit: MedicationDoseUnit.milligram,
        frequencyCount: 3,
        frequencyPeriod: MedicationFrequencyPeriod.day,
        dueMode: MedicationDueMode.immediate,
      );
      expect(directions.doseText, '5 mg');
      expect(directions.frequencyText, '3x per day');
    });

    test('supported periods are hour, day and week', () {
      expect(
        MedicationFrequencyPeriod.values.map((item) => item.label).toList(),
        ['hour', 'day', 'week'],
      );
    });

    test('supported units include requested mass and volume units', () {
      expect(
        MedicationDoseUnit.values.map((item) => item.symbol).toSet(),
        containsAll(<String>{'g', 'mg', 'mcg', 'mL', 'µL', 'L'}),
      );
    });

    test('immediate due mode resolves to now', () {
      final now = DateTime(2026, 9, 5, 18, 37);
      const directions = StructuredMedicationDirections(
        doseValue: 1,
        doseUnit: MedicationDoseUnit.gram,
        frequencyCount: 1,
        frequencyPeriod: MedicationFrequencyPeriod.day,
        dueMode: MedicationDueMode.immediate,
      );
      expect(directions.effectiveDueAt(now: now), now);
    });

    test('scheduled due mode requires and returns selected date/time', () {
      final scheduled = DateTime(2026, 9, 7, 14, 30);
      final directions = StructuredMedicationDirections(
        doseValue: 2,
        doseUnit: MedicationDoseUnit.millilitre,
        frequencyCount: 2,
        frequencyPeriod: MedicationFrequencyPeriod.day,
        dueMode: MedicationDueMode.scheduled,
        scheduledAt: scheduled,
      );
      expect(directions.effectiveDueAt(), scheduled);

      const invalid = StructuredMedicationDirections(
        doseValue: 2,
        doseUnit: MedicationDoseUnit.millilitre,
        frequencyCount: 2,
        frequencyPeriod: MedicationFrequencyPeriod.day,
        dueMode: MedicationDueMode.scheduled,
      );
      expect(() => invalid.effectiveDueAt(), throwsStateError);
    });
  });

  group('product strength preset', () {
    test('maps an exact 1-100 strength into selectors', () {
      final preset = MedicationDosePreset.tryParse('20 mg tablet');
      expect(preset, isNotNull);
      expect(preset!.value, 20);
      expect(preset.unit, MedicationDoseUnit.milligram);
    });

    test('does not coerce values outside the requested selector range', () {
      expect(MedicationDosePreset.tryParse('500 mg tablet'), isNull);
    });
  });

  test('clinical clock is explicitly 24-hour', () {
    expect(ClinicalClock.time(DateTime(2026, 9, 5, 6, 37)), '06:37');
    expect(ClinicalClock.time(DateTime(2026, 9, 5, 18, 37)), '18:37');
  });
}
