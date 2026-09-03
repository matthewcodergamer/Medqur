import '../models.dart';

/// Produces FHIR-shaped integration payloads for the prototype boundary.
/// These maps are deliberately not advertised as complete FHIR conformance;
/// a production integration must validate against the Ministry/e-Care profiles.
class FhirAdapter {
  const FhirAdapter._();

  static Map<String, dynamic> patientResource(Patient patient) => {
        'resourceType': 'Patient',
        'id': patient.id,
        'identifier': [
          {'system': 'https://medqur.example/patient-id', 'value': patient.id},
        ],
        'name': [
          {'text': patient.name},
        ],
        'gender': patient.sex.toLowerCase(),
        if (patient.dateOfBirth != null) 'birthDate': patient.dateOfBirth,
      };

  static Map<String, dynamic> encounterResource(Patient patient, Facility facility) => {
        'resourceType': 'Encounter',
        'id': patient.effectiveEncounterId,
        'identifier': [
          {
            'system': 'https://medqur.example/encounter-id',
            'value': patient.effectiveEncounterId,
          },
        ],
        'status': patient.status == PatientStatus.discharge ? 'finished' : 'in-progress',
        'subject': {'reference': 'Patient/${patient.id}'},
        'serviceProvider': {
          'identifier': {'value': facility.id},
          'display': facility.name,
        },
      };

  static List<Map<String, dynamic>> observationResources(Patient patient) {
    return patient.vitals.entries
        .map((entry) => {
              'resourceType': 'Observation',
              'status': 'final',
              'category': [
                {
                  'coding': [
                    {
                      'system': 'http://terminology.hl7.org/CodeSystem/observation-category',
                      'code': 'vital-signs',
                    }
                  ]
                }
              ],
              'code': {'text': entry.key},
              'subject': {'reference': 'Patient/${patient.id}'},
              'encounter': {'reference': 'Encounter/${patient.effectiveEncounterId}'},
              'valueString': entry.value,
            })
        .toList();
  }

  static List<Map<String, dynamic>> allergyResources(Patient patient) {
    return patient.allergies
        .where((value) =>
            value.trim().isNotEmpty &&
            !value.toLowerCase().contains('no known') &&
            value.toLowerCase() != 'nkda')
        .map((allergy) => {
              'resourceType': 'AllergyIntolerance',
              'clinicalStatus': {
                'coding': [
                  {
                    'system': 'http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical',
                    'code': 'active',
                  }
                ]
              },
              'patient': {'reference': 'Patient/${patient.id}'},
              'code': {'text': allergy},
            })
        .toList();
  }

  static Map<String, dynamic> medicationRequestResource(
    Patient patient,
    MedicationOrder order,
  ) =>
      {
        'resourceType': 'MedicationRequest',
        'status': order.administered ? 'completed' : 'active',
        'intent': 'order',
        'subject': {'reference': 'Patient/${patient.id}'},
        'encounter': {'reference': 'Encounter/${patient.effectiveEncounterId}'},
        'medication': {
          'concept': {'text': order.name},
        },
        'dosageInstruction': [
          {'text': '${order.dose} • ${order.route} • ${order.frequency}'},
        ],
        if (order.productCode != null)
          'identifier': [
            {
              'system': 'https://medqur.example/product-code',
              'value': order.productCode,
            }
          ],
      };

  static Map<String, dynamic> medicationAdministrationResource(
    Patient patient,
    MedicationOrder order,
  ) =>
      {
        'resourceType': 'MedicationAdministration',
        'status': order.administered ? 'completed' : 'not-done',
        'subject': {'reference': 'Patient/${patient.id}'},
        'encounter': {'reference': 'Encounter/${patient.effectiveEncounterId}'},
        'medication': {
          'concept': {'text': order.name},
        },
        'dosage': {
          'text': '${order.dose} • ${order.route}',
        },
        if (order.productCode != null)
          'identifier': [
            {
              'system': 'https://medqur.example/scanned-product-code',
              'value': order.productCode,
            }
          ],
      };
}
