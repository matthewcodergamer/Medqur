import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/wristband_print_service.dart';
import '../widgets/common.dart';
import 'live_scanner_page.dart';

class WristbandPrintPreviewPage extends StatefulWidget {
  const WristbandPrintPreviewPage({super.key, required this.data});
  final WristbandData data;

  @override
  State<WristbandPrintPreviewPage> createState() => _WristbandPrintPreviewPageState();
}

class _WristbandPrintPreviewPageState extends State<WristbandPrintPreviewPage> {
  bool _busy = false;
  bool _printed = false;
  bool _wristbandVerified = false;

  Future<void> _print() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final printed = await WristbandPrintService.print(widget.data);
      if (!mounted) return;
      setState(() {
        _printed = printed;
        if (!printed) _wristbandVerified = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(printed
            ? 'Print job sent. Scan the physical wristband before the patient can be registered.'
            : 'Printing was cancelled or did not complete.'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyPrintedBand() async {
    if (!_printed || _busy) return;
    final capture = await Navigator.of(context).push<ScanCapture>(
      MaterialPageRoute(
        builder: (_) => const LiveScannerPage(purpose: ScanPurpose.patientWristband),
      ),
    );
    if (capture == null || !mounted) return;
    final expected = widget.data.codeValue.trim();
    final actual = capture.value.trim();
    final matches = actual == expected || actual == widget.data.encounterId;
    setState(() => _wristbandVerified = matches);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(matches
          ? 'Physical wristband verified. Registration can now be completed.'
          : 'That code does not match this encounter. Scan the wristband that was just printed.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _savePdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await WristbandPrintService.saveOrShare(widget.data);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canFinish = _printed && _wristbandVerified;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Print patient wristband', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          SoftCard(
            highlighted: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(canFinish ? Icons.verified_rounded : Icons.shield_outlined, color: canFinish ? medqurGreen : medqurBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  canFinish
                      ? 'Wristband requirement satisfied: the print step completed and the physical wristband QR was scanned back successfully.'
                      : 'Registration is locked until a wristband is printed and that physical wristband is scanned back into Medqur. Saving a PDF or leaving this screen does not register the patient.',
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: Text('Wristband preview', style: Theme.of(context).textTheme.titleLarge)),
            StatusPill(
              label: canFinish ? 'Verified' : _printed ? 'Needs scan-back' : 'Not printed',
              color: canFinish ? medqurGreen : _printed ? medqurAmber : medqurBlue,
              icon: canFinish ? Icons.check_rounded : _printed ? Icons.qr_code_scanner_rounded : Icons.print_rounded,
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: medqurLine),
            ),
            child: Row(children: [
              SizedBox(
                width: 116,
                height: 116,
                child: QrImageView(
                  data: widget.data.codeValue,
                  version: QrVersions.auto,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                  padding: const EdgeInsets.all(8),
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.data.patientName.toUpperCase(), style: const TextStyle(color: medqurInk, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('Patient ${widget.data.patientId}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('Encounter ${widget.data.encounterId}'),
                  Text('DOB ${widget.data.displayDob} • ${widget.data.sex}'),
                  const SizedBox(height: 6),
                  Text('Allergies: ${widget.data.allergies}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('Priority: ${widget.data.priority}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _print,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print_rounded),
            label: Text(_printed ? 'Print wristband again' : 'Print wristband'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _printed && !_busy ? _verifyPrintedBand : null,
            icon: Icon(_wristbandVerified ? Icons.verified_rounded : Icons.qr_code_scanner_rounded),
            label: Text(_wristbandVerified ? 'Physical wristband verified' : 'Scan printed wristband to verify'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _savePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Save / share wristband PDF'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canFinish ? () => Navigator.of(context).pop(true) : null,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Finish & add patient to queue'),
          ),
          if (!canFinish) ...[
            const SizedBox(height: 8),
            const Text(
              'Finish remains disabled until both safeguards pass. This prevents the previous path where a patient could be added without a verified wristband.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF748297), fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
