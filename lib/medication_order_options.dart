enum MedicationDoseUnit {
  gram,
  milligram,
  microgram,
  millilitre,
  microlitre,
  litre,
}

extension MedicationDoseUnitInfo on MedicationDoseUnit {
  String get label => switch (this) {
        MedicationDoseUnit.gram => 'grams',
        MedicationDoseUnit.milligram => 'milligrams',
        MedicationDoseUnit.microgram => 'micrograms',
        MedicationDoseUnit.millilitre => 'millilitres',
        MedicationDoseUnit.microlitre => 'microlitres',
        MedicationDoseUnit.litre => 'litres',
      };

  String get symbol => switch (this) {
        MedicationDoseUnit.gram => 'g',
        MedicationDoseUnit.milligram => 'mg',
        MedicationDoseUnit.microgram => 'mcg',
        MedicationDoseUnit.millilitre => 'mL',
        MedicationDoseUnit.microlitre => 'µL',
        MedicationDoseUnit.litre => 'L',
      };
}

enum MedicationFrequencyPeriod {
  hour,
  day,
  week,
}

extension MedicationFrequencyPeriodInfo on MedicationFrequencyPeriod {
  String get label => switch (this) {
        MedicationFrequencyPeriod.hour => 'hour',
        MedicationFrequencyPeriod.day => 'day',
        MedicationFrequencyPeriod.week => 'week',
      };
}

enum MedicationDueMode {
  immediate,
  scheduled,
}

extension MedicationDueModeInfo on MedicationDueMode {
  String get label => switch (this) {
        MedicationDueMode.immediate => 'Immediately',
        MedicationDueMode.scheduled => 'On date / time',
      };
}

/// Controlled medication-order values requested for the Medqur prescribing UI.
///
/// The UI deliberately avoids free-text dose/frequency entry for these fields:
/// dose amount is selected from 1–100, dose unit from a controlled unit list,
/// and frequency from 1x–10x per hour/day/week.
class StructuredMedicationDirections {
  const StructuredMedicationDirections({
    required this.doseValue,
    required this.doseUnit,
    required this.frequencyCount,
    required this.frequencyPeriod,
    required this.dueMode,
    this.scheduledAt,
  });

  final int doseValue;
  final MedicationDoseUnit doseUnit;
  final int frequencyCount;
  final MedicationFrequencyPeriod frequencyPeriod;
  final MedicationDueMode dueMode;
  final DateTime? scheduledAt;

  static const List<int> doseValues = <int>[
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
    31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50,
    51, 52, 53, 54, 55, 56, 57, 58, 59, 60,
    61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
    71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
    81, 82, 83, 84, 85, 86, 87, 88, 89, 90,
    91, 92, 93, 94, 95, 96, 97, 98, 99, 100,
  ];

  static const List<int> frequencyCounts = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  String get doseText => '$doseValue ${doseUnit.symbol}';

  String get frequencyText => '$frequencyCount× per ${frequencyPeriod.label}';

  DateTime effectiveDueAt({DateTime? now}) {
    if (dueMode == MedicationDueMode.immediate) {
      return now ?? DateTime.now();
    }
    final value = scheduledAt;
    if (value == null) {
      throw StateError('A scheduled medication order requires a due date and time.');
    }
    return value;
  }
}

class MedicationDosePreset {
  const MedicationDosePreset(this.value, this.unit);

  final int value;
  final MedicationDoseUnit unit;

  /// Uses a product strength only when it maps exactly into the controlled
  /// 1–100 selector. Values outside that range are intentionally not coerced.
  static MedicationDosePreset? tryParse(String raw) {
    final text = raw.trim();
    final match = RegExp(
      r'(^|\s)(\d{1,3})\s*(mg|mcg|ug|µg|g|ml|mL|ul|µl|µL|l|L)(\b|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final value = int.tryParse(match.group(2) ?? '');
    if (value == null || value < 1 || value > 100) return null;
    final token = (match.group(3) ?? '').toLowerCase();
    final unit = switch (token) {
      'g' => MedicationDoseUnit.gram,
      'mg' => MedicationDoseUnit.milligram,
      'mcg' || 'ug' || 'µg' => MedicationDoseUnit.microgram,
      'ml' => MedicationDoseUnit.millilitre,
      'ul' || 'µl' => MedicationDoseUnit.microlitre,
      'l' => MedicationDoseUnit.litre,
      _ => null,
    };
    return unit == null ? null : MedicationDosePreset(value, unit);
  }
}
