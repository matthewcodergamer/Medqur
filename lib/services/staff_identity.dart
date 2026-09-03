import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

class StaffBadgePermission {
  const StaffBadgePermission({
    required this.role,
    required this.facilityId,
    required this.facilityName,
  });

  final String role;
  final String facilityId;
  final String facilityName;
}

class StaffBadgeVerification {
  const StaffBadgeVerification({
    required this.valid,
    required this.staffNumber,
    required this.displayName,
    required this.professionalRegistration,
    required this.permissions,
    required this.credentialId,
    required this.expiresAt,
    required this.signingKeyId,
    this.error,
  });

  final bool valid;
  final String staffNumber;
  final String displayName;
  final String professionalRegistration;
  final List<StaffBadgePermission> permissions;
  final String credentialId;
  final DateTime? expiresAt;
  final String signingKeyId;
  final String? error;

  String? get primaryRole => permissions.isEmpty ? null : permissions.first.role;
}

class StaffBadgePresentation {
  const StaffBadgePresentation({
    required this.token,
    required this.staffNumber,
    required this.credentialId,
    required this.issuedAt,
    required this.expiresAt,
    required this.signingKeyId,
  });

  final String token;
  final String staffNumber;
  final String credentialId;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String signingKeyId;
}

class StaffBadgeCodec {
  const StaffBadgeCodec._();

  static final RegExp _sixDigits = RegExp(r'^\d{6}$');

  static bool isSixDigitStaffNumber(String value) =>
      _sixDigits.hasMatch(value.trim());

  static String normalizeStaffNumber(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  /// Local prototype badge used only when no credential service is configured.
  /// Production signed badges always begin with `MQW1.` and are verified by the
  /// staff identity service before device authentication starts.
  static String prototypeToken(String staffNumber) {
    final normalized = normalizeStaffNumber(staffNumber);
    if (!isSixDigitStaffNumber(normalized)) {
      throw ArgumentError.value(staffNumber, 'staffNumber', 'must contain six digits');
    }
    return 'MQS1|$normalized';
  }

  static bool looksSigned(String raw) => raw.trim().startsWith('MQW1.');

  static String? prototypeStaffNumber(String raw) {
    var value = raw.trim();
    final upper = value.toUpperCase();
    if (upper.startsWith('MQS1|')) {
      value = value.substring(5);
    } else if (upper.startsWith('MQS|')) {
      value = value.substring(4);
    } else {
      final uri = Uri.tryParse(value);
      if (uri != null &&
          uri.scheme == 'medqur' &&
          uri.host == 'staff' &&
          uri.pathSegments.isNotEmpty) {
        value = uri.pathSegments.last;
      }
    }
    final normalized = normalizeStaffNumber(value);
    return isSixDigitStaffNumber(normalized) ? normalized : null;
  }
}

class StaffIdentityClient {
  StaffIdentityClient({
    http.Client? client,
    Future<String?> Function()? accessTokenProvider,
  })  : _client = client ?? http.Client(),
        _accessTokenProvider = accessTokenProvider;

  static const String _identityBase = String.fromEnvironment(
    'MEDQUR_IDENTITY_API_BASE',
    defaultValue: '',
  );
  static const String _apiBase = String.fromEnvironment(
    'MEDQUR_API_BASE',
    defaultValue: '',
  );
  static const bool _devBackendAuth = bool.fromEnvironment(
    'MEDQUR_DEV_BACKEND_AUTH',
    defaultValue: false,
  );

  static String get configuredBase =>
      _identityBase.trim().isNotEmpty ? _identityBase.trim() : _apiBase.trim();

  bool get isConfigured => configuredBase.isNotEmpty;

  final http.Client _client;
  final Future<String?> Function()? _accessTokenProvider;

  void dispose() => _client.close();

  Uri _uri(String path) {
    final configured = configuredBase;
    if (configured.isEmpty) {
      throw StateError('MEDQUR_IDENTITY_API_BASE is not configured.');
    }
    final base = Uri.parse(configured.endsWith('/') ? configured : '$configured/');
    return base.resolve(path);
  }

