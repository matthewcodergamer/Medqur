import 'medication_identifier.dart';

class MedicationProduct {
  const MedicationProduct({
    required this.id,
    required this.genericName,
    required this.brandName,
    required this.strength,
    required this.dosageForm,
    required this.manufacturer,
    this.packageDescription,
    this.gtin,
    this.prototypeAliases = const [],
    this.active = true,
  });

  final String id;
  final String genericName;
  final String brandName;
  final String strength;
  final String dosageForm;
  final String manufacturer;
  final String? packageDescription;
  final String? gtin;
  final List<String> prototypeAliases;
  final bool active;

  String get displayName {
    final brand = brandName.trim().isEmpty ? '' : ' ($brandName)';
    return '$genericName $strength$brand';
  }
}

/// Prototype lookup boundary for a future Jamaica medication master.
///
/// Production data should come from an approved Ministry/pharmacy/procurement
/// source. We intentionally do not ship invented real-world GTIN mappings.
class MedicationMasterCatalog {
  const MedicationMasterCatalog._();

  static const products = <MedicationProduct>[
    MedicationProduct(
      id: 'DEMO-PARA-500-TAB',
      genericName: 'Paracetamol',
      brandName: 'Demo product',
      strength: '500 mg',
      dosageForm: 'Tablet',
      manufacturer: 'Prototype only',
      packageDescription: 'Prototype unit-dose medication',
      prototypeAliases: ['MEDQUR-DEMO-PARA-500'],
    ),
    MedicationProduct(
      id: 'DEMO-AMOX-500-CAP',
      genericName: 'Amoxicillin',
      brandName: 'Demo product',
      strength: '500 mg',
      dosageForm: 'Capsule',
      manufacturer: 'Prototype only',
      packageDescription: 'Prototype unit-dose medication',
      prototypeAliases: ['MEDQUR-DEMO-AMOX-500'],
    ),
  ];

  static MedicationProduct? lookup(MedicationIdentifier identifier) {
    final gtin = identifier.gtin;
    for (final product in products) {
      if (gtin != null && product.gtin == gtin) return product;
      if (product.prototypeAliases.contains(identifier.rawValue)) return product;
    }
    return null;
  }

  static MedicationProduct? byId(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }
}
