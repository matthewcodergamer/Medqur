import 'package:flutter/material.dart';

import '../clinical_models.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';

class ClinicalOrderComposerPage extends StatefulWidget {
  const ClinicalOrderComposerPage({
    super.key,
    required this.staff,
    required this.patient,
    required this.facility,
  });

  final StaffProfile staff;
  final Patient patient;
  final Facility facility;

  @override
  State<ClinicalOrderComposerPage> createState() =>
      _ClinicalOrderComposerPageState();
}

class _ClinicalOrderComposerPageState extends State<ClinicalOrderComposerPage> {
  DiagnosticOrderType _type = DiagnosticOrderType.xray;
  DiagnosticOrderPriority _priority = DiagnosticOrderPriority.routine;
  final _study = TextEditingController();
  final _instructions = TextEditingController();

  @override
  void initState() {
    super.initState();
    _study.text = _type.defaultStudyName;
  }

  @override
  void dispose() {
    _study.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _setType(DiagnosticOrderType value) {
    setState(() {
      final oldDefault = _type.defaultStudyName;
      _type = value;
      if (_study.text.trim().isEmpty || _study.text.trim() == oldDefault) {
        _study.text = value.defaultStudyName;
      }
    });
  }

  void _submit() {
    final study = _study.text.trim();
    if (study.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the test or study to order.')),
      );
      return;
    }

    final now = DateTime.now();
    Navigator.of(context).pop(
      DiagnosticOrder(
        id: 'DX-${now.microsecondsSinceEpoch}',
        patientId: widget.patient.id,
        encounterId: widget.patient.effectiveEncounterId,
        facilityId: widget.facility.id,
        type: _type,
        studyName: study,
        instructions: _instructions.text.trim(),
        priority: _priority,
        orderedBy: widget.staff.name,
        orderedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New test / procedure')),
      body: MedqurPage(
        children: [
          PatientContextBar(patient: widget.patient),
          const SizedBox(height: 18),
          const MedqurPageHeader(
            eyebrow: 'Doctor order',
            title: 'Investigation',
            subtitle:
                'Choose the investigation and Medqur will route it to the appropriate clinical-support worklist.',
          ),
          const SizedBox(height: 18),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<DiagnosticOrderType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Order type'),
                  items: [
                    for (final type in DiagnosticOrderType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) _setType(value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _study,
                  decoration: const InputDecoration(
                    labelText: 'Study / test',
                    hintText: 'e.g. Chest X-ray PA and lateral',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DiagnosticOrderPriority>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: [
                    for (final priority in DiagnosticOrderPriority.values)
                      DropdownMenuItem(
                        value: priority,
                        child: Text(priority.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _priority = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _instructions,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Clinical question / instructions',
                    hintText: 'Reason for study, relevant symptoms or collection instructions',
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: medqurLine),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.route_outlined,
                          color: medqurBlue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Routes to ${_type.targetDiscipline.label}. Only a doctor can originate this order; the performing clinical-support team can complete it and upload the result.',
                          style: const TextStyle(
                            color: Color(0xFF687587),
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Place order'),
          ),
        ],
      ),
    );
  }
}
