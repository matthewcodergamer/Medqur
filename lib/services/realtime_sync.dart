import '../models.dart';

/// Boundary used by the UI/store for future nurse/doctor cross-device sync.
/// V0.2 keeps this disconnected until an authenticated Ministry-approved
/// backend exists; the local app itself stays synchronized through shared state.
abstract class ClinicalSyncGateway {
  bool get isConfigured;
  Future<void> publishPatients(List<Patient> patients);
}

class DisconnectedClinicalSyncGateway implements ClinicalSyncGateway {
  const DisconnectedClinicalSyncGateway();
  @override
  bool get isConfigured => false;
  @override
  Future<void> publishPatients(List<Patient> patients) async {}
}
