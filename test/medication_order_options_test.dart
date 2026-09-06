import 'package:flutter_test/flutter_test.dart';
import 'package:medqur/clinical_clock.dart';
import 'package:medqur/medication_order_options.dart';
import 'package:medqur/medication_prescribing_options.dart';

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

    test('frequency selector is 1x through 20x per period', () {
      expect(
        StructuredMedicationDirections.frequencyCounts,
        orderedEquals(List<int>.generate(20, (index) => index + 1)),
      );
      const directions = StructuredMedicationDirections(
        doseValue: 5,
        doseUnit: MedicationDoseUnit.milligram,
        frequencyCount: 20,
        frequencyPeriod: MedicationFrequencyPeriod.day,
        dueMode: MedicationDueMode.immediate,
      );
      expect(directions.doseText, '5 mg');
      expect(directions.frequencyText, '20x per day');
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

  group('prescribing option libraries', () {
    test('route list is alphabetized and substantially expanded', () {
      final sorted = [...MedicationPrescribingOptions.routes]..sort();
      expect(MedicationPrescribingOptions.routes, orderedEquals(sorted));
      expect(MedicationPrescribingOptions.routes.length, greaterThanOrEqualTo(18));
      expect(
        MedicationPrescribingOptions.routes,
        containsAll(<String>[
          'Intramuscular (IM)',
          'Intravenous (IV)',
          'Oral',
          'Subcutaneous',
          'Sublingual',
          'Topical',
        ]),
      );
    });

    test('duration dropdown includes short, course and long-term choices', () {
      expect(MedicationPrescribingOptions.durations.first, 'Not specified');
      expect(
        MedicationPrescribingOptions.durations,
        containsAll(<String>[
          'Single dose',
          '1 day',
          '7 days',
          '14 days',
          '30 days',
          '6 weeks',
          '3 months',
          'Until course completed',
          'Until reviewed',
          'Ongoing',
        ]),
      );
    });

    test('instruction library is broad and covers common food/drink warnings', () {
      expect(
        MedicationPrescribingOptions.commonInstructions.length,
        greaterThanOrEqualTo(70),
      );
      expect(
        MedicationPrescribingOptions.commonInstructions,
        containsAll(<String>[
          'Avoid alcohol',
          'Avoid grapefruit and grapefruit juice',
          'Avoid tea and coffee within 2 hours of this dose',
          'Avoid milk and dairy products around the time of this dose',
          'Do not take with milk',
          'Take with milk',
          'Take with food',
          'Take before food',
          'Take on an empty stomach',
          'Take with water',
          'May cause drowsiness',
          'Do not drive or operate machinery if drowsy, dizzy or vision is affected',
          'Avoid using antacids within 2 hours of this dose',
          'Rinse mouth after each inhaled dose',
        ]),
      );
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
