/// Controlled prescribing choices used by the doctor prescription workflow.
///
/// Long lists are kept out of the primary screen and opened only when needed.
/// Routes are alphabetical so clinicians can scan the list quickly.
abstract final class MedicationPrescribingOptions {
  static const routes = <String>[
    'Buccal',
    'Enteral / feeding tube',
    'Epidural',
    'Inhaled',
    'Intradermal',
    'Intramuscular (IM)',
    'Intranasal',
    'Intraosseous (IO)',
    'Intrathecal',
    'Intravenous (IV)',
    'Nebulized',
    'Ophthalmic',
    'Oral',
    'Otic',
    'Rectal',
    'Subcutaneous',
    'Sublingual',
    'Topical',
    'Transdermal',
    'Vaginal',
  ];

  /// Common directions/warnings are optional templates only. Selecting one
  /// appends it to the prescription instructions; it does not infer that the
  /// instruction is clinically appropriate for a medicine.
  static const commonInstructions = <String>[
    'Allow to dissolve under the tongue',
    'Apply to the affected area',
    'Avoid alcohol',
    'Avoid grapefruit or grapefruit juice',
    'Complete the full course',
    'Do not crush or chew',
    'Do not drive or operate machinery if drowsy',
    'Do not take with milk',
    'Do not stop suddenly unless instructed',
    'For external use only',
    'May cause drowsiness',
    'Rinse mouth after use',
    'Shake well before use',
    'Swallow whole',
    'Take after food',
    'Take at bedtime',
    'Take before food',
    'Take in the morning',
    'Take on an empty stomach',
    'Take with food',
    'Take with a full glass of water',
    'Take with milk',
    'Take with water',
    'Use as directed',
  ];
}
