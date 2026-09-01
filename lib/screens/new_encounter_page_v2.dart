import 'package:flutter/material.dart';

import '../models.dart';
import '../services/nids_test_credential.dart';
import '../services/wristband_print_service.dart';
import '../widgets/common.dart';
import 'id_front_capture_page.dart';
import 'live_scanner_page.dart';
import 'wristband_print_preview_page.dart';

class NewEncounterPageV2 extends StatefulWidget {
  const NewEncounterPageV2({
    super.key,
    required this.facility,
    required this.existingPatients,
  });

  final Facility facility;
  final List<Patient> existingPatients;

  @override
  State<NewEncounterPageV2> createState() => _NewEncounterPageV2State();
}

class _NewEncounterPageV2State extends State<NewEncounterPageV2> {
  final name = TextEditingController(text: 'Daniel Thompson');
  final age = TextEditingController(text: '34');
  final complaint = TextEditingController(text: 'Fever, headache and weakness');
  final allergies = TextEditingController(text: 'NKDA');

  String identity = 'NIDS / NIC';
  String sex = 'Male';
  TriageLevel triage = TriageLevel.moderate;
  String? capturedCredential;
  NidsTestCredential? nidsTestCredential;
  IdFrontCaptureResult? frontCapture;
  Patient? _draftPatient;
  int stage = 0;

