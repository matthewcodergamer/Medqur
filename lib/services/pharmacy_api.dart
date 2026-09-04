import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class PharmacyApiException implements Exception {
  const PharmacyApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class PharmacyInventoryItem {
  const PharmacyInventoryItem({
    required this.id,
    required this.productId,
    required this.genericName,
    required this.brandName,
    required this.strength,
    required this.quantity,
    required this.unit,
    required this.locationCode,
    required this.locationName,
    required this.approvalStatus,
    required this.formularyStatus,
    this.lotId,
    this.lotNumber,
    this.expiryDate,
  });

  final String id;
  final String productId;
  final String genericName;
  final String brandName;
  final String strength;
  final double quantity;
  final String unit;
  final String locationCode;
  final String locationName;
  final String approvalStatus;
  final String formularyStatus;
  final String? lotId;
  final String? lotNumber;
  final DateTime? expiryDate;

  factory PharmacyInventoryItem.fromJson(Map<String, dynamic> json) =>
      PharmacyInventoryItem(
        id: json['id']?.toString() ?? '',
        productId: json['product_id']?.toString() ?? '',
        genericName: json['generic_name']?.toString() ?? '',
        brandName: json['brand_name']?.toString() ?? '',
        strength: json['strength']?.toString() ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ??
            double.tryParse(json['quantity']?.toString() ?? '') ??
            0,
        unit: json['unit']?.toString() ?? 'unit',
        locationCode: json['location_code']?.toString() ?? '',
        locationName: json['location_name']?.toString() ?? '',
        approvalStatus: json['approval_status']?.toString() ?? 'unverified',
        formularyStatus: json['formulary_status']?.toString() ?? 'unreviewed',
        lotId: json['lot_id']?.toString(),
        lotNumber: json['lot_number']?.toString(),
        expiryDate: DateTime.tryParse(json['expiry_date']?.toString() ?? ''),
      );

  String get displayName {
    final brand = brandName.trim().isEmpty ? '' : ' ($brandName)';
    return '$genericName $strength$brand'.trim();
  }
}

class RecallImpact {
  const RecallImpact({
    required this.severity,
    required this.reason,
    required this.genericName,
    required this.brandName,
    this.gtin,
    this.lotNumber,
    this.facilityId,
    this.inventoryQuantity,
    this.patientId,
    this.encounterId,
    this.administeredAt,
  });

  final String severity;
  final String reason;
  final String genericName;
  final String brandName;
  final String? gtin;
  final String? lotNumber;
  final String? facilityId;
  final double? inventoryQuantity;
  final String? patientId;
  final String? encounterId;
  final DateTime? administeredAt;

  factory RecallImpact.fromJson(Map<String, dynamic> json) => RecallImpact(
        severity: json['severity']?.toString() ?? 'notice',
        reason: json['reason']?.toString() ?? '',
        genericName: json['generic_name']?.toString() ?? '',
        brandName: json['brand_name']?.toString() ?? '',
        gtin: json['gtin14']?.toString(),
        lotNumber: json['lot_number']?.toString(),
        facilityId: json['facility_id']?.toString(),
        inventoryQuantity: double.tryParse(json['inventory_quantity']?.toString() ?? ''),
        patientId: json['patient_id']?.toString(),
        encounterId: json['encounter_id']?.toString(),
        administeredAt: DateTime.tryParse(json['administered_at']?.toString() ?? ''),
      );
}

class UnitDoseLabelResult {
  const UnitDoseLabelResult({
    required this.codeValue,
    required this.codeType,
    required this.dataMatrixSvg,
    required this.zpl,
  });
  final String codeValue;
  final String codeType;
  final String dataMatrixSvg;
  final String zpl;
}

/// Authenticated boundary to the Medqur pharmacy/national medication backend.
///
/// Production should inject a short-lived OIDC access token from the Medqur
/// authentication layer. `MEDQUR_DEV_BACKEND_AUTH=true` exists only for a local
/// workstation/docker demonstration and adds explicit development headers.
class PharmacyApiClient {
  PharmacyApiClient({
    http.Client? client,
    Future<String?> Function()? accessTokenProvider,
  })  : _client = client ?? http.Client(),
        _accessTokenProvider = accessTokenProvider;

  static const String configuredBase =
      String.fromEnvironment('MEDQUR_API_BASE', defaultValue: '');
  static const bool devBackendAuth =
      bool.fromEnvironment('MEDQUR_DEV_BACKEND_AUTH', defaultValue: false);

  final http.Client _client;
  final Future<String?> Function()? _accessTokenProvider;

  bool get isConfigured => configuredBase.trim().isNotEmpty;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(configuredBase.endsWith('/')
        ? configuredBase
        : '$configuredBase/');
    return base.resolve(path.startsWith('/') ? path.substring(1) : path).replace(
          queryParameters: query,
        );
  }

  Future<Map<String, String>> _headers({
    String? staffId,
    String? role,
    String? facilityId,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final token = await _accessTokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else if (devBackendAuth) {
      headers['x-medqur-staff-id'] = staffId ?? 'DEV-PHARMACIST';
      headers['x-medqur-role'] = role ?? 'pharmacist';
      headers['x-medqur-facility'] = facilityId ?? 'MRH';
      headers['x-medqur-staff-name'] = 'Medqur Development User';
    }
    return headers;
  }

  Future<List<PharmacyInventoryItem>> inventory({
    required String facilityId,
    required String staffId,
    required String role,
  }) async {
    _requireConfigured();
    final response = await _client.get(
      _uri('v1/inventory', {'facilityId': facilityId}),
      headers: await _headers(staffId: staffId, role: role, facilityId: facilityId),
    );
    final body = _decode(response);
    final items = body['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PharmacyInventoryItem.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> receiveStock({
    required String facilityId,
    required String staffId,
    required String role,
    required String locationCode,
    required String lotNumber,
    required double quantity,
    required String unit,
    String? productId,
    String? gtin,
    DateTime? manufactureDate,
    DateTime? expiryDate,
    String serialNumber = '',
    String supplier = '',
    String? rawScan,
    String? scanFormat,
  }) async {
    _requireConfigured();
    final response = await _client.post(
      _uri('v1/pharmacy/receive'),
      headers: await _headers(staffId: staffId, role: role, facilityId: facilityId),
      body: jsonEncode({
        'facilityId': facilityId,
        'locationCode': locationCode,
        if (productId != null) 'productId': productId,
        if (gtin != null) 'gtin': gtin,
        'lotNumber': lotNumber,
        if (manufactureDate != null) 'manufactureDate': manufactureDate.toIso8601String(),
        if (expiryDate != null) 'expiryDate': expiryDate.toIso8601String(),
        'serialNumber': serialNumber,
        'supplier': supplier,
        'quantity': quantity,
        'unit': unit,
        if (rawScan != null) 'rawScan': rawScan,
        if (scanFormat != null) 'scanFormat': scanFormat,
      }),
    );
    return _decode(response);
  }

  Future<List<RecallImpact>> searchRecall({
    required String staffId,
    required String role,
    String? gtin,
    String? lot,
  }) async {
    _requireConfigured();
    final response = await _client.get(
      _uri('v1/recalls/search', {
        if (gtin != null && gtin.trim().isNotEmpty) 'gtin': gtin.trim(),
        if (lot != null && lot.trim().isNotEmpty) 'lot': lot.trim(),
      }),
      headers: await _headers(staffId: staffId, role: role),
    );
    final body = _decode(response);
    final items = body['impacts'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(RecallImpact.fromJson)
        .toList();
  }

  Future<UnitDoseLabelResult> generateUnitDoseLabel({
    required String facilityId,
    required String staffId,
    required String role,
    required String productId,
    String? lotId,
    String? dispenseId,
    String? existingUnitCode,
  }) async {
    _requireConfigured();
    final response = await _client.post(
      _uri('v1/labels/unit-dose'),
      headers: await _headers(staffId: staffId, role: role, facilityId: facilityId),
      body: jsonEncode({
        'facilityId': facilityId,
        'productId': productId,
        if (lotId != null) 'lotId': lotId,
        if (dispenseId != null) 'dispenseId': dispenseId,
        if (existingUnitCode != null) 'existingUnitCode': existingUnitCode,
      }),
    );
    final body = _decode(response);
    return UnitDoseLabelResult(
      codeValue: body['codeValue']?.toString() ?? '',
      codeType: body['codeType']?.toString() ?? 'DataMatrix',
      dataMatrixSvg: body['dataMatrixSvg']?.toString() ?? '',
      zpl: body['zpl']?.toString() ?? '',
    );
  }

  Future<Map<String, dynamic>> createOrder({
    required String staffId,
    required String facilityId,
    required String patientId,
    required String encounterId,
    required String medicationText,
    required String dose,
    required String route,
    required String frequency,
    String? productId,
    DateTime? dueAt,
    int earlyGraceMinutes = 30,
    int lateGraceMinutes = 60,
    String? signaturePayload,
    String? signatureSha256,
    DateTime? signatureSignedAt,
    String? signatureMethod,
  }) async {
    _requireConfigured();
    final response = await _client.post(
      _uri('v1/orders'),
      headers: await _headers(staffId: staffId, role: 'doctor', facilityId: facilityId),
      body: jsonEncode({
        'patientId': patientId,
        'encounterId': encounterId,
        'facilityId': facilityId,
        if (productId != null) 'productId': productId,
        'medicationText': medicationText,
        'dose': dose,
        'route': route,
        'frequency': frequency,
        if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
        'earlyGraceMinutes': earlyGraceMinutes,
        'lateGraceMinutes': lateGraceMinutes,
        if (signaturePayload != null) 'signaturePayload': signaturePayload,
        if (signatureSha256 != null) 'signatureSha256': signatureSha256,
        if (signatureSignedAt != null) 'signatureSignedAt': signatureSignedAt.toIso8601String(),
        if (signatureMethod != null) 'signatureMethod': signatureMethod,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> structuredSafetyCheck({
    required String staffId,
    required String facilityId,
    required String patientId,
    required String productId,
    List<String> currentProductIds = const [],
  }) async {
    _requireConfigured();
    final response = await _client.post(
      _uri('v1/medications/safety-check'),
      headers: await _headers(staffId: staffId, role: 'nurse', facilityId: facilityId),
      body: jsonEncode({
        'patientId': patientId,
        'productId': productId,
        'currentProductIds': currentProductIds,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> recordAdministration({
    required String staffId,
    required String facilityId,
    required String orderId,
    required String patientId,
    required String encounterId,
    required String productId,
    required String patientScan,
    required String medicationScan,
    String? dispenseId,
    String? lotId,
    String? overrideReason,
  }) async {
    _requireConfigured();
    final response = await _client.post(
      _uri('v1/administrations'),
      headers: await _headers(staffId: staffId, role: 'nurse', facilityId: facilityId),
      body: jsonEncode({
        'orderId': orderId,
        if (dispenseId != null) 'dispenseId': dispenseId,
        'patientId': patientId,
        'encounterId': encounterId,
        'facilityId': facilityId,
        'productId': productId,
        if (lotId != null) 'lotId': lotId,
        'patientScan': patientScan,
        'medicationScan': medicationScan,
        if (overrideReason != null) 'overrideReason': overrideReason,
      }),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> encounterFhir({
    required String encounterId,
    required String staffId,
    required String role,
    required String facilityId,
  }) async {
    _requireConfigured();
    final response = await _client.get(
      _uri('v1/fhir/encounters/${Uri.encodeComponent(encounterId)}/medications'),
      headers: await _headers(staffId: staffId, role: role, facilityId: facilityId),
    );
    return _decode(response);
  }

  Stream<Map<String, dynamic>> events({
    required String facilityId,
    required String staffId,
    required String role,
  }) async* {
    _requireConfigured();
    final request = http.Request('GET', _uri('v1/events', {'facilityId': facilityId}));
    request.headers.addAll(
      await _headers(staffId: staffId, role: role, facilityId: facilityId),
    );
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = await response.stream.bytesToString();
      throw PharmacyApiException(detail, statusCode: response.statusCode);
    }
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final payload = line.substring(6);
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) yield decoded;
      } on FormatException {
        // Ignore malformed realtime frames rather than breaking the shift.
      }
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = const {};
    if (response.body.trim().isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PharmacyApiException(
        body['error']?.toString() ?? 'Backend request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  void _requireConfigured() {
    if (!isConfigured) {
      throw const PharmacyApiException(
        'Medqur backend is not configured. Set MEDQUR_API_BASE for this build.',
      );
    }
  }

  void dispose() => _client.close();
}
