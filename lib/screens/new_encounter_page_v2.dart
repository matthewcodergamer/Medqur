import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'live_scanner_page.dart';

class NewEncounterPageV2 extends StatefulWidget {
  const NewEncounterPageV2({super.key});

  @override
  State<NewEncounterPageV2> createState() => _NewEncounterPageV2State();
}

class _NewEncounterPageV2State extends State<NewEncounterPageV2> {
  final name = TextEditingController(text: 'Daniel Thompson');
  final age = TextEditingController(text: '34');
  final complaint = TextEditingController(text: 'Fever, headache and weakness');
  String identity = 'NIDS / NIC';
  String sex = 'Male';
  TriageLevel triage = TriageLevel.moderate;
  String? capturedCredential;
  int stage = 0;

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    complaint.dispose();
    super.dispose();
  }

  Future<void> _scanIdentity() async {
    final capture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(builder: (_) => const LiveScannerPage(purpose: ScanPurpose.nidsCard)),
    );
    if (capture == null || !mounted) return;
    setState(() => capturedCredential = capture.value);
  }

  String _shortId() =>
      (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0');

  Patient _patient() {
    final emergency = identity == 'Emergency / unknown';
    final visitor = identity == 'Visitor passport';
    final suffix = _shortId();
    return Patient(
      id: emergency ? 'TEMP-$suffix' : visitor ? 'VIS-$suffix' : 'MQP-$suffix',
      name: emergency || name.text.trim().isEmpty
          ? 'Unknown Patient $suffix'
          : name.text.trim(),
      age: emergency ? 0 : int.tryParse(age.text.trim()) ?? 0,
      sex: emergency ? 'Unknown' : sex,
      nidsStatus: emergency
          ? 'Temporary emergency identity'
          : visitor
              ? 'Visitor credential captured'
              : capturedCredential == null
                  ? 'NIDS verification pending'
                  : 'NIDS credential captured',
      chiefComplaint: complaint.text.trim().isEmpty
          ? 'Clinical complaint pending'
          : complaint.text.trim(),
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
        '${_timeNow()} — ${emergency ? 'Emergency identity created' : 'Encounter registration started'}',
        if (capturedCredential != null)
          '${_timeNow()} — Identity credential scanned; authoritative verification still pending',
        '${_timeNow()} — ${triageCode(triage)} (${triageName(triage)}) triage recorded',
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
        duration: const Duration(milliseconds: 240),
        child: stage == 0 ? _registration() : _wristband(),
      ),
    );
  }

  Widget _registration() {
    return ListView(
      key: const ValueKey('registration-v3'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Text('Identify patient', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const ['NIDS / NIC', 'Visitor passport', 'Emergency / unknown'])
              ChoiceChip(
                label: Text(item),
                selected: identity == item,
                onSelected: (_) => setState(() {
                  identity = item;
                  capturedCredential = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (identity == 'NIDS / NIC') ...[
          OutlinedButton.icon(
            onPressed: _scanIdentity,
            icon: const Icon(Icons.badge_outlined),
            label: Text(capturedCredential == null
                ? 'Scan NIDS / NIC'
                : 'Credential captured • scan again'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Scanning captures the credential only. NIRA identity verification is not connected to this public prototype.',
            style: TextStyle(color: Color(0xFF748297), fontSize: 12),
          ),
          const SizedBox(height: 14),
        ],
        if (identity != 'Emergency / unknown') ...[
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Patient name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
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
                initialValue: sex,
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
          ]),
          const SizedBox(height: 12),
        ] else
          const SoftCard(
            highlighted: true,
            child: Row(children: [
              Icon(Icons.emergency_rounded, color: medqurAmber),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Emergency care can start immediately; identity can be reconciled later.',
                ),
              ),
            ]),
          ),
        TextField(
          controller: complaint,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Chief complaint',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Emergency triage priority'),
        const SizedBox(height: 6),
        const Text(
          'Select the P1–P4 level after clinical assessment. P1 is the highest emergency priority.',
          style: TextStyle(color: Color(0xFF748297), fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 12),
        for (final level in TriageLevel.values) ...[
          _TriageOption(
            level: level,
            selected: triage == level,
            onTap: () => setState(() => triage = level),
          ),
          const SizedBox(height: 10),
        ],
        if (triageBypassesRoutineWaiting(triage)) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: triageColor(triage).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: triageColor(triage).withValues(alpha: .30)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.priority_high_rounded, color: triageColor(triage)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  triage == TriageLevel.critical
                      ? 'P1 selected — do not place this patient in the routine waiting queue. Route directly for immediate resuscitation/life-saving intervention.'
                      : 'P2 selected — rapid medical assessment and urgent treatment are required. Route to the priority treatment area.',
                  style: TextStyle(
                    color: triageColor(triage),
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: () => setState(() => stage = 1),
          icon: Icon(identity == 'Emergency / unknown'
              ? Icons.emergency_rounded
              : Icons.arrow_forward_rounded),
          label: Text(identity == 'Emergency / unknown'
              ? 'Create emergency encounter'
              : 'Continue to wristband'),
        ),
      ],
    );
  }

  Widget _wristband() {
    final patient = _patient();
    return ListView(
      key: const ValueKey('wristband-v3'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        const Center(child: Icon(Icons.check_circle_rounded, color: medqurGreen, size: 52)),
        const SizedBox(height: 10),
        Text(
          'Encounter ready',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 22),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SoftCard(
              highlighted: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  MedqurLogo(width: 118),
                  Spacer(),
                  Text(
                    'ENCOUNTER WRISTBAND',
                    style: TextStyle(
                      color: Color(0xFF8793A4),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  FakeQr(size: 104, data: patient.encounterToken),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: const TextStyle(
                            color: medqurInk,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          patient.id,
                          style: const TextStyle(
                            color: Color(0xFF65748A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        StatusPill(
                          label: triageLabel(patient.triage),
                          color: triageColor(patient.triage),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          triageAction(patient.triage),
                          style: TextStyle(
                            color: triageColor(patient.triage),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                const Divider(color: medqurLine),
                const SizedBox(height: 8),
                const Text(
                  'The QR contains only an opaque encounter token, not diagnoses or confidential clinical data.',
                  style: TextStyle(color: Color(0xFF748297), fontSize: 12),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(patient),
          icon: const Icon(Icons.print_rounded),
          label: const Text('Print wristband & add to queue'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => setState(() => stage = 0), child: const Text('Back')),
      ],
    );
  }
}

class _TriageOption extends StatelessWidget {
  const _TriageOption({required this.level, required this.selected, required this.onTap});

  final TriageLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = triageColor(level);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .07) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : medqurLine,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                triageCode(level),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      triageName(level),
                      style: const TextStyle(
                        color: medqurInk,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded, color: color, size: 20),
                ]),
                const SizedBox(height: 4),
                Text(
                  triageDescription(level),
                  style: const TextStyle(color: Color(0xFF65748A), fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 6),
                Text(
                  triageAction(level),
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
