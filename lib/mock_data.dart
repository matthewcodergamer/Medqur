import 'models.dart';

const facilities = <Facility>[
  Facility(
    id: 'MRH',
    name: 'Mandeville Regional Hospital',
    area: 'Mandeville, Manchester',
    parish: 'Manchester',
    type: 'Hospital',
    classification: FacilityClass.typeBHospital,
    suggested: true,
  ),
  Facility(
    id: 'JHC',
    name: 'Junction Health Centre',
    area: 'Junction, St. Elizabeth',
    parish: 'St. Elizabeth',
    type: 'Health Centre',
    classification: FacilityClass.type2HealthCentre,
  ),
  Facility(
    id: 'SPH',
    name: 'Spanish Town Hospital',
    area: 'Spanish Town, St. Catherine',
    parish: 'St. Catherine',
    type: 'Hospital',
    classification: FacilityClass.typeBHospital,
  ),
];

// Every health worker uses one stable six-digit Medqur staff number regardless
// of profession, parish or facility. These are prototype identities only.
const demoDoctor = StaffProfile(
  id: '482731',
  name: 'Dr. Maya Brown',
  role: StaffRole.doctor,
  title: 'Medical Officer',
  registration: 'MCR-204781',
  facilities: facilities,
);

const demoNurse = StaffProfile(
  id: '615204',
  name: 'Nurse Aaliyah Grant',
  role: StaffRole.nurse,
  title: 'Registered Nurse',
  registration: 'NCR-109388',
  facilities: facilities,
);

const demoPharmacist = StaffProfile(
  id: '739182',
  name: 'Pharmacist Jordan Reid',
  role: StaffRole.pharmacist,
  title: 'Hospital Pharmacist',
  registration: 'PHR-DEMO-2049',
  facilities: facilities,
);

List<Patient> buildDemoPatients() => [
      Patient(
        id: 'MQP-208491',
        name: 'Shanice Campbell',
        age: 29,
        sex: 'Female',
        nidsStatus: 'NIDS verified',
        chiefComplaint: 'Shortness of breath and chest tightness',
        triage: TriageLevel.urgent,
        status: PatientStatus.triaged,
        waitMinutes: 8,
        vitals: {
          'BP': '128/82',
          'Pulse': '104 bpm',
          'SpO₂': '94%',
          'Temp': '37.4 °C',
        },
        allergies: ['Penicillin'],
        timeline: [
          '03:07 — Identity verified',
          '03:11 — Triage completed by Nurse Grant',
          '03:13 — Assigned to Dr. Brown',
        ],
        medications: [],
      ),
      Patient(
        id: 'MQP-772104',
        name: 'Andre Williams',
        age: 41,
        sex: 'Male',
        nidsStatus: 'NIDS verified',
        chiefComplaint: 'Lower abdominal pain',
        triage: TriageLevel.moderate,
        status: PatientStatus.triaged,
        waitMinutes: 17,
        vitals: {
          'BP': '119/76',
          'Pulse': '86 bpm',
          'SpO₂': '98%',
          'Temp': '37.0 °C',
        },
        allergies: ['No known allergies'],
        timeline: [
          '02:54 — Identity verified',
          '03:00 — Triage completed',
        ],
        medications: [
          MedicationOrder(
            name: 'Paracetamol',
            dose: '1 g',
            route: 'Oral',
            frequency: 'Once',
            orderedBy: 'Dr. Maya Brown',
          )
        ],
      ),
      Patient(
        id: 'TEMP-0091',
        name: 'Unknown Patient 0091',
        age: 0,
        sex: 'Unknown',
        nidsStatus: 'Temporary emergency identity',
        chiefComplaint: 'Found unresponsive; identity pending',
        triage: TriageLevel.critical,
        status: PatientStatus.withDoctor,
        waitMinutes: 0,
        vitals: {
          'BP': '92/58',
          'Pulse': '122 bpm',
          'SpO₂': '91%',
          'Temp': '36.5 °C',
        },
        allergies: ['Unknown'],
        timeline: [
          '03:18 — Emergency encounter created',
          '03:18 — Immediate clinical care started',
        ],
        medications: [],
      ),
      Patient(
        id: 'MQP-119502',
        name: 'Keisha Morgan',
        age: 66,
        sex: 'Female',
        nidsStatus: 'NIDS verified',
        chiefComplaint: 'Dizziness after morning medication',
        triage: TriageLevel.routine,
        status: PatientStatus.waiting,
        waitMinutes: 26,
        vitals: {
          'BP': '108/68',
          'Pulse': '72 bpm',
          'SpO₂': '99%',
          'Temp': '36.8 °C',
        },
        allergies: ['Sulfa drugs'],
        timeline: [
          '02:49 — Identity verified',
          '02:52 — Registration complete',
        ],
        medications: [],
      ),
    ];
