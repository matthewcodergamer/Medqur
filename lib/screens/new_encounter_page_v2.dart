import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models.dart';
import '../services/nids_test_credential.dart';
import '../services/wristband_print_service.dart';
import '../widgets/common.dart';
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
  bool frontVerified = false;
  Patient? _draftPatient;
  int stage = 0;

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
      MaterialPageRoute(builder: (_) => const LiveScannerPage(purpose: ScanPurpose.nidsCard)),
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
      frontVerified = false;
      _draftPatient = null;
    });
  }

  Future<void> _verifyIdentityFront() async {
    final credential = nidsTestCredential;
    if (credential == null) return;
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _FrontIdReviewPage(
          expectedName: credential.fullName,
          expectedId: credential.nationalIdNumber,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => frontVerified = verified == true);
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
    if (value.isEmpty || value.toUpperCase() == 'NKDA') return const ['No known allergies'];
    return value.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
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
        (emergency ? 'TEMP-${now.year}-$suffix' : visitor ? 'VIS-${now.year}-$suffix' : 'PAT-${now.year}-$suffix');
    final encounterId = 'ENC-${now.year}-${now.month.toString().padLeft(2, '0')}-$suffix';

    return Patient(
      id: patientId,
      encounterId: encounterId,
      facilityName: widget.facility.name,
      name: emergency || name.text.trim().isEmpty ? 'Unknown Patient $suffix' : name.text.trim(),
      age: emergency ? 0 : int.tryParse(age.text.trim()) ?? 0,
      sex: emergency ? 'Unknown' : sex,
      nidsStatus: emergency
          ? 'Temporary emergency identity'
          : visitor
              ? 'Visitor credential captured'
              : frontVerified
                  ? 'Medqur NIDS TEST back code + front visual/text cross-check completed • not NIRA verified'
                  : 'NIDS verification pending',
      chiefComplaint: complaint.text.trim().isEmpty ? 'Clinical complaint pending' : complaint.text.trim(),
      triage: triage,
      status: PatientStatus.triaged,
      waitMinutes: 0,
      vitals: const {'BP': '124/79', 'Pulse': '88 bpm', 'SpO₂': '98%', 'Temp': '37.8 °C'},
      allergies: _allergyList(),
      timeline: [
        '${_timeNow()} — ${emergency ? 'Emergency identity created' : 'Encounter registration started'}',
        '${_timeNow()} — Encounter $encounterId created at ${widget.facility.name}',
        if (existing != null) '${_timeNow()} — Existing Medqur patient ID ${existing.id} reused',
        if (nidsTestCredential != null) '${_timeNow()} — Back-of-card Medqur NIDS TEST code decoded',
        if (frontVerified) '${_timeNow()} — Front-of-card portrait presence and transcribed name/ID cross-check passed',
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
      key: const ValueKey('registration-v7'),
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
                  nidsTestCredential = null;
                  frontVerified = false;
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
            '1. Scan the back code. 2. Show the front to the camera and cross-check the visible portrait, name and ID number. Both steps are required before wristband printing.',
            style: TextStyle(color: Color(0xFF65748A), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _scanIdentityBack,
            icon: Icon(nidsTestCredential != null ? Icons.check_circle_rounded : Icons.qr_code_scanner_rounded),
            label: Text(nidsTestCredential != null ? 'Back code captured • scan again' : 'Step 1 — scan back code'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: nidsTestCredential == null ? null : _verifyIdentityFront,
            icon: Icon(frontVerified ? Icons.verified_user_rounded : Icons.badge_outlined),
            label: Text(frontVerified ? 'Front cross-check passed' : 'Step 2 — verify front of ID'),
          ),
          const SizedBox(height: 10),
          SoftCard(
            highlighted: _identityReady,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_identityReady ? Icons.verified_rounded : Icons.shield_outlined, color: _identityReady ? medqurGreen : medqurAmber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _identityReady
                      ? 'Both sides cross-check successfully. The prototype can continue to the wristband requirement.'
                      : nidsTestCredential == null
                          ? 'Back-of-card code is still required.'
                          : 'Back code decoded. Front-of-card cross-check is still required.',
                  style: TextStyle(color: _identityReady ? medqurGreen : medqurInk, fontWeight: FontWeight.w800, height: 1.35),
                ),
              ),
            ]),
          ),
          if (nidsTestCredential != null) ...[
            const SizedBox(height: 8),
            Text(
              '${nidsTestCredential!.fullName} • DOB ${nidsTestCredential!.dateOfBirth} • ${nidsTestCredential!.nationalIdNumber}',
              style: const TextStyle(color: Color(0xFF65748A), fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ],
        const SizedBox(height: 16),
        if (identity != 'Emergency / unknown') ...[
          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Patient name', prefixIcon: Icon(Icons.person_outline_rounded))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age'))),
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
                onChanged: (value) { if (value != null) setState(() => sex = value); },
              ),
            ),
          ]),
          const SizedBox(height: 12),
        ] else
          const SoftCard(highlighted: true, child: Row(children: [Icon(Icons.emergency_rounded, color: medqurAmber), SizedBox(width: 12), Expanded(child: Text('Emergency care can start immediately; identity can be reconciled later. A wristband is still required before the encounter is added to the queue.'))])),
        TextField(controller: complaint, maxLines: 3, decoration: const InputDecoration(labelText: 'Chief complaint', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes_rounded))),
        const SizedBox(height: 12),
        TextField(controller: allergies, decoration: const InputDecoration(labelText: 'Allergies', hintText: 'NKDA or comma-separated allergies', prefixIcon: Icon(Icons.warning_amber_rounded))),
        const SizedBox(height: 20),
        const SectionTitle('Emergency triage priority'),
        const SizedBox(height: 10),
        for (final level in TriageLevel.values) ...[
          _TriageOption(level: level, selected: triage == level, onTap: () => setState(() => triage = level)),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _identityReady
              ? () {
                  final patient = _buildPatient();
                  setState(() { _draftPatient = patient; stage = 1; });
                }
              : null,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(identity == 'Emergency / unknown' ? 'Continue to required wristband' : 'Continue to wristband'),
        ),
      ],
    );
  }

  Future<void> _openPrintPreview(Patient patient) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WristbandPrintPreviewPage(
          data: WristbandData.fromPatient(patient, facilityName: widget.facility.name),
        ),
      ),
    );
    if (completed == true && mounted) Navigator.of(context).pop(patient);
  }

  Widget _wristband() {
    final patient = _draftPatient ?? _buildPatient();
    final wristband = WristbandData.fromPatient(patient, facilityName: widget.facility.name);
    return ListView(
      key: const ValueKey('wristband-v7'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        const Center(child: Icon(Icons.print_rounded, color: medqurBlue, size: 52)),
        const SizedBox(height: 10),
        Text('Wristband required', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'The patient is not registered yet. Print the wristband and scan that physical wristband back successfully to unlock queue registration.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF65748A), height: 1.4),
        ),
        const SizedBox(height: 20),
        SoftCard(
          highlighted: true,
          child: Row(children: [
            FakeQr(size: 96, data: patient.encounterToken),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(wristband.patientName, style: const TextStyle(color: medqurInk, fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text('${patient.id} • ${patient.effectiveEncounterId}', style: const TextStyle(color: Color(0xFF65748A), fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text('Allergies: ${wristband.allergies}', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('Priority: ${wristband.priority}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: () => _openPrintPreview(patient), icon: const Icon(Icons.print_rounded), label: const Text('Review, print & verify wristband')),
        const SizedBox(height: 8),
        TextButton(onPressed: () => setState(() { stage = 0; _draftPatient = null; }), child: const Text('Back')),
      ],
    );
  }
}

class _FrontIdReviewPage extends StatefulWidget {
  const _FrontIdReviewPage({required this.expectedName, required this.expectedId});
  final String expectedName;
  final String expectedId;

  @override
  State<_FrontIdReviewPage> createState() => _FrontIdReviewPageState();
}

class _FrontIdReviewPageState extends State<_FrontIdReviewPage> {
  late final MobileScannerController _camera;
  final _frontName = TextEditingController();
  final _frontId = TextEditingController();
  bool _portraitVisible = false;

  @override
  void initState() {
    super.initState();
    _camera = MobileScannerController(facing: CameraFacing.back, detectionSpeed: DetectionSpeed.normal);
  }

  @override
  void dispose() {
    unawaited(_camera.dispose());
    _frontName.dispose();
    _frontId.dispose();
    super.dispose();
  }

  String _normalize(String value) => value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  bool get _nameMatches => _normalize(_frontName.text) == _normalize(widget.expectedName);
  bool get _idMatches => _normalize(_frontId.text) == _normalize(widget.expectedId);
  bool get _ready => _portraitVisible && _nameMatches && _idMatches;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Verify front of ID', style: TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              MobileScanner(controller: _camera, onDetect: (_) {}, tapToFocus: true, fit: BoxFit.cover),
              IgnorePointer(
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: .90,
                    child: AspectRatio(
                      aspectRatio: 85.60 / 53.98,
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF6EA2FF), width: 3), borderRadius: BorderRadius.circular(20)),
                        child: const Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Text('FRONT • KEEP PORTRAIT + TEXT CLEAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(children: [
              const Text(
                'Cross-check the front against the decoded back. This prototype uses camera-assisted visual review plus exact normalized text matching; it does not claim biometric liveness or NIRA verification.',
                style: TextStyle(color: Color(0xFF65748A), fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _frontName,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Type the name visible on the front',
                  suffixIcon: Icon(_nameMatches ? Icons.check_circle_rounded : Icons.compare_arrows_rounded, color: _nameMatches ? medqurGreen : null),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _frontId,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Type the ID/NIN visible on the front',
                  suffixIcon: Icon(_idMatches ? Icons.check_circle_rounded : Icons.compare_arrows_rounded, color: _idMatches ? medqurGreen : null),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _portraitVisible,
                onChanged: (value) => setState(() => _portraitVisible = value == true),
                title: const Text('A clear portrait/photo is visibly present on the front of the card'),
                subtitle: const Text('This is a presence check, not automated face recognition.'),
              ),
              FilledButton.icon(
                onPressed: _ready ? () => Navigator.of(context).pop(true) : null,
                icon: const Icon(Icons.verified_user_rounded),
                label: const Text('Confirm front/back match'),
              ),
            ]),
          ),
        ]),
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .07) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : medqurLine, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
            child: Text(triageCode(level), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${triageName(level)} — ${triageLabel(level)}', style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 4),
            Text(triageDescription(level), style: const TextStyle(color: Color(0xFF65748A), fontSize: 12, height: 1.35)),
          ])),
          if (selected) Icon(Icons.check_circle_rounded, color: color, size: 20),
        ]),
      ),
    );
  }
}
