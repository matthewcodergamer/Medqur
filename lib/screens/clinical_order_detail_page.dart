import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../clinical_models.dart';
import '../models.dart';
import '../services/access_policy.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';

class ClinicalOrderDetailPage extends StatefulWidget {
  const ClinicalOrderDetailPage({
    super.key,
    required this.staff,
    required this.order,
    this.patient,
    required this.onChanged,
  });

  final StaffProfile staff;
  final DiagnosticOrder order;
  final Patient? patient;
  final VoidCallback onChanged;

  @override
  State<ClinicalOrderDetailPage> createState() =>
      _ClinicalOrderDetailPageState();
}

class _ClinicalOrderDetailPageState extends State<ClinicalOrderDetailPage> {
  final _result = TextEditingController();
  final _picker = ImagePicker();
  bool _capturing = false;

  bool get _canWork =>
      AccessPolicy.canWorkOnDiagnosticOrder(widget.staff, widget.order);

  @override
  void initState() {
    super.initState();
    _result.text = widget.order.resultSummary;
  }

  @override
  void dispose() {
    _result.dispose();
    super.dispose();
  }

  void _changed() {
    widget.onChanged();
    if (mounted) setState(() {});
  }

  void _start() {
    if (!_canWork || widget.order.status != DiagnosticOrderStatus.ordered) {
      return;
    }
    widget.order
      ..status = DiagnosticOrderStatus.inProgress
      ..startedBy = widget.staff.name
      ..startedAt = DateTime.now();
    _changed();
  }

  Future<void> _capture(ImageSource source) async {
    if (!_canWork || widget.order.status == DiagnosticOrderStatus.completed) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 72,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) return;
      if (bytes.length > 3 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Image is too large for the local prototype. Capture a smaller image.',
            ),
          ),
        );
        return;
      }

      final now = DateTime.now();
      widget.order.attachments.add(
        DiagnosticAttachment(
          id: 'ATT-${now.microsecondsSinceEpoch}',
          fileName: image.name.isEmpty ? 'clinical-result.jpg' : image.name,
          mimeType: _mimeType(image.name),
          base64Data: base64Encode(bytes),
          uploadedBy: widget.staff.name,
          uploadedAt: now,
        ),
      );
      if (widget.order.status == DiagnosticOrderStatus.ordered) {
        widget.order
          ..status = DiagnosticOrderStatus.inProgress
          ..startedBy = widget.staff.name
          ..startedAt = now;
      }
      _changed();
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  String _mimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _saveSummary() {
    if (!_canWork) return;
    widget.order.resultSummary = _result.text.trim();
    _changed();
  }

  void _complete() {
    if (!_canWork) return;
    final summary = _result.text.trim();
    if (summary.isEmpty && widget.order.attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a result summary or attachment before completion.'),
        ),
      );
      return;
    }
    widget.order
      ..resultSummary = summary
      ..status = DiagnosticOrderStatus.completed
      ..completedBy = widget.staff.name
      ..completedAt = DateTime.now();
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Scaffold(
      appBar: AppBar(title: Text(order.type.label)),
      body: MedqurPage(
        children: [
          if (widget.patient != null) ...[
            PatientContextBar(patient: widget.patient!),
            const SizedBox(height: 16),
          ],
          MedqurPageHeader(
            eyebrow: order.assignedDiscipline.label,
            title: order.studyName,
            subtitle:
                '${order.priority.label} • Ordered by ${order.orderedBy}',
            trailing: StatusPill(
              label: order.status.label,
              color: order.status == DiagnosticOrderStatus.completed
                  ? medqurGreen
                  : order.priority == DiagnosticOrderPriority.stat
                      ? medqurRed
                      : medqurBlue,
            ),
          ),
          const SizedBox(height: 16),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _meta('Patient ID', order.patientId),
                _meta('Encounter', order.encounterId),
                _meta('Assigned team', order.assignedDiscipline.label),
                if (order.instructions.trim().isNotEmpty) ...[
                  const Divider(height: 20),
                  const Text(
                    'Clinical question / instructions',
                    style: TextStyle(
                      color: medqurInk,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    order.instructions,
                    style: const TextStyle(
                      color: Color(0xFF65748A),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_canWork && order.status == DiagnosticOrderStatus.ordered)
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start task'),
            ),
          if (_canWork && order.status != DiagnosticOrderStatus.completed) ...[
            const SizedBox(height: 12),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Result',
                    style: TextStyle(
                      color: medqurInk,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _result,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Result summary',
                      hintText: 'Enter the finding or completion note',
                    ),
                    onChanged: (_) => _saveSummary(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _capturing
                              ? null
                              : () => _capture(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Take photo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _capturing
                              ? null
                              : () => _capture(ImageSource.gallery),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Upload'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A photographed paper ECG can be attached during the prototype. Production X-ray, CT and MRI images should come from approved PACS/DICOM integration, not camera photographs.',
                    style: TextStyle(
                      color: Color(0xFF7A8798),
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!_canWork) ...[
            const SizedBox(height: 12),
            SoftCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.visibility_outlined,
                      color: medqurBlue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.staff.role == StaffRole.doctor
                          ? 'Doctor review mode. Results from the performing team appear here.'
                          : 'This order is routed to ${order.assignedDiscipline.label}. Your account can read it but cannot complete it.',
                      style: const TextStyle(
                        color: Color(0xFF647286),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.attachments.isNotEmpty) ...[
            const SizedBox(height: 18),
            SectionTitle('Attachments'),
            const SizedBox(height: 9),
            for (final attachment in order.attachments)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AttachmentCard(attachment: attachment),
              ),
          ],
          if (order.resultSummary.trim().isNotEmpty && !_canWork) ...[
            const SizedBox(height: 18),
            SectionTitle('Result summary'),
            const SizedBox(height: 9),
            SoftCard(
              child: Text(
                order.resultSummary,
                style: const TextStyle(
                  color: medqurInk,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (_canWork && order.status != DiagnosticOrderStatus.completed) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _complete,
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Complete & return result'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _meta(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 94,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF7A8798),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: medqurInk,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({required this.attachment});
  final DiagnosticAttachment attachment;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      bytes = base64Decode(attachment.base64Data);
    } catch (_) {}

    return SoftCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: bytes == null || bytes.isEmpty
                ? Container(
                    width: 66,
                    height: 52,
                    color: const Color(0xFFF2F4F7),
                    child: const Icon(Icons.insert_drive_file_outlined),
                  )
                : Image.memory(
                    bytes,
                    width: 66,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 66,
                      height: 52,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: medqurInk,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${attachment.uploadedBy} • ${(attachment.byteLength / 1024).ceil()} KB',
                  style: const TextStyle(
                    color: Color(0xFF7A8798),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
