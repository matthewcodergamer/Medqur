import 'medication_identifier.dart';

enum MedicationProductSource {
  jamaicaApproved,
  publicReference,
  observedPackage,
  prototype,
}

class MedicationProduct {
  const MedicationProduct({
    required this.id,
    required this.genericName,
    required this.brandName,
    required this.strength,
    required this.dosageForm,
    required this.manufacturer,
    required this.source,
    this.packageDescription,
    this.gtins = const [],
    this.rawAliases = const [],
    this.rxcui,
    this.ndc,
    this.jamaicaReference,
    this.importer,
    this.therapeuticCategory,
    this.prescriptionStatus,
    this.ingredients = const [],
    this.formularyStatus,
    this.approvalStatus,
    this.active = true,
    this.clinicallyVerified = false,
  });

  final String id;
  final String genericName;
  final String brandName;
  final String strength;
  final String dosageForm;
  final String manufacturer;
  final MedicationProductSource source;
  final String? packageDescription;
  final List<String> gtins;
  final List<String> rawAliases;
  final String? rxcui;
  final String? ndc;
  final String? jamaicaReference;
  final String? importer;
  final String? therapeuticCategory;
  final String? prescriptionStatus;
  final List<String> ingredients;
  final String? formularyStatus;
  final String? approvalStatus;
  final bool active;
  final bool clinicallyVerified;

  String? get gtin => gtins.isEmpty ? null : gtins.first;

  String get displayName {
    final brand = brandName.trim().isEmpty ? '' : ' ($brandName)';
    final dose = strength.trim().isEmpty ? '' : ' $strength';
    return '$genericName$dose$brand';
  }

  String get sourceLabel => switch (source) {
        MedicationProductSource.jamaicaApproved =>
          'Jamaica approved medication master',
        MedicationProductSource.publicReference => 'Public medication reference',
        MedicationProductSource.observedPackage => 'Observed package fixture',
        MedicationProductSource.prototype => 'Medqur prototype fixture',
      };
}

/// Searchable offline fixture/cache used when the live medication master is not
/// available.
///
/// Nothing in this list is automatically Jamaica-approved. `prototype` entries
/// deliberately provide common medicine names/forms for UI and workflow testing
/// only. Observed-package entries are grounded in packages supplied during
/// prototype testing, but they also remain unverified until an authorized
/// pharmacist/medication-master process promotes them.
class MedicationMasterCatalog {
  const MedicationMasterCatalog._();

