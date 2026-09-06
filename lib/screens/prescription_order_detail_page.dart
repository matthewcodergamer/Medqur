import 'dart:convert';

import 'package:flutter/material.dart';

import '../clinical_clock.dart';
import '../models.dart';
import '../services/prescription_record_store.dart';
import '../services/prescription_signature_store.dart';
import '../services/signature_rendering.dart';
import '../services/signature_vault.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
import '../widgets/medqur_responsive.dart';
import 'prescription_composer_page.dart';

class PrescriptionOrderDetailPage extends StatefulWidget {
  const PrescriptionOrderDetailPage({
    super.key,
    required this.staff,
    required this.patient,
    required this.facility,
    required this.order,
    required this.onAmended,
  });

  final StaffProfile staff;
  final Patient patient;
  final Facility facility;
  final MedicationOrder order;
  final ValueChanged<MedicationOrder> onAmended;

  @override
  State<PrescriptionOrderDetailPage> createState() =>
      _PrescriptionOrderDetailPageState();
}

class _PrescriptionOrderDetailPageState
    extends State<PrescriptionOrderDetailPage> {
  final _records = const PrescriptionRecordStore();
  final _signatures = PrescriptionSignatureStore();
  final _vault = DoctorSignatureVault();

  PrescriptionRecord? _record;
  List<PrescriptionRecord> _history = const [];
  StoredDoctorSignature? _signature;
  Map<String, dynamic>? _attestation;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final record = await _records.latestForMedication(
      patientId: widget.patient.id,
      order: widget.order,
    );
    final all = await _records.forPatient(widget.patient.id);
    final history = record == null
        ? <PrescriptionRecord>[]
        : all
            .where(
              (item) =>
                  item.medication == record.medication &&
                  item.orderedById == record.orderedById,
            )
            .toList()
      ..sort((a, b) => b.revision.compareTo(a.revision));

    Map<String, dynamic>? attestation;
    StoredDoctorSignature? signature;
    final key = record?.orderKey ?? widget.order.orderId;
    if (key != null && key.trim().isNotEmpty) {
      attestation = await _signatures.load(key);
      final rawPayload = attestation?['payload']?.toString();
      if (rawPayload != null && rawPayload.isNotEmpty) {
        try {
          final payload = jsonDecode(rawPayload);
          if (payload is Map<String, dynamic>) {
            final signatureId = payload['signatureId']?.toString();
            final prescriberId = payload['prescriberId']?.toString();
            if (signatureId != null && prescriberId != null) {
              final saved = await _vault.load(prescriberId);
              for (final item in saved) {
                if (item.id == signatureId) {
                  signature = item;
                  break;
                }
              }
            }
          }
        } on FormatException {
          // Keep digest/time visible even if legacy payload cannot be decoded.
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _record = record;
      _history = history;
      _attestation = attestation;
      _signature = signature;
      _loading = false;
    });
  }

  Future<void> _amend() async {
    final updated = await Navigator.of(context).push<MedicationOrder>(
      MaterialPageRoute(
        builder: (_) => PrescriptionComposerPage(
          staff: widget.staff,
          patient: widget.patient,
          facility: widget.facility,
          existingOrder: widget.order,
          existingRecord: _record,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    widget.onAmended(updated);
    Navigator.pop(context);
  }

  bool get _canAmend =>
      widget.staff.role == StaffRole.doctor &&
      !widget.order.administered &&
      _record?.isDispensed != true;

  @override
  Widget build(BuildContext context) {
    final record = _record;
    final signedAt = record?.signatureSignedAt ??
        DateTime.tryParse(_attestation?['signedAt']?.toString() ?? '');
    final digest = record?.signatureDigest ??
        _attestation?['digest']?.toString() ??
        '';

    return Scaffold(
      appBar: AppBar(title: const Text('Prescription order')),
      body: SafeArea(
        child: MedqurPage(
          children: [
            PatientContextBar(patient: widget.patient),
            const SizedBox(height: 16),
            MedqurPageHeader(
              eyebrow: record == null
                  ? 'Medication order'
                  : 'Signed prescription • revision ${record.revision}',
              title: widget.order.name,
              subtitle:
                  '${widget.order.dose} • ${widget.order.route} • ${widget.order.frequency}',
              trailing: StatusPill(
                label: record?.isDispensed == true
                    ? 'Dispensed'
                    : record?.isSuperseded == true
                        ? 'Superseded'
                        : 'Active',
                color: record?.isDispensed == true
                    ? medqurGreen
                    : record?.isSuperseded == true
                        ? const Color(0xFF7B8794)
                        : medqurBlue,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              _detailsCard(record),
              const SizedBox(height: 12),
              _signatureCard(record, signedAt, digest),
              if (_history.length > 1) ...[
                const SizedBox(height: 14),
                const SectionTitle('Revision history'),
                const SizedBox(height: 7),
                for (final item in _history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _revisionTile(item),
                  ),
              ],
              if (_canAmend) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _amend,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Amend prescription'),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailsCard(PrescriptionRecord? record) => SoftCard(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Order details',
              style: TextStyle(
                color: medqurInk,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ResponsiveFields(
              minFieldWidth: 180,
              children: [
                _field('Dose', widget.order.dose),
                _field('Route', widget.order.route),
                _field('Frequency', widget.order.frequency),
              ],
            ),
            if (record?.duration.trim().isNotEmpty == true) ...[
              const SizedBox(height: 9),
              _field('Duration', record!.duration),
            ],
            if (record?.instructions.trim().isNotEmpty == true) ...[
              const SizedBox(height: 9),
              _field('Instructions', record!.instructions),
            ],
            const SizedBox(height: 9),
            _field(
              'Ordered by',
              record == null
                  ? widget.order.orderedBy
                  : '${record.orderedByName} • ${record.orderedById}',
            ),
            if (record?.amendmentReason?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 9),
              _field('Latest amendment', record!.amendmentReason!),
            ],
          ],
        ),
      );

  Widget _field(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A8797),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: medqurInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      );

  Widget _signatureCard(
    PrescriptionRecord? record,
    DateTime? signedAt,
    String digest,
  ) {
    final signature = _signature;
    final preview = signature == null
        ? null
        : SignatureRendering.blueInkOnWhitePaper(signature.imageBytes);
    return SoftCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Doctor signature',
                  style: TextStyle(
                    color: medqurInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (digest.isNotEmpty)
                const Icon(Icons.verified_user_outlined,
                    color: medqurGreen, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 78,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: medqurLine),
            ),
            child: preview != null &&
                    SignatureRendering.looksLikeSignature(preview)
                ? Image.memory(
                    preview,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  )
                : const Text(
                    'Signature artwork unavailable on this device',
                    style: TextStyle(
                      color: Color(0xFF7A8797),
                      fontSize: 11.5,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          if (signedAt != null)
            Text(
              'Signed ${ClinicalClock.dateTimeShort(signedAt.toLocal())}',
              style: const TextStyle(
                color: Color(0xFF667487),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (digest.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Attestation ${digest.substring(0, digest.length < 16 ? digest.length : 16)}…',
              style: const TextStyle(
                color: Color(0xFF8793A2),
                fontSize: 10.5,
              ),
            ),
          ],
          if (record?.copyNumber.isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(
              record!.copyNumber,
              style: const TextStyle(
                color: Color(0xFF8793A2),
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _revisionTile(PrescriptionRecord item) => SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.isSuperseded
                    ? const Color(0xFFF0F2F4)
                    : medqurBlue.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                'R${item.revision}',
                style: TextStyle(
                  color: item.isSuperseded
                      ? const Color(0xFF748091)
                      : medqurBlue,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.dose} • ${item.route} • ${item.frequency}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: medqurInk,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.amendmentReason?.trim().isNotEmpty == true
                        ? item.amendmentReason!
                        : 'Original signed prescription',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7A8797),
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
