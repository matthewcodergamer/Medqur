import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';

class PatientDetailPage extends StatefulWidget {
  const PatientDetailPage({
    super.key,
    required this.staff,
    required this.patient,
    required this.onChanged,
  });

  final StaffProfile staff;
  final Patient patient;
  final VoidCallback onChanged;

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  bool get isDoctor => widget.staff.role == StaffRole.doctor;

  Future<void> _addOrder() async {
    final medication = TextEditingController();
    final dose = TextEditingController();
    String route = 'Oral';
    String frequency = 'Once';

    final order = await showModalBottomSheet<MedicationOrder>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  22,
                  8,
                  22,
                  22 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'New medication order',
                        style: TextStyle(
                          color: medqurInk,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Structured fields help remove handwriting ambiguity and keep the nursing task exact.',
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: medication,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Medication',
                          hintText: 'e.g. Paracetamol',
                          prefixIcon: Icon(Icons.medication_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dose,
                        decoration: const InputDecoration(
                          labelText: 'Dose',
                          hintText: 'e.g. 1 g',
                          prefixIcon: Icon(Icons.straighten_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: route,
                        decoration: const InputDecoration(
                          labelText: 'Route',
                          prefixIcon: Icon(Icons.route_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Oral', child: Text('Oral')),
                          DropdownMenuItem(value: 'IV', child: Text('IV')),
                          DropdownMenuItem(value: 'IM', child: Text('IM')),
                          DropdownMenuItem(value: 'Inhaled', child: Text('Inhaled')),
                          DropdownMenuItem(value: 'Topical', child: Text('Topical')),
                        ],
                        onChanged: (value) {
                          if (value != null) setSheetState(() => route = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: frequency,
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                          prefixIcon: Icon(Icons.schedule_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Once', child: Text('Once')),
                          DropdownMenuItem(value: 'Every 4 hours', child: Text('Every 4 hours')),
                          DropdownMenuItem(value: 'Every 6 hours', child: Text('Every 6 hours')),
                          DropdownMenuItem(value: 'Every 8 hours', child: Text('Every 8 hours')),
                          DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                        ],
                        onChanged: (value) {
                          if (value != null) setSheetState(() => frequency = value);
                        },
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () {
                          final name = medication.text.trim();
                          final doseValue = dose.text.trim();
                          if (name.isEmpty || doseValue.isEmpty) return;
                          Navigator.of(sheetContext).pop(
                            MedicationOrder(
                              name: name,
                              dose: doseValue,
                              route: route,
                              frequency: frequency,
                              orderedBy: widget.staff.name,
                            ),
                          );
                        },
                        icon: const Icon(Icons.draw_outlined),
                        label: const Text('Sign and send order'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    medication.dispose();
    dose.dispose();

    if (order == null || !mounted) return;

    setState(() {
      widget.patient.medications.add(order);
      widget.patient.status = PatientStatus.treatment;
      widget.patient.timeline.add(
        '${_timeNow()} — ${order.name} ${order.dose} ordered by ${widget.staff.name}',
      );
    });
    widget.onChanged();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Medication order sent to the nursing task list.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _administer(MedicationOrder medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.qr_code_scanner_rounded, color: medqurBlue),
        title: const Text('Verify before administration'),
        content: Text(
          'Prototype scan check:\n\nPatient: ${widget.patient.name}\nMedication: ${medication.name} ${medication.dose}\nRoute: ${medication.route}\n\nIn production, Medqur would require a valid patient wristband and medication barcode match.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.verified_rounded),
            label: const Text('Verify & give'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final index = widget.patient.medications.indexOf(medication);
    if (index < 0) return;

    setState(() {
      widget.patient.medications[index] = medication.copyWith(administered: true);
      widget.patient.timeline.add(
        '${_timeNow()} — ${medication.name} ${medication.dose} administered by ${widget.staff.name}',
      );
    });
    widget.onChanged();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Administration recorded in the encounter timeline.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _timeNow() {
    final now = TimeOfDay.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;
    final color = triageColor(patient.triage);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            const MedqurLogo(width: 104),
            const SizedBox(width: 10),
            Container(width: 1, height: 24, color: medqurLine),
            const SizedBox(width: 10),
            const Text('Patient record', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: color.withValues(alpha: .10),
                      foregroundColor: color,
                      child: Text(
                        patient.name.startsWith('Unknown')
                            ? '?'
                            : patient.name.split(' ').take(2).map((part) => part[0]).join(),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.name,
                            style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: -.4),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${patient.id} • ${patient.age == 0 ? 'Age unknown' : '${patient.age} years'} • ${patient.sex}',
                            style: const TextStyle(color: Color(0xFF6B7A8F)),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(label: triageLabel(patient.triage), color: color),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(
                      label: patient.nidsStatus,
                      color: patient.nidsStatus.startsWith('NIDS') ? medqurGreen : medqurAmber,
                      icon: patient.nidsStatus.startsWith('NIDS') ? Icons.verified_user_outlined : Icons.emergency_outlined,
                    ),
                    StatusPill(
                      label: patientStatusLabel(patient.status),
                      color: medqurBlue,
                      icon: Icons.local_hospital_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Chief complaint'),
          const SizedBox(height: 10),
          SoftCard(
            child: Text(
              patient.chiefComplaint,
              style: const TextStyle(fontSize: 16, color: medqurInk, fontWeight: FontWeight.w700, height: 1.45),
            ),
          ),
          const SizedBox(height: 22),
          const SectionTitle('Latest vitals'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: patient.vitals.entries
                .map(
                  (entry) => Container(
                    width: 150,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: medqurLine),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key, style: const TextStyle(color: Color(0xFF78869A), fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text(entry.value, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900, fontSize: 17)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 22),
          const SectionTitle('Allergies'),
          const SizedBox(height: 10),
          SoftCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: patient.allergies
                  .map(
                    (allergy) => StatusPill(
                      label: allergy,
                      color: allergy.toLowerCase().contains('no known') ? medqurGreen : medqurRed,
                      icon: Icons.warning_amber_rounded,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 22),
          SectionTitle(
            'Medication orders',
            trailing: isDoctor
                ? TextButton.icon(
                    onPressed: _addOrder,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add order'),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          if (patient.medications.isEmpty)
            SoftCard(
              child: Row(
                children: [
                  Icon(Icons.medication_outlined, color: medqurBlue.withValues(alpha: .7)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('No active medication orders for this encounter.')),
                  if (isDoctor)
                    TextButton(onPressed: _addOrder, child: const Text('Create')),
                ],
              ),
            )
          else
            for (final medication in patient.medications)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: (medication.administered ? medqurGreen : medqurBlue).withValues(alpha: .10),
                            foregroundColor: medication.administered ? medqurGreen : medqurBlue,
                            child: Icon(medication.administered ? Icons.check_rounded : Icons.medication_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${medication.name} • ${medication.dose}', style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text('${medication.route} • ${medication.frequency}', style: const TextStyle(color: Color(0xFF65748A), fontSize: 13)),
                                const SizedBox(height: 3),
                                Text('Ordered by ${medication.orderedBy}', style: const TextStyle(color: Color(0xFF8793A4), fontSize: 11)),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: medication.administered ? 'Given' : 'Pending',
                            color: medication.administered ? medqurGreen : medqurAmber,
                          ),
                        ],
                      ),
                      if (!isDoctor && !medication.administered) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: () => _administer(medication),
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: const Text('Scan, verify & administer'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 22),
          const SectionTitle('Encounter timeline'),
          const SizedBox(height: 10),
          SoftCard(
            child: Column(
              children: [
                for (var i = 0; i < patient.timeline.length; i++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(color: medqurBlue, shape: BoxShape.circle),
                          ),
                          if (i < patient.timeline.length - 1)
                            Container(width: 1, height: 35, color: medqurLine),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Text(patient.timeline[i], style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Prototype only • All names and clinical information shown here are simulated. No live NIDS, e-Care, or Ministry system is connected.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8793A4), fontSize: 11, height: 1.4),
          ),
        ],
      ),
      floatingActionButton: isDoctor
          ? FloatingActionButton.extended(
              onPressed: _addOrder,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Medication order'),
            )
          : null,
    );
  }
}
