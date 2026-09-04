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
    this.product,
    this.trust = MedicationResolutionTrust.publicReference,
  });

  final String name;
  final String rxcui;
  final double score;
  final String source;
  final MedicationProduct? product;
  final MedicationResolutionTrust trust;

  bool get isProductRecord => product != null;
}

/// Multi-source medication identity resolver.
///
/// Resolution order:
/// 1. Medqur/Jamaica approved registry backend when configured;
/// 2. local observed/prototype cache (including exact raw package aliases);
/// 3. strict GS1 check-digit validation before external GTIN lookups;
/// 4. openFDA NDC Directory UPC lookup for compatible US-market packages;
/// 5. unresolved, requiring pharmacist/master-data verification.
///
/// The exact raw identifier is checked before rejecting a malformed candidate
/// GTIN because some pharmaceutical DataMatrix encoders/scanners expose a
/// proprietary HRI string that our parser may tentatively interpret as GTIN.
/// We still never send an invalid GTIN to an external/clinical lookup.
class MedicationRegistryClient {
  MedicationRegistryClient({
    http.Client? client,
    Future<String?> Function()? accessTokenProvider,
  })  : _client = client ?? http.Client(),
        _accessTokenProvider = accessTokenProvider;

  static const String _medicationBase =
      String.fromEnvironment('MEDQUR_MEDICATION_API_BASE', defaultValue: '');
  static const String _apiBase =
      String.fromEnvironment('MEDQUR_API_BASE', defaultValue: '');
  static const bool _devBackendAuth =
      bool.fromEnvironment('MEDQUR_DEV_BACKEND_AUTH', defaultValue: false);

  static String get configuredBase =>
      _medicationBase.trim().isNotEmpty ? _medicationBase : _apiBase;

  final http.Client _client;
  final Future<String?> Function()? _accessTokenProvider;
  final Map<String, MedicationResolution> _cache = {};

  void dispose() => _client.close();

  Future<Map<String, String>> _backendHeaders() async {
    final headers = <String, String>{'Accept': 'application/json'};
    final token = await _accessTokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else if (_devBackendAuth) {
      headers['x-medqur-staff-id'] = 'DEV-PHARMACIST';
      headers['x-medqur-role'] = 'pharmacist';
      headers['x-medqur-facility'] = 'MRH';
    }
    return headers;
  }

