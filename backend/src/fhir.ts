type Row = Record<string, unknown>;

function id(value: unknown): string {
  return String(value ?? '').replace(/[^A-Za-z0-9\-.]/g, '-');
}

export function medicationResource(row: Row) {
  return {
    resourceType: 'Medication',
    id: id(row.id),
    status: row.active === false ? 'inactive' : 'active',
    code: {
      text: [row.generic_name, row.strength, row.brand_name].filter(Boolean).join(' '),
    },
    form: row.dosage_form ? { text: String(row.dosage_form) } : undefined,
    manufacturer: row.manufacturer
      ? { display: String(row.manufacturer) }
      : undefined,
    extension: [
      {
        url: 'https://medqur.example/fhir/StructureDefinition/formulary-status',
        valueCode: String(row.formulary_status ?? 'unreviewed'),
      },
      {
        url: 'https://medqur.example/fhir/StructureDefinition/provenance-source',
        valueString: String(row.provenance_source ?? ''),
      },
    ],
  };
}

export function medicationRequestResource(row: Row) {
  return {
    resourceType: 'MedicationRequest',
    id: id(row.id),
    status: String(row.status ?? 'active'),
    intent: 'order',
    subject: { reference: `Patient/${id(row.patient_id)}` },
    encounter: { reference: `Encounter/${id(row.encounter_id)}` },
    medicationReference: row.product_id
      ? { reference: `Medication/${id(row.product_id)}` }
      : undefined,
    medicationCodeableConcept: row.product_id ? undefined : { text: String(row.medication_text ?? '') },
    authoredOn: row.ordered_at,
    requester: { reference: `Practitioner/${id(row.ordered_by)}` },
    dosageInstruction: [
      {
        text: `${row.dose ?? ''} ${row.route ?? ''} ${row.frequency ?? ''}`.trim(),
        route: row.route ? { text: String(row.route) } : undefined,
      },
    ],
  };
}

export function medicationDispenseResource(row: Row) {
  return {
    resourceType: 'MedicationDispense',
    id: id(row.id),
    status: row.status === 'cancelled' ? 'cancelled' : 'completed',
    medicationReference: { reference: `Medication/${id(row.product_id)}` },
    authorizingPrescription: [{ reference: `MedicationRequest/${id(row.order_id)}` }],
    performer: [{ actor: { reference: `Practitioner/${id(row.dispensed_by)}` } }],
    quantity: { value: Number(row.quantity ?? 0), unit: String(row.unit ?? 'unit') },
    whenHandedOver: row.dispensed_at,
  };
}

export function medicationAdministrationResource(row: Row) {
  return {
    resourceType: 'MedicationAdministration',
    id: id(row.id),
    status: String(row.status ?? 'completed').replace('not_done', 'not-done'),
    medicationReference: row.product_id
      ? { reference: `Medication/${id(row.product_id)}` }
      : undefined,
    subject: { reference: `Patient/${id(row.patient_id)}` },
    context: { reference: `Encounter/${id(row.encounter_id)}` },
    request: { reference: `MedicationRequest/${id(row.order_id)}` },
    performer: [{ actor: { reference: `Practitioner/${id(row.administered_by)}` } }],
    effectiveDateTime: row.administered_at,
  };
}

export function bundle(resources: unknown[]) {
  return {
    resourceType: 'Bundle',
    type: 'collection',
    timestamp: new Date().toISOString(),
    entry: resources.map((resource) => ({ resource })),
  };
}