  bool get frontVerified => frontCapture != null;

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    complaint.dispose();
    allergies.dispose();
    super.dispose();
  }

  Future<void> _scanIdentityBack() async {
    final capture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(
        builder: (_) => const LiveScannerPage(purpose: ScanPurpose.nidsCard),
      ),
    );
    if (capture == null || !mounted) return;
    final parsed = NidsTestCredential.tryParse(capture.value);
    if (parsed != null) {
      name.text = parsed.fullName;
      age.text = NidsTestCredential.ageFromIsoDate(parsed.dateOfBirth).toString();
    }
    setState(() {
      capturedCredential = capture.value;
      nidsTestCredential = parsed;
      frontCapture = null;
      _draftPatient = null;
    });
  }

  Future<void> _verifyIdentityFront() async {
    final credential = nidsTestCredential;
    if (credential == null) return;
    final captured = await Navigator.of(context).push<IdFrontCaptureResult>(
      MaterialPageRoute(
        builder: (_) => IdFrontCapturePage(
          expectedName: credential.fullName,
          expectedId: credential.nationalIdNumber,
        ),
      ),
    );
    if (!mounted || captured == null) return;
    setState(() {
      frontCapture = captured;
      _draftPatient = null;
    });
  }

  String _shortId(DateTime now) =>
      (now.microsecondsSinceEpoch % 1000000).toString().padLeft(6, '0');

  Patient? _existingNidsPatient() {
    final nin = nidsTestCredential?.nationalIdNumber;
    if (nin == null || nin.isEmpty) return null;
    for (final patient in widget.existingPatients) {
      if (patient.nationalIdNumber == nin) return patient;
    }
    return null;
  }

  List<String> _allergyList() {
    final value = allergies.text.trim();
    if (value.isEmpty || value.toUpperCase() == 'NKDA') {
      return const ['No known allergies'];
    }
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  bool get _identityReady {
    if (identity != 'NIDS / NIC') return true;
    return nidsTestCredential != null && frontVerified;
  }

  Patient _buildPatient() {
    final emergency = identity == 'Emergency / unknown';
    final visitor = identity == 'Visitor passport';
    final now = DateTime.now();
    final suffix = _shortId(now);
    final existing = _existingNidsPatient();
    final patientId = existing?.id ??
        (emergency
            ? 'TEMP-${now.year}-$suffix'
            : visitor
                ? 'VIS-${now.year}-$suffix'
                : 'PAT-${now.year}-$suffix');
    final encounterId =
        'ENC-${now.year}-${now.month.toString().padLeft(2, '0')}-$suffix';

    return Patient(
      id: patientId,
      encounterId: encounterId,
      facilityName: widget.facility.name,
      name: emergency || name.text.trim().isEmpty
          ? 'Unknown Patient $suffix'
          : name.text.trim(),
      age: emergency ? 0 : int.tryParse(age.text.trim()) ?? 0,
      sex: emergency ? 'Unknown' : sex,
      nidsStatus: emergency
          ? 'Temporary emergency identity'
          : visitor
              ? 'Visitor credential captured'
              : frontVerified
                  ? 'Medqur NIDS TEST back code + front card photo captured • not NIRA verified'
                  : 'NIDS verification pending',
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
      allergies: _allergyList(),
      timeline: [
        '${_timeNow()} — ${emergency ? 'Emergency identity created' : 'Encounter registration started'}',
        '${_timeNow()} — Encounter $encounterId created at ${widget.facility.name}',
        if (existing != null)
          '${_timeNow()} — Existing Medqur patient ID ${existing.id} reused',
        if (nidsTestCredential != null)
          '${_timeNow()} — Back-of-card Medqur NIDS TEST code decoded',
        if (frontVerified)
          '${_timeNow()} — Front-of-card image captured and accepted for the front/back review step; no typed transcription used',
        '${_timeNow()} — ${triageCode(triage)} (${triageName(triage)}) triage recorded',
      ],
      medications: [],
      dateOfBirth: nidsTestCredential?.dateOfBirth,
      nationalIdNumber: nidsTestCredential?.nationalIdNumber,
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
        title: const Text(
          'New encounter',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: stage == 0 ? _registration() : _wristband(),
      ),
    );
  }

  Widget _registration() {
    return ListView(
      key: const ValueKey('registration-v8'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Text('Identify patient', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              'NIDS / NIC',
              'Visitor passport',
              'Emergency / unknown',
            ])
              ChoiceChip(
                label: Text(item),
                selected: identity == item,
                onSelected: (_) => setState(() {
                  identity = item;
                  capturedCredential = null;
                  nidsTestCredential = null;
                  frontCapture = null;
                  _draftPatient = null;
                }),
              ),
          ],
        ),
        if (identity == 'NIDS / NIC') ...[
          const SizedBox(height: 18),
          const SectionTitle('Two-sided identity check'),
          const SizedBox(height: 8),
          const Text(
            'Step 1 scans the back QR while the whole card is lined up. Step 2 photographs the entire front using a portrait-and-text overlay. There are no name or ID typing boxes.',
            style: TextStyle(
              color: Color(0xFF65748A),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _scanIdentityBack,
            icon: Icon(
              nidsTestCredential != null
                  ? Icons.check_circle_rounded
                  : Icons.qr_code_scanner_rounded,
            ),
            label: Text(
              nidsTestCredential != null
                  ? 'Back card scanned • scan again'
                  : 'Step 1 — scan back of card',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: nidsTestCredential == null ? null : _verifyIdentityFront,
            icon: Icon(
              frontVerified
                  ? Icons.check_circle_rounded
                  : Icons.camera_alt_outlined,
            ),
            label: Text(
              frontVerified
                  ? 'Front photo captured • retake'
                  : 'Step 2 — photograph front of ID',
            ),
          ),
          const SizedBox(height: 10),
          SoftCard(
            highlighted: _identityReady,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _identityReady ? Icons.verified_rounded : Icons.shield_outlined,
                  color: _identityReady ? medqurGreen : medqurAmber,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _identityReady
                        ? 'Back code and front-card photo are both captured. The encounter can continue to the required wristband step.'
                        : nidsTestCredential == null
                            ? 'Back-of-card QR scan is still required.'
                            : 'Back QR decoded. A front-card photo is still required.',
                    style: TextStyle(
                      color: _identityReady ? medqurGreen : medqurInk,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (nidsTestCredential != null) ...[
            const SizedBox(height: 8),
            Text(
              '${nidsTestCredential!.fullName} • DOB ${nidsTestCredential!.dateOfBirth} • ${nidsTestCredential!.nationalIdNumber}',
              style: const TextStyle(
                color: Color(0xFF65748A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
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
            ],
          ),
          const SizedBox(height: 12),
        ] else
          const SoftCard(
            highlighted: true,
            child: Row(
              children: [
                Icon(Icons.emergency_rounded, color: medqurAmber),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Emergency care can start immediately; identity can be reconciled later. A wristband is still required before the encounter is added to the queue.',
                  ),
                ),
              ],
            ),
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
        const SizedBox(height: 12),
        TextField(
          controller: allergies,
          decoration: const InputDecoration(
            labelText: 'Allergies',
            hintText: 'NKDA or comma-separated allergies',
            prefixIcon: Icon(Icons.warning_amber_rounded),
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Emergency triage priority'),
        const SizedBox(height: 10),
        for (final level in TriageLevel.values) ...[
          _TriageOption(
            level: level,
            selected: triage == level,
            onTap: () => setState(() => triage = level),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _identityReady
              ? () {
                  final patient = _buildPatient();
                  setState(() {
                    _draftPatient = patient;
                    stage = 1;
                  });
                }
              : null,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(
            identity == 'Emergency / unknown'
                ? 'Continue to required wristband'
                : 'Continue to wristband',
          ),
        ),
      ],
    );
  }

  Future<void> _openPrintPreview(Patient patient) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WristbandPrintPreviewPage(
          data: WristbandData.fromPatient(
            patient,
            facilityName: widget.facility.name,
          ),
        ),
      ),
    );
    if (completed == true && mounted) Navigator.of(context).pop(patient);
  }

  Widget _wristband() {
    final patient = _draftPatient ?? _buildPatient();
    final wristband = WristbandData.fromPatient(
      patient,
      facilityName: widget.facility.name,
    );
    return ListView(
      key: const ValueKey('wristband-v8'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        const Center(
          child: Icon(Icons.print_rounded, color: medqurBlue, size: 52),
        ),
        const SizedBox(height: 10),
        Text(
          'Wristband required',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'The patient is not registered yet. Print the wristband and scan that physical wristband back successfully to unlock queue registration.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF65748A), height: 1.4),
        ),
        const SizedBox(height: 20),
        SoftCard(
          highlighted: true,
          child: Row(
            children: [
              FakeQr(size: 96, data: patient.encounterToken),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wristband.patientName,
                      style: const TextStyle(
                        color: medqurInk,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${patient.id} • ${patient.effectiveEncounterId}',
                      style: const TextStyle(
                        color: Color(0xFF65748A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Allergies: ${wristband.allergies}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Priority: ${wristband.priority}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => _openPrintPreview(patient),
          icon: const Icon(Icons.print_rounded),
          label: const Text('Review, print & verify wristband'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            stage = 0;
            _draftPatient = null;
          }),
          child: const Text('Back'),
        ),
      ],
    );
  }
}

class _TriageOption extends StatelessWidget {
  const _TriageOption({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final TriageLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = triageColor(level);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .07) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : medqurLine,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${triageName(level)} — ${triageLabel(level)}',
                    style: const TextStyle(
                      color: medqurInk,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    triageDescription(level),
                    style: const TextStyle(
                      color: Color(0xFF65748A),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