  Future<MedicationResolution> resolve(
    MedicationIdentifier identifier, {
    bool allowPublicReference = true,
  }) async {
    final cacheKey = '${identifier.gtin ?? ''}|${identifier.rawValue}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    // Give the configured medication master a chance to recognize the exact
    // raw package identifier even when a scanner produced an invalid candidate
    // GTIN. The backend remains responsible for provenance/verification.
    final authoritative = await _resolveApprovedRegistry(
      identifier,
      includeGtin: identifier.gtinCheckDigitValid != false,
    );
    if (authoritative != null) {
      _cache[cacheKey] = authoritative;
      return authoritative;
    }

    final local = MedicationMasterCatalog.lookup(identifier);
    if (local != null) {
      final trust = switch (local.source) {
        MedicationProductSource.jamaicaApproved =>
          MedicationResolutionTrust.jamaicaApproved,
        MedicationProductSource.publicReference =>
          MedicationResolutionTrust.publicReference,
        MedicationProductSource.observedPackage =>
          MedicationResolutionTrust.observedPackage,
        MedicationProductSource.prototype => MedicationResolutionTrust.prototype,
      };
      final result = MedicationResolution(
        identifier: identifier,
        product: local,
        trust: trust,
        source: local.sourceLabel,
        message: local.clinicallyVerified
            ? 'Product identifier matched an approved medication master record.'
            : 'Medication identified from the package catalogue. Pharmacist/approved-registry verification is still required for clinical use.',
      );
      _cache[cacheKey] = result;
      return result;
    }

    if (identifier.gtin != null && identifier.gtinCheckDigitValid == false) {
      final result = MedicationResolution(
        identifier: identifier,
        trust: MedicationResolutionTrust.unresolved,
        source: 'GS1 validation',
        message:
            'A candidate GTIN was detected but its check digit is invalid. Re-scan the clearest manufacturer barcode or search the medication name.',
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

    final rawLower = identifier.rawValue.trim().toLowerCase();
    final webQr = rawLower.startsWith('https://') || rawLower.startsWith('http://');
    final result = MedicationResolution(
      identifier: identifier,
      trust: MedicationResolutionTrust.unresolved,
      source: 'No trusted product match',
      message: webQr
          ? 'This QR contains a web/retail link rather than a medicine product identifier. Scan the package UPC/EAN/GS1 DataMatrix instead.'
          : identifier.gtin == null
              ? 'The code was captured but no GTIN could be extracted. Try another package barcode or search by medicine name.'
              : 'GTIN ${identifier.gtin} was captured, but no configured medication registry matched it. Search by name or send it for pharmacist verification.',
      onlineLookup: allowPublicReference,
    );
    _cache[cacheKey] = result;
    return result;
  }

  Future<List<MedicationNameMatch>> searchByName(String query) async {
    final value = query.trim();
    if (value.length < 2) return const [];

    final matches = <MedicationNameMatch>[];
    final registryMatches = await _searchConfiguredRegistry(value);
    matches.addAll(registryMatches);

    final rxNormMatches = await _searchRxNorm(value);
    final seenNames = registryMatches.map((item) => item.name.toLowerCase()).toSet();
    for (final item in rxNormMatches) {
      if (seenNames.add(item.name.toLowerCase())) matches.add(item);
    }
    return matches;
  }

  Future<List<MedicationNameMatch>> _searchConfiguredRegistry(String query) async {
    final configured = configuredBase.trim();
    if (configured.isEmpty) return const [];
    try {
      final base = Uri.parse(configured.endsWith('/') ? configured : '$configured/');
      final uri = base.resolve('v1/medications/search').replace(
        queryParameters: {'q': query},
      );
      final response = await _client
          .get(uri, headers: await _backendHeaders())
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final results = decoded['results'] as List<dynamic>? ?? const [];
      final matches = <MedicationNameMatch>[];
      for (final raw in results) {
        if (raw is! Map<String, dynamic>) continue;
        final verified = raw['approval_status']?.toString() == 'verified' ||
            raw['approvalStatus']?.toString() == 'verified' ||
            raw['verified'] == true;
        final product = _productFromRegistry(raw, clinicallyVerified: verified);
        if (product == null) continue;
        matches.add(MedicationNameMatch(
          name: product.displayName,
          rxcui: product.rxcui ?? '',
          score: verified ? 1000 : 800,
          source: raw['provenance_source']?.toString() ??
              raw['source']?.toString() ??
              'Medqur medication registry',
          product: product,
          trust: verified
              ? MedicationResolutionTrust.jamaicaApproved
              : MedicationResolutionTrust.publicReference,
        ));
      }
      return matches;
    } on Object {
      return const [];
    }
  }

  Future<List<MedicationNameMatch>> _searchRxNorm(String query) async {
    try {
      final uri = Uri.https(
        'rxnav.nlm.nih.gov',
        '/REST/approximateTerm.json',
        {'term': query, 'maxEntries': '8', 'option': '1'},
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final group = body['approximateGroup'] as Map<String, dynamic>?;
      final candidates = group?['candidate'] as List<dynamic>? ?? const [];
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
    MedicationIdentifier identifier, {
    bool includeGtin = true,
  }) async {
    final configured = configuredBase.trim();
    if (configured.isEmpty) return null;
    try {
      final base = Uri.parse(configured.endsWith('/') ? configured : '$configured/');
      final uri = base.resolve('v1/medications/resolve').replace(
        queryParameters: {
          if (includeGtin && identifier.gtin != null) 'gtin': identifier.gtin!,
          'raw': identifier.rawValue,
        },
      );
      final response = await _client
          .get(uri, headers: await _backendHeaders())
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final productJson = decoded['product'] is Map<String, dynamic>
          ? decoded['product'] as Map<String, dynamic>
          : decoded;
      final verified = decoded['verified'] == true ||
          productJson['verified'] == true ||
          productJson['approval_status']?.toString() == 'verified' ||
          productJson['approvalStatus']?.toString() == 'verified';
      final product = _productFromRegistry(
        productJson,
        clinicallyVerified: verified,
      );
      if (product == null) return null;
      return MedicationResolution(
        identifier: identifier,
        product: product,
        trust: verified
            ? MedicationResolutionTrust.jamaicaApproved
            : MedicationResolutionTrust.publicReference,
        source: decoded['source']?.toString() ??
            'Configured Medqur medication registry',
        message: decoded['message']?.toString() ??
            (verified
                ? 'Medication identified and verified by the configured approved medication registry.'
                : 'Medication identified by the registry, but it is not marked clinically verified yet.'),
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
          {'search': 'openfda.upc:"$upc"', 'limit': '5'},
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
          message:
              'Medication package matched the public FDA NDC Directory. This identifies the product for reference but does not establish Jamaica formulary approval.',
          onlineLookup: true,
        );
      } on Object {
        // Try next candidate.
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
        if (gtin.isNotEmpty && !gtins.contains(gtin)) gtins.add(gtin);
      }
    }
    final identifiers = json['identifiers'];
    if (identifiers is List) {
      for (final value in identifiers) {
        if (value is! Map) continue;
        final gtin = value['gtin14']?.toString();
        if (gtin != null && gtin.isNotEmpty && !gtins.contains(gtin)) gtins.add(gtin);
      }
    }
    final single = json['gtin']?.toString();
    if (single != null && single.isNotEmpty && !gtins.contains(single)) gtins.add(single);

    final ingredientNames = <String>[];
    final rawIngredients = json['ingredients'];
    if (rawIngredients is List) {
      for (final value in rawIngredients) {
        if (value is Map) {
          final name = value['name']?.toString() ?? value['ingredient_name']?.toString();
          if (name != null && name.isNotEmpty) ingredientNames.add(name);
        } else {
          final name = value.toString();
          if (name.isNotEmpty) ingredientNames.add(name);
        }
      }
    }

    return MedicationProduct(
      id: json['id']?.toString() ?? 'REGISTRY-${gtins.isEmpty ? brand : gtins.first}',
      genericName: generic,
      brandName: brand,
      strength: json['strength']?.toString() ?? '',
      dosageForm: json['dosageForm']?.toString() ?? json['dosage_form']?.toString() ?? '',
      manufacturer: json['manufacturer']?.toString() ?? '',
      importer: json['importer']?.toString(),
      source: clinicallyVerified
          ? MedicationProductSource.jamaicaApproved
          : MedicationProductSource.publicReference,
      packageDescription: json['packageDescription']?.toString() ?? json['package_description']?.toString(),
      gtins: gtins,
      rxcui: json['rxcui']?.toString(),
      ndc: json['ndc']?.toString(),
      clinicallyVerified: clinicallyVerified,
      jamaicaReference: json['jamaicaReference']?.toString() ??
          json['provenanceReference']?.toString() ??
          json['provenance_reference']?.toString(),
      therapeuticCategory: json['therapeuticCategory']?.toString() ?? json['therapeutic_category']?.toString(),
      prescriptionStatus: json['prescriptionStatus']?.toString() ?? json['prescription_status']?.toString(),
      ingredients: ingredientNames,
      formularyStatus: json['formularyStatus']?.toString() ?? json['formulary_status']?.toString(),
      approvalStatus: json['approvalStatus']?.toString() ?? json['approval_status']?.toString(),
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
      ingredients: ingredientNames,
      prescriptionStatus: json['marketing_category']?.toString(),
    );
  }
}
