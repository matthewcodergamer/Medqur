import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/prescription_document.dart';
import '../services/signature_vault.dart';
import '../widgets/common.dart';
import '../widgets/prescription_form_preview.dart';

class PrescriptionPrintPreviewPage extends StatefulWidget {
  const PrescriptionPrintPreviewPage({
    super.key,
    required this.data,
  });

  final PrescriptionPrintData data;

  @override
  State<PrescriptionPrintPreviewPage> createState() =>
      _PrescriptionPrintPreviewPageState();
}

class _PrescriptionPrintPreviewPageState
    extends State<PrescriptionPrintPreviewPage> {
  bool _busy = false;

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      await Printing.layoutPdf(
        name: 'Medqur prescription ${widget.data.copyNumber}',
        onLayout: (_) => PrescriptionDocumentService.build(widget.data),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bytes = await PrescriptionDocumentService.build(widget.data);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'medqur-prescription-${widget.data.copyNumber}.pdf',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prescription preview')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Row(
              children: [
                const Icon(Icons.verified_outlined, color: medqurGreen, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Signed by ${widget.data.staff.name}',
                    style: const TextStyle(
                      color: medqurInk,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  widget.data.ink.label,
                  style: const TextStyle(
                    color: Color(0xFF7A8798),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PrescriptionFormPreview(data: widget.data),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _print,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print prescription'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _share,
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Save / share PDF'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Done'),
            ),
            const SizedBox(height: 8),
            const Text(
              'The print output uses the SRHA / Mandeville Regional Hospital form supplied for this prototype. Patient and prescriber fields are typed for clarity; medication directions use a restrained digital-pen style.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7A8798),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