  Future<Map<String, String>> _headers({
    StaffProfile? staff,
    Facility? facility,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final token = await _accessTokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      return headers;
    }
    if (_devBackendAuth && staff != null) {
      headers['x-medqur-staff-id'] = staff.id;
      headers['x-medqur-role'] = _roleName(staff.role);
      if (facility != null) headers['x-medqur-facility'] = facility.id;
    }
    return headers;
  }

  Future<StaffBadgeVerification> verifyBadge(String token) async {
    if (!isConfigured) {
      return StaffBadgeVerification(
        valid: false,
        staffNumber: '',
        displayName: '',
        professionalRegistration: '',
        permissions: const [],
        credentialId: '',
        expiresAt: null,
        signingKeyId: '',
        error: 'Staff identity service is not configured.',
      );
    }
    try {
      final response = await _client
          .post(
            _uri('v1/public/staff-badge/verify'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'token': token.trim()}),
          )
          .timeout(const Duration(seconds: 8));
      final decoded = jsonDecode(response.body);
      final body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (response.statusCode != 200 || body['valid'] != true) {
        return StaffBadgeVerification(
          valid: false,
          staffNumber: '',
          displayName: '',
          professionalRegistration: '',
          permissions: const [],
          credentialId: '',
          expiresAt: null,
          signingKeyId: '',
          error: body['error']?.toString() ?? 'Staff badge verification failed.',
        );
      }

      final staff = body['staff'] is Map<String, dynamic>
          ? body['staff'] as Map<String, dynamic>
          : <String, dynamic>{};
      final credential = body['credential'] is Map<String, dynamic>
          ? body['credential'] as Map<String, dynamic>
          : <String, dynamic>{};
      final permissions = <StaffBadgePermission>[];
      final rawPermissions = staff['permissions'];
      if (rawPermissions is List) {
        for (final raw in rawPermissions) {
          if (raw is! Map) continue;
          permissions.add(StaffBadgePermission(
            role: raw['role']?.toString() ?? '',
            facilityId: raw['facilityId']?.toString() ?? '',
            facilityName: raw['facilityName']?.toString() ?? '',
          ));
        }
      }

      return StaffBadgeVerification(
        valid: true,
        staffNumber: staff['staffNumber']?.toString() ?? '',
        displayName: staff['displayName']?.toString() ?? '',
        professionalRegistration:
            staff['professionalRegistration']?.toString() ?? '',
        permissions: List.unmodifiable(permissions),
        credentialId: credential['id']?.toString() ?? '',
        expiresAt: DateTime.tryParse(credential['expiresAt']?.toString() ?? ''),
        signingKeyId: credential['signingKeyId']?.toString() ?? '',
      );
    } on Object catch (error) {
      return StaffBadgeVerification(
        valid: false,
        staffNumber: '',
        displayName: '',
        professionalRegistration: '',
        permissions: const [],
        credentialId: '',
        expiresAt: null,
        signingKeyId: '',
        error: 'Unable to verify staff badge: $error',
      );
    }
  }

  Future<StaffBadgePresentation?> fetchMyBadge({
    required StaffProfile staff,
    required Facility facility,
  }) async {
    if (!isConfigured) return null;
    final response = await _client
        .get(
          _uri('v1/staff/badge'),
          headers: await _headers(staff: staff, facility: facility),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['badge'] is! Map<String, dynamic>) {
      return null;
    }
    final badge = decoded['badge'] as Map<String, dynamic>;
    final token = badge['token']?.toString() ?? '';
    final staffNumber = badge['staffNumber']?.toString() ?? '';
    if (!StaffBadgeCodec.looksSigned(token) ||
        !StaffBadgeCodec.isSixDigitStaffNumber(staffNumber)) {
      return null;
    }
    return StaffBadgePresentation(
      token: token,
      staffNumber: staffNumber,
      credentialId: badge['credentialId']?.toString() ?? '',
      issuedAt: DateTime.tryParse(badge['issuedAt']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(badge['expiresAt']?.toString() ?? ''),
      signingKeyId: badge['signingKeyId']?.toString() ?? '',
    );
  }

  static String _roleName(StaffRole role) => switch (role) {
        StaffRole.doctor => 'doctor',
        StaffRole.nurse => 'nurse',
        StaffRole.pharmacist => 'pharmacist',
      };
}