  static const products = <MedicationProduct>[
    MedicationProduct(
      id: 'OBS-NEUROBALIN-75',
      genericName: 'Pregabalin',
      brandName: 'Neurobalin-75',
      strength: '75 mg',
      dosageForm: 'Capsule',
      manufacturer: 'Indus Life Sciences Pvt. Ltd.',
      source: MedicationProductSource.observedPackage,
      packageDescription:
          'Prescription package observed in Medqur prototype testing',
      gtins: ['18904215101509'],
      therapeuticCategory: 'Gabapentinoid',
      prescriptionStatus: 'Prescription only',
      ingredients: ['Pregabalin'],
      jamaicaReference:
          'National Health Fund benefits listing includes NEUROBALIN-75 CAP 75mg',
    ),
    MedicationProduct(
      id: 'OBS-CEFUR-500',
      genericName: 'Cefuroxime axetil',
      brandName: 'CEFUR',
      strength: '500 mg',
      dosageForm: 'Tablet',
      manufacturer: 'Ryvis Pharma',
      source: MedicationProductSource.observedPackage,
      packageDescription:
          '10-tablet prescription package observed in Medqur prototype testing',
      therapeuticCategory: 'Cephalosporin antibiotic',
      prescriptionStatus: 'Prescription only',
      ingredients: ['Cefuroxime axetil'],
      gtins: ['18906102700512', '08906102700515'],
      rawAliases: ['8906102700515'],
    ),
    MedicationProduct(
      id: 'OBS-MUCINEX-DM-MAX',
      genericName: 'Guaifenesin / Dextromethorphan HBr',
      brandName: 'Mucinex DM Maximum Strength',
      strength: '1200 mg / 60 mg',
      dosageForm: 'Extended-release tablet',
      manufacturer: 'Package manufacturer to be verified by external registry',
      source: MedicationProductSource.observedPackage,
      packageDescription:
          'Maximum-strength 12-hour expectorant / cough suppressant package',
      therapeuticCategory: 'Expectorant / cough suppressant',
      ingredients: ['Guaifenesin', 'Dextromethorphan HBr'],
      gtins: ['00363824050287'],
      rawAliases: ['363824050287'],
    ),
    MedicationProduct(
      id: 'DEMO-PARA-500-TAB',
      genericName: 'Paracetamol',
      brandName: '',
      strength: '500 mg',
      dosageForm: 'Tablet',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Analgesic / antipyretic',
      ingredients: ['Paracetamol'],
      rawAliases: ['MEDQUR-DEMO-PARA-500'],
    ),
    MedicationProduct(
      id: 'DEMO-AMOX-500-CAP',
      genericName: 'Amoxicillin',
      brandName: '',
      strength: '500 mg',
      dosageForm: 'Capsule',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Penicillin antibiotic',
      ingredients: ['Amoxicillin'],
      rawAliases: ['MEDQUR-DEMO-AMOX-500'],
    ),
    MedicationProduct(
      id: 'DEMO-AMOXCLAV-875-125-TAB',
      genericName: 'Amoxicillin / Clavulanic acid',
      brandName: '',
      strength: '875 mg / 125 mg',
      dosageForm: 'Tablet',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Penicillin antibiotic / beta-lactamase inhibitor',
      ingredients: ['Amoxicillin', 'Clavulanic acid'],
      rawAliases: ['MEDQUR-DEMO-AMOXCLAV-875-125'],
    ),
    MedicationProduct(
      id: 'DEMO-IBUPROFEN-400-TAB',
      genericName: 'Ibuprofen',
      brandName: '',
      strength: '400 mg',
      dosageForm: 'Tablet',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'NSAID analgesic',
      ingredients: ['Ibuprofen'],
      rawAliases: ['MEDQUR-DEMO-IBUPROFEN-400'],
    ),
    MedicationProduct(
      id: 'DEMO-AZITHRO-500-TAB',
      genericName: 'Azithromycin',
      brandName: '',
      strength: '500 mg',
      dosageForm: 'Tablet',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Macrolide antibiotic',
      ingredients: ['Azithromycin'],
      rawAliases: ['MEDQUR-DEMO-AZITHRO-500'],
    ),
    MedicationProduct(
      id: 'DEMO-DOXY-100-CAP',
      genericName: 'Doxycycline',
      brandName: '',
      strength: '100 mg',
      dosageForm: 'Capsule',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Tetracycline antibiotic',
      ingredients: ['Doxycycline'],
      rawAliases: ['MEDQUR-DEMO-DOXY-100'],
    ),
    MedicationProduct(
      id: 'DEMO-CEFTRIAXONE-1G-VIAL',
      genericName: 'Ceftriaxone',
      brandName: '',
      strength: '1 g',
      dosageForm: 'Powder for injection vial',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Cephalosporin antibiotic',
      ingredients: ['Ceftriaxone'],
      rawAliases: ['MEDQUR-DEMO-CEFTRIAXONE-1G'],
    ),
    MedicationProduct(
      id: 'DEMO-METFORMIN-500-TAB',
      genericName: 'Metformin',
      brandName: '',
      strength: '500 mg',
      dosageForm: 'Tablet',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Biguanide antidiabetic',
      ingredients: ['Metformin'],
      rawAliases: ['MEDQUR-DEMO-METFORMIN-500'],
    ),
    MedicationProduct(
      id: 'DEMO-AMLODIPINE-5-TAB',
      genericName: 'Amlodipine',
      brandName: '',
      strength: '5 mg',
      dosageForm: 'Tablet',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Calcium-channel blocker',
      ingredients: ['Amlodipine'],
      rawAliases: ['MEDQUR-DEMO-AMLODIPINE-5'],
    ),
    MedicationProduct(
      id: 'DEMO-LISINOPRIL-10-TAB',
      genericName: 'Lisinopril',
      brandName: '',
      strength: '10 mg',
      dosageForm: 'Tablet',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'ACE inhibitor',
      ingredients: ['Lisinopril'],
      rawAliases: ['MEDQUR-DEMO-LISINOPRIL-10'],
    ),
    MedicationProduct(
      id: 'DEMO-OMEPRAZOLE-20-CAP',
      genericName: 'Omeprazole',
      brandName: '',
      strength: '20 mg',
      dosageForm: 'Delayed-release capsule',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Proton-pump inhibitor',
      ingredients: ['Omeprazole'],
      rawAliases: ['MEDQUR-DEMO-OMEPRAZOLE-20'],
    ),
    MedicationProduct(
      id: 'DEMO-CETIRIZINE-10-TAB',
      genericName: 'Cetirizine',
      brandName: '',
      strength: '10 mg',
      dosageForm: 'Tablet',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Antihistamine',
      ingredients: ['Cetirizine'],
      rawAliases: ['MEDQUR-DEMO-CETIRIZINE-10'],
    ),
    MedicationProduct(
      id: 'DEMO-SALBUTAMOL-100-INH',
      genericName: 'Salbutamol',
      brandName: '',
      strength: '100 micrograms/actuation',
      dosageForm: 'Metered-dose inhaler',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Short-acting beta2 agonist',
      ingredients: ['Salbutamol'],
      rawAliases: ['MEDQUR-DEMO-SALBUTAMOL-100'],
    ),
    MedicationProduct(
      id: 'DEMO-FLUCONAZOLE-150-CAP',
      genericName: 'Fluconazole',
      brandName: '',
      strength: '150 mg',
      dosageForm: 'Capsule',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Azole antifungal',
      ingredients: ['Fluconazole'],
      rawAliases: ['MEDQUR-DEMO-FLUCONAZOLE-150'],
    ),
    MedicationProduct(
      id: 'DEMO-ORS-SACHET',
      genericName: 'Oral rehydration salts',
      brandName: '',
      strength: 'WHO-type sachet',
      dosageForm: 'Powder for oral solution',
      manufacturer: 'Prototype catalogue',
      source: MedicationProductSource.prototype,
      therapeuticCategory: 'Oral electrolyte replacement',
      ingredients: ['Glucose', 'Sodium chloride', 'Potassium chloride', 'Citrate'],
      rawAliases: ['MEDQUR-DEMO-ORS'],
    ),
  ];

