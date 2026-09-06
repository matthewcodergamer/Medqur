import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/signature_rendering.dart';
import '../services/signature_vault.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
import '../widgets/medqur_responsive.dart';
import '../widgets/prescription_signature_pad.dart';

/// Blue-only prescriber signature vault.
///
/// The earlier blue/black controls are intentionally removed. Doctors can draw
/// on the device or photograph handwriting on clean white paper; both paths are
/// normalized to Medqur prescription blue before use.
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
        ink: PrescriptionInk.blue,
      );
      await _vault.add(
        staffId: widget.staff.id,
        label: value.label,
        source: DoctorSignatureSource.drawn,
        imageBytes: image,
        ink: PrescriptionInk.blue,
        vectorPayload: value.signature.payload,
        makeDefault: _items.isEmpty,
      );
      await _reload();
    } on Object catch (error) {
      _message('Signature could not be saved: $error');
    }
  }

  Future<void> _photoSignature() async {
    final label = await _photoOptions();
    if (label == null || !mounted) return;

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
        ink: PrescriptionInk.blue,
      );
      final prescriptionSafe =
          SignatureRendering.blueInkOnWhitePaper(cleaned);
      if (!SignatureRendering.looksLikeSignature(prescriptionSafe)) {
        throw const FormatException(
          'The handwriting could not be isolated clearly. Retake the photo on plain white paper with the signature centered and well lit.',
        );
      }
      await _vault.add(
        staffId: widget.staff.id,
        label: label,
        source: DoctorSignatureSource.paperPhoto,
        imageBytes: prescriptionSafe,
        ink: PrescriptionInk.blue,
        makeDefault: _items.isEmpty,
      );
      await _reload();
    } on Object catch (error) {
      _message('Paper signature could not be cleaned: $error');
    }
  }

  Future<String?> _photoOptions() async {
    final controller = TextEditingController(text: 'Paper signature');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Photograph signature'),
        content: SizedBox(
          width: 390,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Write the signature in blue or dark ink on clean white paper. Fill the center of the photo with the handwriting and avoid shadows or printed text.',
                style: TextStyle(
                  color: Color(0xFF667487),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Signature name'),
              ),
              const SizedBox(height: 9),
              const Row(
                children: [
                  Icon(Icons.circle, size: 12, color: medqurBlue),
                  SizedBox(width: 7),
                  Text(
                    'Prescription output: blue ink',
                    style: TextStyle(
                      color: medqurNavy,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Open camera'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
              '${signature.label} will no longer be available for new prescriptions. Existing signed revisions stay unchanged.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
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
              subtitle:
                  'Save a signature once, then reuse it on signed prescriptions.',
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.circle, size: 12, color: medqurBlue),
                SizedBox(width: 7),
                Text(
                  'Blue prescription ink',
                  style: TextStyle(
                    color: medqurNavy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ResponsiveActions(
              children: [
                FilledButton.icon(
                  onPressed: _drawSignature,
                  icon: const Icon(Icons.draw_rounded),
                  label: const Text('Draw signature'),
                ),
                OutlinedButton.icon(
                  onPressed: _photoSignature,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Photo from paper'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
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
                const SizedBox(height: 9),
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
    final preview = SignatureRendering.blueInkOnWhitePaper(signature.imageBytes);
    final valid = SignatureRendering.looksLikeSignature(preview);
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 430;
          final artwork = Container(
            width: narrow ? double.infinity : 132,
            height: 68,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: medqurLine),
            ),
            child: valid
                ? Image.memory(
                    preview,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  )
                : const Icon(
                    Icons.warning_amber_rounded,
                    color: medqurRed,
                  ),
          );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      signature.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: medqurInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (signature.isDefault)
                    const StatusPill(label: 'Default', color: medqurGreen),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                valid
                    ? (signature.source == DoctorSignatureSource.drawn
                        ? 'Drawn signature'
                        : 'Paper signature')
                    : 'Capture again',
                style: TextStyle(
                  color: valid ? const Color(0xFF7A8798) : medqurRed,
                  fontSize: 11,
                  fontWeight: valid ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 2,
                children: [
                  if (!signature.isDefault && valid)
                    TextButton(
                      onPressed: onDefault,
                      child: const Text('Make default'),
                    ),
                  TextButton(onPressed: onRename, child: const Text('Rename')),
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(foregroundColor: medqurRed),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                artwork,
                const SizedBox(height: 10),
                details,
              ],
            );
          }
          return Row(
            children: [
              artwork,
              const SizedBox(width: 12),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _EmptySignatureState extends StatelessWidget {
  const _EmptySignatureState();

  @override
  Widget build(BuildContext context) => const SoftCard(
        child: Column(
          children: [
            Icon(Icons.draw_outlined, color: medqurBlue, size: 30),
            SizedBox(height: 8),
            Text(
              'No saved signatures',
              style: TextStyle(
                color: medqurInk,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Draw one or photograph handwriting on white paper.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF718095), fontSize: 11.5),
            ),
          ],
        ),
      );
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FC),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: medqurLine),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.security_outlined, size: 17, color: medqurNavy),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'The signature artwork is not the login credential. Signed prescriptions remain bound to the authenticated staff ID, facility, time and audit record.',
                style: TextStyle(
                  color: Color(0xFF657286),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
}

class _DrawSignatureResult {
  const _DrawSignatureResult({
    required this.label,
    required this.signature,
  });

  final String label;
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
        signature: signature,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Draw signature',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Use a finger or stylus. Prescription output is blue.',
                style: TextStyle(color: Color(0xFF718095), fontSize: 11.5),
              ),
              const SizedBox(height: 13),
              TextField(
                controller: _label,
                decoration: const InputDecoration(labelText: 'Signature name'),
              ),
              const SizedBox(height: 12),
              PrescriptionSignaturePad(
                key: _padKey,
                height: 190,
                onChanged: (value) => setState(() => _ready = value),
              ),
              const SizedBox(height: 8),
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
