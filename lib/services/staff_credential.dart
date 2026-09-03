import '../models.dart';
import 'security_foundation.dart';

class StaffCredential {
  const StaffCredential({
    required this.credentialId,
    required this.staffId,
    required this.issuedAt,
    required this.active,
  });

  final String credentialId;
  final String staffId;
  final DateTime issuedAt;
  final bool active;

  String get qrValue => 'medqur://credential/v1/$credentialId';
}

class StaffCredentialIssuer {
  const StaffCredentialIssuer._();

  static StaffCredential issueFor(StaffProfile staff) {
    return StaffCredential(
      credentialId: MedqurSecurity.generateOpaqueToken(),
      staffId: staff.id,
      issuedAt: DateTime.now().toUtc(),
      active: true,
    );
  }
}

abstract class StaffCredentialDirectory {
  Future<StaffProfile?> resolve(String opaqueCredentialId);
  Future<bool> isActive(String opaqueCredentialId);
  Future<void> revoke(String opaqueCredentialId, {required String reason});
}
