import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/signature_rendering.dart';
import '../services/signature_vault.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
import '../widgets/prescription_signature_pad.dart';

class SignatureVaultPage extends StatefulWidget {
  const SignatureVaultPage({super.key, required this.staff});

  final StaffProfile staff;

  @override
  State<SignatureVaultPage> createState() => _SignatureVaultPageState();
}

class _SignatureVaultPageState extends State<SignatureVaultPage> {
  final _vault = DoctorSignatureVault();
  final _picker = ImagePicker();
  List<StoredDoctorSignature> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final values = await _vault.load(widget.staff.id);
    if (!mounted) return;
    setState(() {
      _items = values;
      _loading = false;
    });
  }

  Future<void> _drawSignature() async {
    final value = await showModalBottomSheet<_DrawSignatureResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _DrawSignatureSheet(),
    );
    if (value == null || !mounted) return;
    try {
      final image = await SignatureImageProcessor.fromVectorPayload(
        value.signature.payload,
        ink: value.ink,
      );
      await _vault.add(
        staffId: widget.staff.id,
        label: value.label,
        source: DoctorSignatureSource.drawn,
        imageBytes: image,
        ink: value.ink,
        vectorPayload: value.signature.payload,
        makeDefault: _items.isEmpty,
      );
      await _reload();
    } on Object catch (error) {
      _message('Signature could not be saved: $error');
    }
  }

  Future<void> _photoSignature() async {
    final options = await showDialog<_PhotoSignatureOptions>(
      context: context,
      builder: (_) => const _PhotoSignatureDialog(),
    );
    if (options == null || !mounted) return;
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (photo == null || !mounted) return;

    try {
      final source = await photo.readAsBytes();
      final cleaned = await SignatureImageProcessor.fromPaperPhoto(
        source,
        ink: options.ink,
      );
      final prescriptionSafe = SignatureRendering.onWhitePaper(cleaned);
      if (!SignatureRendering.looksLikeSignature(prescriptionSafe)) {
        throw const FormatException(
          'The cleaned image still does not look like handwriting. Retake it on plain white paper with the signature filling the center of the photo.',
        );
      }
      await _vault.add(
        staffId: widget.staff.id,
        label: options.label,
        source: DoctorSignatureSource.paperPhoto,
        imageBytes: prescriptionSafe,
        ink: options.ink,
        makeDefault: _items.isEmpty,
      );
      await _reload();
    } on Object catch (error) {
      _message('The paper signature could not be cleaned: $error');
    }
  }

  Future<void> _rename(StoredDoctorSignature signature) async {
    final controller = TextEditingController(text: signature.label);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename signature'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Signature name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    await _vault.rename(widget.staff.id, signature.id, value);
    await _reload();
  }

  Future<void> _delete(StoredDoctorSignature signature) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete signature?'),
            content: Text(
              '${signature.label} will no longer be available for new prescriptions. Existing signed prescription records are not changed.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: medqurRed),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _vault.delete(widget.staff.id, signature.id);
    await _reload();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signatures')),
      body: SafeArea(
        child: MedqurPage(
          children: [
            const MedqurPageHeader(
              eyebrow: 'Prescriber profile',
              title: 'Signature vault',
              subtitle: 'Keep a small set of reusable signatures. Your default signature is selected automatically when you create a prescription.',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _drawSignature,
                    icon: const Icon(Icons.draw_rounded),
                    label: const Text('Draw signature'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _photoSignature,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Photo from paper'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_items.isEmpty)
              const _EmptySignatureState()
            else
              for (final signature in _items) ...[
                _SignatureCard(
                  signature: signature,
                  onDefault: () async {
                    await _vault.setDefault(widget.staff.id, signature.id);
                    await _reload();
                  },
                  onRename: () => _rename(signature),
                  onDelete: () => _delete(signature),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 8),
            const _SecurityNote(),
          ],
        ),
      ),
    );
  }
}

class _SignatureCard extends StatelessWidget {
  const _SignatureCard({
    required this.signature,
    required this.onDefault,
    required this.onRename,
    required this.onDelete,
  });

  final StoredDoctorSignature signature;
  final VoidCallback onDefault;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final preview = SignatureRendering.onWhitePaper(signature.imageBytes);
    final valid = SignatureRendering.looksLikeSignature(preview);
    return SoftCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 128,
            height: 64,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: medqurLine),
            ),
            child: valid
                ? Image.memory(
                    preview,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const Icon(Icons.draw_outlined),
                  )
                : const Center(
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: medqurRed,
                      size: 24,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        signature.label,
                        style: const TextStyle(
                          color: medqurInk,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (signature.isDefault)
                      const StatusPill(
                        label: 'Default',
                        color: medqurGreen,
                        icon: Icons.check_circle_outline_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  valid
                      ? '${signature.source == DoctorSignatureSource.drawn ? 'Drawn' : 'Paper photo'} • ${signature.ink.label}'
                      : 'Signature needs to be captured again',
                  style: TextStyle(
                    color: valid ? const Color(0xFF7A8798) : medqurRed,
                    fontSize: 11.5,
                    fontWeight: valid ? FontWeight.w400 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 2,
                  children: [
                    if (!signature.isDefault && valid)
                      TextButton(onPressed: onDefault, child: const Text('Make default')),
                    TextButton(onPressed: onRename, child: const Text('Rename')),
                    TextButton(
                      onPressed: onDelete,
                      style: TextButton.styleFrom(foregroundColor: medqurRed),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySignatureState extends StatelessWidget {
  const _EmptySignatureState();

  @override
  Widget build(BuildContext context) => SoftCard(
        child: Column(
          children: [
            const Icon(Icons.draw_outlined, color: medqurBlue, size: 31),
            const SizedBox(height: 10),
            Text(
              'No saved signatures',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            const Text(
              'Draw one on the device or photograph a signature written on clean white paper.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF718095), fontSize: 12.5, height: 1.35),
            ),
          ],
        ),
      );
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: medqurLine),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.security_outlined, size: 18, color: medqurNavy),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'A saved signature is a visual attestation, not the doctor’s identity by itself. Medqur still binds every prescription to the authenticated six-digit staff account, facility, time and audit record.',
                style: TextStyle(color: Color(0xFF657286), fontSize: 11.5, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class _DrawSignatureResult {
  const _DrawSignatureResult({
    required this.label,
    required this.ink,
    required this.signature,
  });
  final String label;
  final PrescriptionInk ink;
  final PrescriptionSignature signature;
}

class _DrawSignatureSheet extends StatefulWidget {
  const _DrawSignatureSheet();

  @override
  State<_DrawSignatureSheet> createState() => _DrawSignatureSheetState();
}

class _DrawSignatureSheetState extends State<_DrawSignatureSheet> {
  final _label = TextEditingController(text: 'Primary signature');
  final _padKey = GlobalKey<PrescriptionSignaturePadState>();
  PrescriptionInk _ink = PrescriptionInk.blue;
  bool _ready = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _save() {
    final signature = _padKey.currentState?.buildSignature();
    if (signature == null) return;
    Navigator.pop(
      context,
      _DrawSignatureResult(
        label: _label.text.trim(),
        ink: _ink,
        signature: signature,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          8,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Draw signature', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              const Text(
                'Use a finger or stylus. The strokes are stored as reusable signature artwork.',
                style: TextStyle(color: Color(0xFF718095), fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _label,
                decoration: const InputDecoration(labelText: 'Signature name'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<PrescriptionInk>(
                segments: const [
                  ButtonSegment(value: PrescriptionInk.blue, label: Text('Blue pen')),
                  ButtonSegment(value: PrescriptionInk.black, label: Text('Black pen')),
                ],
                selected: {_ink},
                onSelectionChanged: (value) => setState(() => _ink = value.first),
              ),
              const SizedBox(height: 14),
              PrescriptionSignaturePad(
                key: _padKey,
                height: 190,
                onChanged: (value) => setState(() => _ready = value),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      _padKey.currentState?.clear();
                      setState(() => _ready = false);
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _ready ? _save : null,
                    child: const Text('Save signature'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _PhotoSignatureOptions {
  const _PhotoSignatureOptions(this.label, this.ink);
  final String label;
  final PrescriptionInk ink;
}

class _PhotoSignatureDialog extends StatefulWidget {
  const _PhotoSignatureDialog();

  @override
  State<_PhotoSignatureDialog> createState() => _PhotoSignatureDialogState();
}

class _PhotoSignatureDialogState extends State<_PhotoSignatureDialog> {
  final _label = TextEditingController(text: 'Paper signature');
  PrescriptionInk _ink = PrescriptionInk.blue;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Photograph signature'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Write the signature on plain white paper in good light. Medqur isolates and crops the pen strokes, then normalizes the paper to pure white so it blends into the white prescription form instead of appearing as a dark block.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Signature name'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<PrescriptionInk>(
              segments: const [
                ButtonSegment(value: PrescriptionInk.blue, label: Text('Blue')),
                ButtonSegment(value: PrescriptionInk.black, label: Text('Black')),
              ],
              selected: {_ink},
              onSelectionChanged: (value) => setState(() => _ink = value.first),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _PhotoSignatureOptions(_label.text.trim(), _ink),
            ),
            child: const Text('Open camera'),
          ),
        ],
      );
}
