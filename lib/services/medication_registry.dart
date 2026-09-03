import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'medication_identifier.dart';
import 'medication_master.dart';

enum MedicationResolutionTrust {
  jamaicaApproved,
  publicReference,
  observedPackage,
  prototype,
  unresolved,
}

class MedicationResolution {
  const MedicationResolution({
    required this.identifier,
    required this.trust,
    required this.source,
    required this.message,
    this.product,
    this.onlineLookup = false,
  });

  final MedicationIdentifier identifier;
  final MedicationProduct? product;
  final MedicationResolutionTrust trust;
  final String source;
  final String message;
  final bool onlineLookup;

  bool get found => product != null;
  bool get approvedForClinicalAutomation =>
      trust == MedicationResolutionTrust.jamaicaApproved &&
      product?.clinicallyVerified == true;

  String get trustLabel => switch (trust) {
        MedicationResolutionTrust.jamaicaApproved => 'Approved medication master',
        MedicationResolutionTrust.publicReference => 'Public reference match',
        MedicationResolutionTrust.observedPackage => 'Observed package match',
        MedicationResolutionTrust.prototype => 'Prototype fixture',
        MedicationResolutionTrust.unresolved => 'Unresolved',
      };
}

class MedicationNameMatch {
  const MedicationNameMatch({
    required this.name,
    required this.rxcui,
    required this.score,
    required this.source,
  });

  final String name;
  final String rxcui;
  final double score;
  final String source;
}

/// Multi-source medication identity resolver.
///
/// Resolution order:
/// 1. an optional Medqur/Jamaica approved registry backend, configured with
///    --dart-define=MEDQUR_MEDICATION_API_BASE=https://.../ ;
/// 2. the small local observed/prototype cache;
/// 3. openFDA NDC Directory UPC lookup for US-market packages;
/// 4. unresolved, requiring pharmacist/master-data verification.
///
/// RxNorm is also available as a name-search fallback. Public FDA/RxNorm data is
/// reference data only and is never elevated to Jamaica-approved clinical data.
class MedicationRegistryClient {
  MedicationRegistryClient({http.Client? client}) : _client = client ?? http.Client();

  static const String _configuredBase =
      String.fromEnvironment('MEDQUR_MEDICATION_API_BASE', defaultValue: '');

  final http.Client _client;
  final Map<String, MedicationResolution> _cache = {};

  void dispose() => _client.close();

  Future<MedicationResolution> resolve(
    MedicationIdentifier identifier, {
    bool allowPublicReference = true,
  }) async {
    final cacheKey = '${identifier.gtin ?? ''}|${identifier.rawValue}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    if (identifier.gtin != null && identifier.gtinCheckDigitValid == false) {
      final result = MedicationResolution(
        identifier: identifier,
        trust: MedicationResolutionTrust.unresolved,
        source: 'GS1 validation',
        message: 'The scanned GTIN has an invalid check digit. Re-scan the package before using it.',
      );
      _cache[cacheKey] = result;
      return result;
    }

    final authoritative = await _resolveApprovedRegistry(identifier);
    if (authoritative != null) {
      _cache[cacheKey] = authoritative;
      return authoritative;
    }

    final local = MedicationMasterCatalog.lookup(identifier);
    if (local != null) {
      final trust = switch (local.source) {
        MedicationProductSource.jamaicaApproved => MedicationResolutionTrust.jamaicaApproved,
        MedicationProductSource.publicReference => MedicationResolutionTrust.publicReference,
        MedicationProductSource.observedPackage => MedicationResolutionTrust.observedPackage,
        MedicationProductSource.prototype => MedicationResolutionTrust.prototype,
      };
      final result = MedicationResolution(
        identifier: identifier,
        product: local,
        trust: trust,
        source: local.sourceLabel,
        message: local.clinicallyVerified
            ? 'Product identifier matched an approved medication master record.'
            : 'The package identity is known to this prototype, but pharmacist/approved-registry verification is still required for clinical use.',
      );
      _cache[cacheKey] = result;
      return result;
    }