  static MedicationProduct? lookup(MedicationIdentifier identifier) {
    final gtin = identifier.gtin;
    final normalizedRaw = identifier.rawValue.trim();
    for (final product in products) {
      if (gtin != null && product.gtins.contains(gtin)) return product;
      if (product.rawAliases.contains(normalizedRaw)) return product;
      if (RegExp(r'^\d+$').hasMatch(normalizedRaw)) {
        final padded = normalizedRaw.padLeft(14, '0');
        if (product.gtins.contains(padded)) return product;
      }
    }
    return null;
  }

  static List<MedicationProduct> search(String query, {int limit = 16}) {
    final words = _normalize(query)
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];

    final matches = <({MedicationProduct product, int score})>[];
    for (final product in products) {
      if (!product.active) continue;
      final generic = _normalize(product.genericName);
      final brand = _normalize(product.brandName);
      final strength = _normalize(product.strength);
      final form = _normalize(product.dosageForm);
      final manufacturer = _normalize(product.manufacturer);
      final category = _normalize(product.therapeuticCategory ?? '');
      final package = _normalize(product.packageDescription ?? '');
      final ingredients = _normalize(product.ingredients.join(' '));
      final aliases = _normalize(product.rawAliases.join(' '));
      final haystack =
          '$generic $brand $strength $form $manufacturer $category $package $ingredients $aliases';
      if (!words.every(haystack.contains)) continue;

      var score = 10;
      final normalizedQuery = _normalize(query);
      if (generic == normalizedQuery || brand == normalizedQuery) score += 100;
      if (generic.startsWith(normalizedQuery) ||
          brand.startsWith(normalizedQuery)) {
        score += 40;
      }
      if (generic.contains(normalizedQuery) ||
          brand.contains(normalizedQuery)) {
        score += 25;
      }
      if (ingredients.contains(normalizedQuery)) score += 18;
      if (form.contains(normalizedQuery)) score += 8;
      if (strength.contains(normalizedQuery)) score += 5;
      matches.add((product: product, score: score));
    }

    matches.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return a.product.displayName.compareTo(b.product.displayName);
    });
    return matches
        .take(limit)
        .map((entry) => entry.product)
        .toList(growable: false);
  }

  static MedicationProduct? byId(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
