import 'package:flutter/material.dart';

import '../services/prescription_document.dart';
import '../services/prescription_template_image.dart';
import '../services/signature_vault.dart';

class PrescriptionFormPreview extends StatelessWidget {
  const PrescriptionFormPreview({
    super.key,
    required this.data,
    this.maxWidth = 430,
  });

  final PrescriptionPrintData data;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final template = PrescriptionTemplateImage.bytes();
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: AspectRatio(
          aspectRatio: PrescriptionTemplateLayout.imageWidth /
              PrescriptionTemplateLayout.imageHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              double x(double value) => constraints.maxWidth * value;
              double y(double value) => constraints.maxHeight * value;
              final ink = data.ink == PrescriptionInk.blue
                  ? const Color(0xFF154AA6)
                  : const Color(0xFF17202B);
              final typed = TextStyle(
                color: const Color(0xFF151515),
                fontSize: constraints.maxWidth * .017,
                height: 1,
                fontWeight: FontWeight.w500,
              );
              final pen = TextStyle(
                color: ink,
                fontSize: constraints.maxWidth * .030,
                height: 1.18,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                fontFamily: 'Kalam',
                fontFamilyFallback: const [
                  'Bradley Hand',
                  'Segoe Print',
                  'cursive',
                ],
              );

              return DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1610223A),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        template,
                        key: ValueKey<int>(template.length),
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.white,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(24),
                          child: const Text(
                            'Prescription form could not be displayed. Reopen the preview before printing.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF687586),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      _positioned(
                        constraints,
                        PrescriptionTemplateLayout.patientName,
                        width: .63,
                        child: Text(
                          data.patient.name,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: typed,
                        ),
                      ),
                      if (data.patient.sex.toLowerCase().startsWith('m'))
                        _positioned(
                          constraints,
                          PrescriptionTemplateLayout.maleMark,
                          child: Text(
                            'X',
                            style: typed.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      if (data.patient.sex.toLowerCase().startsWith('f'))
                        _positioned(
                          constraints,
                          PrescriptionTemplateLayout.femaleMark,
                          child: Text(
                            'X',
                            style: typed.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      _positioned(
                        constraints,
                        PrescriptionTemplateLayout.age,
                        child: Text('${data.patient.age}', style: typed),
                      ),
                      _positioned(
                        constraints,
                        PrescriptionTemplateLayout.date,
                        child: Text(
                          _date(data.createdAt),
                          style: typed.copyWith(
                            fontSize: constraints.maxWidth * .0155,
                          ),
                        ),
                      ),
                      _positioned(
                        constraints,
                        PrescriptionTemplateLayout.ward,
                        width: .35,
                        child: Text(
                          data.facility.name,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: typed.copyWith(
                            fontSize: constraints.maxWidth * .0145,
                          ),
                        ),
                      ),
                      if (data.patient.status.name == 'discharge')
                        _positioned(
                          constraints,
                          PrescriptionTemplateLayout.discharged,
                          child: Text(
                            'YES',
                            style: typed.copyWith(
                              fontSize: constraints.maxWidth * .014,
                            ),
                          ),
                        ),
                      _positioned(
                        constraints,
                        PrescriptionTemplateLayout.docket,
                        width: .59,
                        child: Text(data.patient.id, style: typed),
                      ),
                      Positioned(
                        left: x(PrescriptionTemplateLayout.rxBody.x),
                        top: y(PrescriptionTemplateLayout.rxBody.y),
                        width: x(PrescriptionTemplateLayout.rxBody.w),
                        child: Text(data.prescriptionBody, style: pen),
                      ),
                      _positioned(
                        constraints,
                        PrescriptionTemplateLayout.copyNumber,
                        child: Text(
                          data.copyNumber,
                          style: typed.copyWith(
                            fontSize: constraints.maxWidth * .0145,
                          ),
                        ),
                      ),
                      _positioned(
                        constraints,
                        PrescriptionTemplateLayout.doctorName,
                        width: .34,
                        child: Text(
                          data.staff.name,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: typed.copyWith(
                            fontSize: constraints.maxWidth * .0145,
                          ),
                        ),
                      ),
                      Positioned(
                        left: x(PrescriptionTemplateLayout.signature.x),
                        top: y(PrescriptionTemplateLayout.signature.y),
                        width: x(PrescriptionTemplateLayout.signature.w),
                        height: y(PrescriptionTemplateLayout.signature.h),
                        child: Image.memory(
                          data.signature.imageBytes,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static Widget _positioned(
    BoxConstraints constraints,
    ({double x, double y}) point, {
    double? width,
    required Widget child,
  }) =>
      Positioned(
        left: constraints.maxWidth * point.x,
        top: constraints.maxHeight * point.y,
        width: width == null ? null : constraints.maxWidth * width,
        child: child,
      );

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
