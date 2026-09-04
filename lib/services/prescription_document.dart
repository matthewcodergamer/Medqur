import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models.dart';
import 'prescription_template_image.dart';
import 'signature_rendering.dart';
import 'signature_vault.dart';

class PrescriptionPrintData {
  const PrescriptionPrintData({
    required this.patient,
    required this.staff,
    required this.facility,
    required this.medication,
    required this.dose,
    required this.route,
    required this.frequency,
    required this.duration,
    required this.instructions,
    required this.ink,
    required this.signature,
    required this.copyNumber,
    required this.createdAt,
  });

  final Patient patient;
  final StaffProfile staff;
  final Facility facility;
  final String medication;
  final String dose;
  final String route;
  final String frequency;
  final String duration;
  final String instructions;
  final PrescriptionInk ink;
  final StoredDoctorSignature signature;
  final String copyNumber;
  final DateTime createdAt;

  String get prescriptionBody {
    final first = '$medication $dose'.trim();
    final sig = [route, frequency, duration]
        .where((value) => value.trim().isNotEmpty)
        .join(' • ');
    final lines = <String>[first];
    if (sig.isNotEmpty) lines.add(sig);
    if (instructions.trim().isNotEmpty) lines.add(instructions.trim());
    return lines.join('\n');
  }
}

abstract final class PrescriptionTemplateLayout {
  static const imageWidth = 627.0;
  static const imageHeight = 1114.0;

  static const patientName = (x: .267, y: .237);
  static const maleMark = (x: .182, y: .259);
  static const femaleMark = (x: .294, y: .259);
  static const age = (x: .448, y: .259);
  static const date = (x: .719, y: .259);
  static const ward = (x: .339, y: .282);
  static const discharged = (x: .897, y: .282);
  static const docket = (x: .292, y: .306);
  static const rxBody = (x: .142, y: .417, w: .605);
  static const copyNumber = (x: .430, y: .801);
  static const doctorName = (x: .430, y: .824);
  static const signature = (x: .430, y: .843, w: .345, h: .055);
}

abstract final class PrescriptionDocumentService {
  static Future<Uint8List> build(PrescriptionPrintData data) async {
    final document = pw.Document();
    final template = pw.MemoryImage(PrescriptionTemplateImage.bytes());
    final safeSignature = SignatureRendering.onWhitePaper(data.signature.imageBytes);
    if (!SignatureRendering.looksLikeSignature(safeSignature)) {
      throw const FormatException(
        'The saved signature image is not usable. Capture it again on clean white paper or draw it in Medqur before printing.',
      );
    }
    final signature = pw.MemoryImage(safeSignature);
    final pageWidth = 148 * PdfPageFormat.mm;
    final pageHeight = pageWidth *
        (PrescriptionTemplateLayout.imageHeight /
            PrescriptionTemplateLayout.imageWidth);
    final format = PdfPageFormat(pageWidth, pageHeight, marginAll: 0);
    final ink = data.ink == PrescriptionInk.blue
        ? const PdfColor(0.082, 0.29, 0.65)
        : const PdfColor(0.09, 0.12, 0.16);

    double x(double value) => pageWidth * value;
    double y(double value) => pageHeight * value;

    pw.Widget typed(String value, {double size = 7.6}) => pw.Text(
          value,
          maxLines: 1,
          style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: size,
            color: PdfColors.black,
          ),
        );

    document.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(
          children: [
            pw.Positioned(
              left: 0,
              top: 0,
              child: pw.SizedBox(
                width: pageWidth,
                height: pageHeight,
                child: pw.Image(template, fit: pw.BoxFit.fill),
              ),
            ),
            pw.Positioned(
              left: x(PrescriptionTemplateLayout.patientName.x),
              top: y(PrescriptionTemplateLayout.patientName.y),
              child: pw.SizedBox(
                width: x(.64),
                child: typed(data.patient.name, size: 7.8),
              ),
            ),
            if (data.patient.sex.toLowerCase().startsWith('m'))
              pw.Positioned(
                left: x(PrescriptionTemplateLayout.maleMark.x),
                top: y(PrescriptionTemplateLayout.maleMark.y),
                child: typed('X', size: 8.2),
              ),
            if (data.patient.sex.toLowerCase().startsWith('f'))
              pw.Positioned(
                left: x(PrescriptionTemplateLayout.femaleMark.x),
                top: y(PrescriptionTemplateLayout.femaleMark.y),
                child: typed('X', size: 8.2),
              ),
            pw.Positioned(
              left: x(PrescriptionTemplateLayout.age.x),
              top: y(PrescriptionTemplateLayout.age.y),
              child: typed('${data.patient.age}', size: 7.8),
            ),
            pw.Positioned(
              left: x(PrescriptionTemplateLayout.date.x),
              top: y(PrescriptionTemplateLayout.date.y),
              child: typed(_date(data.createdAt), size: 7.3),
            ),
            pw.Positioned(
              left: x(PrescriptionTemplateLayout.ward.x),
              top: y(PrescriptionTemplateLayout.ward.y),
              child: pw.SizedBox(
                width: x(.35),
                child: typed(data.facility.name, size: 6.8),
              ),
            ),
            if (data.patient.status == PatientStatus.discharge)
              pw.Positioned(
                left: x(PrescriptionTemplateLayout.discharged.x),
                top: y(PrescriptionTemplateLayout.discharged.y),
                child: typed('YES', size: 6.6),
              ),
            pw.Positioned(
              left: x(PrescriptionTemplateLayout.docket.x),
              top: y(PrescriptionTemplateLayout.docket.y),
              child: pw.SizedBox(
                width: x(.60),
                child: typed(data.patient.id, size: 7.4),
              ),
            ),
            pw.Positioned(
              left: x(PrescriptionTemplateLayout.rxBody.x),
              top: y(PrescriptionTemplateLayout.rxBody.y),
              child: pw.SizedBox(
                width: x(PrescriptionTemplateLayout.rxBody.w),
                child: pw.Text(
                  data.prescriptionBody,
                  style: pw.TextStyle(
                    font: pw.Font.timesItalic(),
                    fontSize: 11.5,
                    lineSpacing: 3.2,
                    color: ink,
                  ),
                ),
              ),
            ),
            pw.Positioned(
              left: x(PrescriptionTemplateLayout.copyNumber.x),
              top: y(PrescriptionTemplateLayout.copyNumber.y),
              child: typed(data.copyNumber, size: 6.8),
            ),
            pw.Positioned(
              left: x(PrescriptionTemplateLayout.doctorName.x),
              top: y(PrescriptionTemplateLayout.doctorName.y),
              child: pw.SizedBox(
                width: x(.34),
                child: typed(data.staff.name, size: 6.8),
              ),
            ),
            pw.Positioned(
              left: x(PrescriptionTemplateLayout.signature.x),
              top: y(PrescriptionTemplateLayout.signature.y),
              child: pw.SizedBox(
                width: x(PrescriptionTemplateLayout.signature.w),
                height: y(PrescriptionTemplateLayout.signature.h),
                child: pw.Image(signature, fit: pw.BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
