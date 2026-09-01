import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models.dart';

class WristbandData {
  const WristbandData({
    required this.patientName,
    required this.dateOfBirth,
    required this.age,
    required this.sex,
    required this.patientId,
    required this.encounterId,
    required this.facility,
    required this.allergies,
    required this.priority,
    required this.printedAt,
    required this.codeValue,
  });

  final String patientName;
  final String? dateOfBirth;
  final int age;
  final String sex;
  final String patientId;
  final String encounterId;
  final String facility;
  final String allergies;
  final String priority;
  final DateTime printedAt;
  final String codeValue;

  factory WristbandData.fromPatient(
    Patient patient, {
    String? facilityName,
    DateTime? printedAt,
  }) {
    final allergyText = patient.allergies.isEmpty
        ? 'NKDA'
        : patient.allergies.join(', ');
    final normalizedAllergy = allergyText.toLowerCase().contains('no known')
        ? 'NKDA'
        : allergyText;

    return WristbandData(
      patientName: patient.name,
      dateOfBirth: patient.dateOfBirth,
      age: patient.age,
      sex: patient.sex,
      patientId: patient.id,
      encounterId: patient.effectiveEncounterId,
      facility: facilityName ?? patient.facilityName ?? 'Medqur facility',
      allergies: normalizedAllergy,
      priority: switch (patient.triage) {
        TriageLevel.critical => 'P1',
        TriageLevel.urgent => 'P2',
        TriageLevel.moderate => 'P3',
        TriageLevel.routine => 'P4',
      },
      printedAt: printedAt ?? DateTime.now(),
      codeValue: patient.encounterToken,
    );
  }

  String get displayDob {
    final parsed = dateOfBirth == null ? null : DateTime.tryParse(dateOfBirth!);
    if (parsed == null) return 'UNKNOWN';
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  String get displayPrintedAt {
    final hour = printedAt.hour.toString().padLeft(2, '0');
    final minute = printedAt.minute.toString().padLeft(2, '0');
    return '${printedAt.year}-${printedAt.month.toString().padLeft(2, '0')}-${printedAt.day.toString().padLeft(2, '0')} $hour:$minute';
  }
}

class WristbandPrintService {
  WristbandPrintService._();

  static const double _mm = PdfPageFormat.mm;

  static Future<Uint8List> buildPdf(WristbandData data) async {
    final document = pw.Document();

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.all(12 * _mm),
        build: (context) {
          return pw.Center(
            child: pw.Container(
              width: 262 * _mm,
              height: 44 * _mm,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: PdfColors.black, width: 0.8),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: _identityPanel(data),
                  ),
                  pw.Container(width: 0.7, color: PdfColors.black),
                  pw.Expanded(
                    flex: 3,
                    child: _codePanel(data),
                  ),
                  pw.Container(width: 0.7, color: PdfColors.black),
                  pw.Expanded(
                    flex: 3,
                    child: _clinicalPanel(data),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return document.save();
  }

  static pw.Widget _identityPanel(WristbandData data) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(4.2 * _mm),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            color: PdfColors.black,
            padding: pw.EdgeInsets.symmetric(
              horizontal: 2.4 * _mm,
              vertical: 1.2 * _mm,
            ),
            child: pw.Text(
              'PATIENT IDENTIFICATION',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 2.2 * _mm),
          pw.Text(
            data.patientName.toUpperCase(),
            maxLines: 1,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 1.2 * _mm),
          _line('PATIENT ID', data.patientId, boldValue: true),
          _line('ENCOUNTER', data.encounterId),
          _line(
            'DOB',
            '${data.displayDob}   |   AGE: ${data.age}   |   SEX: ${_shortSex(data.sex)}',
          ),
          _line('FACILITY', data.facility),
          pw.Spacer(),
          pw.Text(
            'Printed ${data.displayPrintedAt} • Medqur prototype wristband',
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _codePanel(WristbandData data) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(3.2 * _mm),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'PATIENT CODE',
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 1.8 * _mm),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: data.codeValue,
            width: 26 * _mm,
            height: 26 * _mm,
            drawText: false,
          ),
          pw.SizedBox(height: 1.4 * _mm),
          pw.Text(
            data.encounterId,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _clinicalPanel(WristbandData data) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(3.8 * _mm),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ALLERGIES',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 0.8 * _mm),
          pw.Text(
            data.allergies.toUpperCase(),
            maxLines: 2,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3 * _mm),
          pw.Text(
            'CURRENT TRIAGE',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 0.8 * _mm),
          pw.Text(
            data.priority,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Spacer(),
          pw.Container(
            width: double.infinity,
            color: PdfColors.black,
            padding: pw.EdgeInsets.symmetric(
              horizontal: 2 * _mm,
              vertical: 1.3 * _mm,
            ),
            child: pw.Text(
              'MEDQUR CLINICAL SYSTEM',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _line(
    String label,
    String value, {
    bool boldValue = false,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 1.1 * _mm),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 8.2),
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(
              text: value,
              style: boldValue
                  ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  static String _shortSex(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.startsWith('m')) return 'M';
    if (normalized.startsWith('f')) return 'F';
    return value.isEmpty ? 'U' : value.substring(0, 1).toUpperCase();
  }

  static Future<bool> print(WristbandData data) {
    return Printing.layoutPdf(
      name: 'Medqur-${data.encounterId}-wristband.pdf',
      onLayout: (_) => buildPdf(data),
    );
  }

  static Future<void> saveOrShare(WristbandData data) async {
    final bytes = await buildPdf(data);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Medqur-${data.encounterId}-wristband.pdf',
    );
  }
}
