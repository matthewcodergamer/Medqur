import 'package:flutter/material.dart';

import '../models.dart';
import 'pharmacy_page_v2.dart' as v14;

/// Source-compatible entry point for older shells while V0.14 passes the live
/// patient list and persistence callback needed by the dispensing queue.
class PharmacyPage extends StatelessWidget {
  const PharmacyPage({
    super.key,
    required this.staff,
    required this.facility,
    this.patients = const <Patient>[],
    this.onPatientsChanged,
  });

  final StaffProfile staff;
  final Facility facility;
  final List<Patient> patients;
  final Future<void> Function()? onPatientsChanged;

  @override
  Widget build(BuildContext context) => v14.PharmacyPage(
        staff: staff,
        facility: facility,
        patients: patients,
        onPatientsChanged: onPatientsChanged ?? () async {},
      );
}
