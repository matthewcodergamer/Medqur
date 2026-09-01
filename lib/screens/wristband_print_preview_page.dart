import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/wristband_print_service.dart';
import '../widgets/common.dart';

class WristbandPrintPreviewPage extends StatefulWidget {
  const WristbandPrintPreviewPage({
    super.key,
    required this.data,
  });

  final WristbandData data;

  @override
  State<WristbandPrintPreviewPage> createState() =>
      _WristbandPrintPreviewPageState();
}

class _WristbandPrintPreviewPageState
    extends State<WristbandPrintPreviewPage> {
  bool _busy = false;
  bool _printed = false;

  Future<void> _print() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final printed = await WristbandPrintService.print(widget.data);
      if (!mounted) return;
      setState(() => _printed = printed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            printed
                ? 'Print job handed to the system print service.'
                : 'Printing was cancelled or did not complete.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Print patient wristband',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          const SoftCard(
            highlighted: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.print_outlined, color: medqurBlue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Print System V1 uses the device/system print dialog. Choose the HP LaserJet P2035n when it is available. The same dynamic wristband data can later be sent to a Zebra healthcare printer adapter.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Wristband preview',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusPill(
                label: _printed ? 'Print sent' : 'Ready',
                color: _printed ? medqurGreen : medqurBlue,
                icon: _printed ? Icons.check_rounded : Icons.print_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: medqurLine),
            ),
            child: AspectRatio(
              aspectRatio: 4.2,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 1050,
                  height: 250,
                  child: _WristbandVisual(data: widget.data),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Print destination',
                  style: TextStyle(
                    color: medqurInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _detail('Printer', 'HP LaserJet P2035n'),
                _detail('Mode', 'Laser / prototype PDF'),
                _detail('Copies', '1'),
                _detail('Encounter', widget.data.encounterId),
                const SizedBox(height: 8),
                const Text(
                  'The system print dialog controls the actual printer selection, paper tray and scaling. For physical testing use ordinary paper or laser-compatible label/wristband stock only.',
                  style: TextStyle(
                    color: Color(0xFF748297),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _print,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_rounded),
            label: const Text('Print wristband'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _savePdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Save / share wristband PDF'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              _printed
                  ? 'Finish & add patient to queue'
                  : 'Continue to queue without printing',
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF748297),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: medqurInk,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
}

class _WristbandVisual extends StatelessWidget {
  const _WristbandVisual({required this.data});

  final WristbandData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 24,
            color: medqurBlue,
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: const Text(
                      'PATIENT IDENTIFICATION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data.patientName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _bandLine('PATIENT ID', data.patientId, strong: true),
                  _bandLine('ENCOUNTER', data.encounterId),
                  _bandLine(
                    'DOB',
                    '${data.displayDob}   |   AGE: ${data.age}   |   SEX: ${_shortSex(data.sex)}',
                  ),
                  _bandLine('FACILITY', data.facility),
                  const Spacer(),
                  Text(
                    'Printed ${data.displayPrintedAt}',
                    style: const TextStyle(
                      color: Color(0xFF5F6772),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 2, color: Colors.black),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  const Text(
                    'PATIENT CODE',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: QrImageView(
                        data: data.codeValue,
                        version: QrVersions.auto,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.encounterId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 2, color: Colors.black),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ALLERGIES',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.allergies.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CURRENT TRIAGE',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.priority,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    color: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: const Text(
                      'MEDQUR CLINICAL SYSTEM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bandLine(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 13),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortSex(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.startsWith('m')) return 'M';
    if (normalized.startsWith('f')) return 'F';
    return value.isEmpty ? 'U' : value.substring(0, 1).toUpperCase();
  }
}
