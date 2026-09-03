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
        MedicationProductSource.jamaicaApproved => 'Jamaica approved medication master',
        MedicationProductSource.publicReference => 'Public medication reference',
        MedicationProductSource.observedPackage => 'Observed package fixture',
        MedicationProductSource.prototype => 'Medqur prototype fixture',
      };
}

/// Small local cache/fixture catalogue.
///
/// This is NOT the national medication database. Production resolution is
/// performed by MedicationRegistryClient, which can query an approved Medqur
/// medication-registry backend and public reference services. The observed
/// package entries below are grounded in packages supplied during prototype
/// testing and are deliberately marked as not clinically verified.
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
      packageDescription: 'Prescription package observed in Medqur prototype testing',
      gtins: ['18904215101509'],
      therapeuticCategory: 'Gabapentinoid',
      prescriptionStatus: 'Prescription only',
      ingredients: ['Pregabalin'],
      jamaicaReference: 'National Health Fund benefits listing includes NEUROBALIN-75 CAP 75mg',
    ),
    MedicationProduct(
      id: 'OBS-CEFUR-500',
      genericName: 'Cefuroxime axetil',
      brandName: 'CEFUR',
      strength: '500 mg',
      dosageForm: 'Tablet',
      manufacturer: 'Ryvis Pharma',
      source: MedicationProductSource.observedPackage,
      packageDescription: '10-tablet prescription package observed in Medqur prototype testing',
      therapeuticCategory: 'Cephalosporin antibiotic',
      prescriptionStatus: 'Prescription only',
      ingredients: ['Cefuroxime axetil'],
      // The package carries a GS1 DataMatrix GTIN and a separate EAN-13.
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
      packageDescription: 'Maximum-strength 12-hour expectorant / cough suppressant package',
      therapeuticCategory: 'Expectorant / cough suppressant',
      ingredients: ['Guaifenesin', 'Dextromethorphan HBr'],
      gtins: ['00363824050287'],
      rawAliases: ['363824050287'],
    ),
    MedicationProduct(
      id: 'DEMO-PARA-500-TAB',
      genericName: 'Paracetamol',
      brandName: 'Demo product',
      strength: '500 mg',
      dosageForm: 'Tablet',
      manufacturer: 'Prototype only',
      source: MedicationProductSource.prototype,
      packageDescription: 'Prototype unit-dose medication',
      therapeuticCategory: 'Analgesic / antipyretic',
      ingredients: ['Paracetamol'],
      rawAliases: ['MEDQUR-DEMO-PARA-500'],
    ),
    MedicationProduct(
      id: 'DEMO-AMOX-500-CAP',
      genericName: 'Amoxicillin',
      brandName: 'Demo product',
      strength: '500 mg',
      dosageForm: 'Capsule',
      manufacturer: 'Prototype only',
      source: MedicationProductSource.prototype,
      packageDescription: 'Prototype unit-dose medication',
      therapeuticCategory: 'Penicillin antibiotic',
      ingredients: ['Amoxicillin'],
      rawAliases: ['MEDQUR-DEMO-AMOX-500'],
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

  static List<MedicationProduct> search(String query, {int limit = 12}) {
    final words = _normalize(query).split(' ').where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return const [];

    final matches = <({MedicationProduct product, int score})>[];
    for (final product in products) {
      if (!product.active) continue;
      final generic = _normalize(product.genericName);
      final brand = _normalize(product.brandName);
      final strength = _normalize(product.strength);
      final manufacturer = _normalize(product.manufacturer);
      final category = _normalize(product.therapeuticCategory ?? '');
      final ingredients = _normalize(product.ingredients.join(' '));
      final haystack = '$generic $brand $strength $manufacturer $category $ingredients';
      if (!words.every(haystack.contains)) continue;

      var score = 10;
      final normalizedQuery = _normalize(query);
      if (generic == normalizedQuery || brand == normalizedQuery) score += 100;
      if (generic.startsWith(normalizedQuery) || brand.startsWith(normalizedQuery)) score += 40;
      if (generic.contains(normalizedQuery) || brand.contains(normalizedQuery)) score += 25;
      if (strength.contains(normalizedQuery)) score += 5;
      matches.add((product: product, score: score));
    }

    matches.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return a.product.displayName.compareTo(b.product.displayName);
    });
    return matches.take(limit).map((entry) => entry.product).toList(growable: false);
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