    if (allowPublicReference) {
      final fda = await _resolveOpenFda(identifier);
      if (fda != null) {
        _cache[cacheKey] = fda;
        return fda;
      }
    }

    final result = MedicationResolution(
      identifier: identifier,
      trust: MedicationResolutionTrust.unresolved,
      source: 'No trusted product match',
      message: identifier.gtin == null
          ? 'The code was captured but no GTIN could be extracted. Manual pharmacist verification is required.'
          : 'GTIN ${identifier.gtin} was captured, but no configured medication registry matched it.',
      onlineLookup: allowPublicReference,
    );
    _cache[cacheKey] = result;
    return result;
  }

  Future<List<MedicationNameMatch>> searchByName(String query) async {
    final value = query.trim();
    if (value.length < 2) return const [];
    try {
      final uri = Uri.https(
        'rxnav.nlm.nih.gov',
        '/REST/approximateTerm.json',
        {
          'term': value,
          'maxEntries': '8',
          'option': '1',
        },
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final group = body['approximateGroup'] as Map<String, dynamic>?;
      final candidates = (group?['candidate'] as List<dynamic>? ?? const []);
      final matches = <MedicationNameMatch>[];
      for (final raw in candidates) {
        if (raw is! Map<String, dynamic>) continue;
        final rxcui = raw['rxcui']?.toString() ?? '';
        final name = raw['name']?.toString() ?? '';
        if (rxcui.isEmpty || name.isEmpty) continue;
        matches.add(MedicationNameMatch(
          name: name,
          rxcui: rxcui,
          score: double.tryParse(raw['score']?.toString() ?? '') ?? 0,
          source: raw['source']?.toString() ?? 'RxNorm',
        ));
      }
      return matches;
    } on Object {
      return const [];
    }
  }

  Future<MedicationResolution?> _resolveApprovedRegistry(
    MedicationIdentifier identifier,
  ) async {
    if (_configuredBase.trim().isEmpty) return null;
    try {
      final base = Uri.parse(
        _configuredBase.endsWith('/') ? _configuredBase : '$_configuredBase/',
      );
      final uri = base.resolve('v1/medications/resolve').replace(
        queryParameters: {
          if (identifier.gtin != null) 'gtin': identifier.gtin!,
          'raw': identifier.rawValue,
        },
      );
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final productJson = decoded['product'] is Map<String, dynamic>
          ? decoded['product'] as Map<String, dynamic>
          : decoded;
      final verified = decoded['verified'] == true || productJson['verified'] == true;
      final product = _productFromRegistry(productJson, clinicallyVerified: verified);
      if (product == null) return null;
      return MedicationResolution(
        identifier: identifier,
        product: product,
        trust: verified
            ? MedicationResolutionTrust.jamaicaApproved
            : MedicationResolutionTrust.publicReference,
        source: decoded['source']?.toString() ?? 'Configured Medqur medication registry',
        message: verified
            ? 'Product identity verified by the configured approved medication registry.'
            : 'Registry returned a product reference, but it is not marked clinically verified.',
        onlineLookup: true,
      );
    } on Object {
      return null;
    }
  }

  Future<MedicationResolution?> _resolveOpenFda(
    MedicationIdentifier identifier,
  ) async {
    final candidates = _upcCandidates(identifier);
    for (final upc in candidates) {
      try {
        final uri = Uri.https(
          'api.fda.gov',
          '/drug/ndc.json',
          {
            'search': 'openfda.upc:"$upc"',
            'limit': '5',
          },
        );
        final response = await _client.get(uri).timeout(const Duration(seconds: 6));
        if (response.statusCode == 404) continue;
        if (response.statusCode != 200) continue;
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final results = body['results'] as List<dynamic>?;
        if (results == null || results.isEmpty) continue;
        final first = results.first;
        if (first is! Map<String, dynamic>) continue;
        final product = _productFromOpenFda(first, identifier.gtin);
        return MedicationResolution(
          identifier: identifier,
          product: product,
          trust: MedicationResolutionTrust.publicReference,
          source: 'openFDA NDC Directory',
          message: 'UPC matched the public FDA NDC Directory. This is reference data, not Jamaica formulary approval or a substitute for pharmacist verification.',
          onlineLookup: true,
        );
      } on Object {
        // Try the next candidate or fall through to unresolved.
      }
    }
    return null;
  }

  static Set<String> _upcCandidates(MedicationIdentifier identifier) {
    final values = <String>{};
    final rawDigits = identifier.rawValue.replaceAll(RegExp(r'\D'), '');
    if (rawDigits.length >= 8 && rawDigits.length <= 14) values.add(rawDigits);
    final gtin = identifier.gtin;
    if (gtin != null) {
      values.add(gtin);
      final stripped = gtin.replaceFirst(RegExp(r'^0+'), '');
      if (stripped.length >= 8) values.add(stripped);
      if (gtin.length == 14 && gtin.startsWith('00')) values.add(gtin.substring(2));
      if (gtin.length == 14 && gtin.startsWith('0')) values.add(gtin.substring(1));
    }
    return values;
  }

  static MedicationProduct? _productFromRegistry(
    Map<String, dynamic> json, {
    required bool clinicallyVerified,
  }) {
    final generic = json['genericName']?.toString() ?? json['generic_name']?.toString() ?? '';
    final brand = json['brandName']?.toString() ?? json['brand_name']?.toString() ?? '';
    if (generic.isEmpty && brand.isEmpty) return null;
    final gtins = <String>[];
    final rawGtins = json['gtins'];
    if (rawGtins is List) {
      for (final value in rawGtins) {
        final gtin = value.toString();
        if (gtin.isNotEmpty) gtins.add(gtin);
      }
    }
    final single = json['gtin']?.toString();
    if (single != null && single.isNotEmpty && !gtins.contains(single)) gtins.add(single);
    return MedicationProduct(
      id: json['id']?.toString() ?? 'REGISTRY-${gtins.isEmpty ? brand : gtins.first}',
      genericName: generic,
      brandName: brand,
      strength: json['strength']?.toString() ?? '',
      dosageForm: json['dosageForm']?.toString() ?? json['dosage_form']?.toString() ?? '',
      manufacturer: json['manufacturer']?.toString() ?? '',
      source: clinicallyVerified
          ? MedicationProductSource.jamaicaApproved
          : MedicationProductSource.publicReference,
      packageDescription: json['packageDescription']?.toString(),
      gtins: gtins,
      rxcui: json['rxcui']?.toString(),
      ndc: json['ndc']?.toString(),
      clinicallyVerified: clinicallyVerified,
      jamaicaReference: json['jamaicaReference']?.toString(),
    );
  }

  static MedicationProduct _productFromOpenFda(
    Map<String, dynamic> json,
    String? scannedGtin,
  ) {
    final active = json['active_ingredients'] as List<dynamic>? ?? const [];
    final ingredientNames = <String>[];
    final strengths = <String>[];
    for (final item in active) {
      if (item is! Map<String, dynamic>) continue;
      final name = item['name']?.toString();
      final strength = item['strength']?.toString();
      if (name != null && name.isNotEmpty) ingredientNames.add(name);
      if (strength != null && strength.isNotEmpty) strengths.add(strength);
    }
    final generic = json['generic_name']?.toString();
    final brand = json['brand_name']?.toString() ?? json['brand_name_base']?.toString() ?? '';
    final packageNdc = json['package_ndc']?.toString();
    return MedicationProduct(
      id: 'OPENFDA-${packageNdc ?? scannedGtin ?? brand}',
      genericName: generic?.isNotEmpty == true
          ? generic!
          : ingredientNames.isNotEmpty
              ? ingredientNames.join(' / ')
              : brand,
      brandName: brand,
      strength: strengths.join(' / '),
      dosageForm: json['dosage_form']?.toString() ?? '',
      manufacturer: json['labeler_name']?.toString() ?? '',
      source: MedicationProductSource.publicReference,
      packageDescription: packageNdc == null ? null : 'NDC package $packageNdc',
      gtins: scannedGtin == null ? const [] : [scannedGtin],
      ndc: json['product_ndc']?.toString() ?? packageNdc,
      clinicallyVerified: false,
    );
  }
}
