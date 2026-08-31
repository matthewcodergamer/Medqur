import '../models.dart';

/// Produces FHIR-shaped integration payloads for the prototype boundary.
/// These maps are deliberately not advertised as complete FHIR conformance;
/// a production integration must validate against the Ministry/EHR profiles.
class FhirAdapter {
  const FhirAdapter._();

  static Map<String, dynamic> patientResource(Patient patient) => {
        'resourceType': 'Patient',
        'id': patient.id,
        'identifier': [
          {'system': 'https://medqur.example/patient-id', 'value': patient.id}
        ],
        'name': [
          {'text': patient.name}
        ],
        'gender': patient.sex.toLowerCase(),
      };

  static Map<String, dynamic> encounterResource(Patient patient, Facility facility) => {
        'resourceType': 'Encounter',
        'id': patient.id,
        'status': patient.status == PatientStatus.discharge ? 'finished' : 'in-progress',
        'subject': {'reference': 'Patient/${patient.id}'},
        'serviceProvider': {'identifier': {'value': facility.id}, 'display': facility.name},
      };

  static Map<String, dynamic> medicationRequestResource(Patient patient, MedicationOrder order) => {
        'resourceType': 'MedicationRequest',
        'status': order.administered ? 'completed' : 'active',
        'intent': 'order',
        'subject': {'reference': 'Patient/${patient.id}'},
        'medication': {'concept': {'text': order.name}},
        'dosageInstruction': [
          {'text': '${order.dose} • ${order.route} • ${order.frequency}'}
        ],
        if (order.productCode != null)
          'identifier': [
            {'system': 'https://medqur.example/product-code', 'value': order.productCode}
          ],
      };
}
