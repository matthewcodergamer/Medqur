import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';

class NewEncounterPage extends StatefulWidget {
  const NewEncounterPage({super.key});

  @override
  State<NewEncounterPage> createState() => _NewEncounterPageState();
}

class _NewEncounterPageState extends State<NewEncounterPage> {
  final name = TextEditingController(text: 'Daniel Thompson');
  final age = TextEditingController(text: '34');
  final complaint = TextEditingController(text: 'Fever, headache and weakness');
  String identity = 'NIDS / NIC';
  String sex = 'Male';
  TriageLevel triage = TriageLevel.moderate;
  int stage = 0;

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    complaint.dispose();
    super.dispose();
  }

  Patient _patient() {
    final isEmergency = identity == 'Emergency / unknown';
    final isVisitor = identity == 'Visitor passport';
    final displayName = isEmergency || name.text.trim().isEmpty
        ? 'Unknown Patient 0142'
        : name.text.trim();
    final patientId = isEmergency
        ? 'TEMP-0142'
        : isVisitor
            ? 'VIS-804211'
            : 'MQP-804211';
    final status = isEmergency ? 'Temporary emergency identity' : isVisitor ? 'Visitor identity verified' : 'NIDS verified';

    return Patient(
      id: patientId,
      name: displayName,
      age: int.tryParse(age.text.trim()) ?? 0,
      sex: isEmergency ? 'Unknown' : sex,
      nidsStatus: status,
      chiefComplaint: complaint.text.trim().isEmpty ? 'Clinical complaint pending' : complaint.text.trim(),
      triage: triage,
      status: PatientStatus.triaged,
      waitMinutes: 0,
      vitals: const {
        'BP': '124/79',
        'Pulse': '88 bpm',
        'SpO₂': '98%',
        'Temp': '37.8 °C',
      },
      allergies: const ['No known allergies'],
      timeline: [
        '${_timeNow()} — ${isEmergency ? 'Emergency identity created' : 'Identity verified with simulated consent'}',
        '${_timeNow()} — Encounter registered and wristband issued',
        '${_timeNow()} — Triage level ${triageLabel(triage).toLowerCase()} recorded',
      ],
      medications: [],
    );
  }

  String _timeNow() {
    final now = TimeOfDay.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('New encounter', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: stage == 0 ? _registration() : _wristband(),
      ),
    );
  }

  Widget _registration() {
    return ListView(
      key: const ValueKey('registration'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Text('Identify the patient', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('For this public prototype, verification is simulated. No NIDS/NIRA service or real identity data is used.'),
        const SizedBox(height: 20),
        const SectionTitle('Identity route'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const ['NIDS / NIC', 'Visitor passport', 'Emergency / unknown'])
              ChoiceChip(
                label: Text(item),
                selected: identity == item,
                onSelected: (_) => setState(() => identity = item),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (identity != 'Emergency / unknown') ...[
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Patient name', prefixIcon: Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Age'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: sex,
                  decoration: const InputDecoration(labelText: 'Sex'),
                  items: const [
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => sex = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ] else
          const SoftCard(
            highlighted: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.emergency_rounded, color: medqurAmber),
                SizedBox(width: 12),
                Expanded(child: Text('Emergency care starts immediately. Identity can be reconciled with the verified record later.')),
              ],
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: complaint,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Chief complaint', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes_rounded)),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Triage'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final level in TriageLevel.values)
              ChoiceChip(
                avatar: CircleAvatar(radius: 6, backgroundColor: triageColor(level)),
                label: Text(triageLabel(level)),
                selected: triage == level,
                onSelected: (_) => setState(() => triage = level),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (identity == 'NIDS / NIC')
          const SoftCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: medqurGreen),
                SizedBox(width: 12),
                Expanded(child: Text('Demo flow assumes the patient consents to a minimum-data identity verification request. The clinical system does not copy the entire NIDS record.')),
              ],
            ),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => setState(() => stage = 1),
          icon: Icon(identity == 'Emergency / unknown' ? Icons.emergency_rounded : Icons.verified_rounded),
          label: Text(identity == 'Emergency / unknown' ? 'Create emergency encounter' : 'Verify demo identity & continue'),
        ),
      ],
    );
  }

  Widget _wristband() {
    final patient = _patient();
    final color = triageColor(patient.triage);
    return ListView(
      key: const ValueKey('wristband'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        const Center(child: Icon(Icons.check_circle_rounded, color: medqurGreen, size: 54)),
        const SizedBox(height: 12),
        Text('Patient registered', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(patient.nidsStatus, textAlign: TextAlign.center),
        const SizedBox(height: 26),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SoftCard(
              highlighted: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      MedqurLogo(width: 120),
                      Spacer(),
                      Text('ENCOUNTER WRISTBAND', style: TextStyle(color: Color(0xFF8793A4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const FakeQr(size: 92),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(patient.name, style: const TextStyle(color: medqurInk, fontSize: 20, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 5),
                            Text(patient.id, style: const TextStyle(color: Color(0xFF65748A), fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            StatusPill(label: triageLabel(patient.triage), color: color),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: medqurLine),
                  const SizedBox(height: 10),
                  const Text('The QR represents a random encounter token only — no diagnosis or confidential record is encoded in the wristband.', style: TextStyle(color: Color(0xFF748297), fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(patient),
          icon: const Icon(Icons.print_rounded),
          label: const Text('Print wristband & add to patient queue'),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: () => setState(() => stage = 0), child: const Text('Back to registration')),
      ],
    );
  }
}
