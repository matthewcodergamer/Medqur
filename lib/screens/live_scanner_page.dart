import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum ScanPurpose { staffBadge, patientWristband, nidsCard, medication }

extension ScanPurposeLabel on ScanPurpose {
  String get title => switch (this) {
        ScanPurpose.staffBadge => 'Scan staff ID',
        ScanPurpose.patientWristband => 'Scan patient wristband',
        ScanPurpose.nidsCard => 'Scan back of NIDS / NIC',
        ScanPurpose.medication => 'Scan medication',
      };

  String get guidance => switch (this) {
        ScanPurpose.staffBadge =>
          'Line up the badge inside the card outline and keep its code sharp.',
        ScanPurpose.patientWristband =>
          'Keep the whole QR visible. Medqur uses a short wristband token so it can scan from farther away.',
        ScanPurpose.nidsCard =>
          'Line up the ENTIRE back of the card. Keep the QR inside the blue QR box and the machine-readable lines inside the lower guide.',
        ScanPurpose.medication =>
          'Center the DataMatrix, QR, or barcode and keep the package still.',
      };
}

class ScanCapture {
  const ScanCapture({required this.value, required this.format});
  final String value;
  final BarcodeFormat format;
}

class LiveScannerPage extends StatefulWidget {
  const LiveScannerPage({super.key, required this.purpose});
  final ScanPurpose purpose;

  @override
  State<LiveScannerPage> createState() => _LiveScannerPageState();
}

class _LiveScannerPageState extends State<LiveScannerPage> {
  late final MobileScannerController _controller;
  bool _returning = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.unrestricted,
      autoZoom: widget.purpose != ScanPurpose.staffBadge,
      formats: switch (widget.purpose) {
        ScanPurpose.nidsCard || ScanPurpose.patientWristband => const [
            BarcodeFormat.qrCode,
          ],
        ScanPurpose.staffBadge => const [
            BarcodeFormat.qrCode,
            BarcodeFormat.code128,
          ],
        ScanPurpose.medication => const [
            BarcodeFormat.dataMatrix,
            BarcodeFormat.qrCode,
            BarcodeFormat.code128,
            BarcodeFormat.code39,
            BarcodeFormat.ean13,
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
          ],
      },
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_returning) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      _returning = true;
      unawaited(_controller.stop());
      Navigator.of(context).pop(
        ScanCapture(value: value, format: barcode.format),
      );
      return;
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.purpose.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (!kIsWeb)
            IconButton(
              tooltip: 'Flash',
              onPressed: () => _controller.toggleTorch(),
              icon: const Icon(Icons.flashlight_on_rounded),
            ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: _onDetect,
            tapToFocus: true,
            placeholderBuilder: (_) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorBuilder: (context, error) => _CameraError(
              error: error,
              retry: () => _controller.start(),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _ScanOverlayPainter(widget.purpose),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(18),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xE6101724),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.center_focus_strong_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.purpose.guidance,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.retry});
  final MobileScannerException error;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF0C1728),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.no_photography_outlined,
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Camera access is needed to scan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB9C7D8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: retry,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Try camera again'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter(this.purpose);
  final ScanPurpose purpose;

  static const _blue = Color(0xFF6EA2FF);
  static const _softBlue = Color(0xFFD0E0FF);
  static const _cardAspect = 85.60 / 53.98;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _frameRect(size);
    final frame = RRect.fromRectAndRadius(
      rect,
      Radius.circular(
        purpose == ScanPurpose.patientWristband ||
                purpose == ScanPurpose.medication
            ? 18
            : 22,
      ),
    );

    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frame);
    canvas.drawPath(shade, Paint()..color = const Color(0xA3000000));
    canvas.drawRRect(
      frame,
      Paint()..color = const Color(0x10FFFFFF),
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = const Color(0xE6FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    _drawCorners(canvas, rect);

    switch (purpose) {
      case ScanPurpose.nidsCard:
        _drawNidsBackGuide(canvas, rect);
        break;
      case ScanPurpose.staffBadge:
        _drawStaffGuide(canvas, rect);
        break;
      case ScanPurpose.patientWristband:
        _drawWristbandGuide(canvas, rect);
        break;
      case ScanPurpose.medication:
        _drawMedicationGuide(canvas, rect);
        break;
    }
  }

  Rect _frameRect(Size size) {
    final center = Offset(size.width / 2, size.height * .43);
    if (purpose == ScanPurpose.nidsCard || purpose == ScanPurpose.staffBadge) {
      final width = math.min(
        math.min(size.width * .92, size.height * .55 * _cardAspect),
        620.0,
      );
      return Rect.fromCenter(
        center: center,
        width: width,
        height: width / _cardAspect,
      );
    }
    if (purpose == ScanPurpose.patientWristband) {
      final width = math.min(size.width * .94, 680.0);
      return Rect.fromCenter(
        center: center,
        width: width,
        height: width * .30,
      );
    }
    final width = math.min(size.width * .90, 600.0);
    return Rect.fromCenter(
      center: center,
      width: width,
      height: width * .44,
    );
  }

  void _drawCorners(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = _blue
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    final corner = math.min(40.0, rect.shortestSide * .16);
    for (final p in <List<double>>[
      [rect.left, rect.top, 1, 1],
      [rect.right, rect.top, -1, 1],
      [rect.left, rect.bottom, 1, -1],
      [rect.right, rect.bottom, -1, -1],
    ]) {
      canvas.drawLine(
        Offset(p[0], p[1]),
        Offset(p[0] + corner * p[2], p[1]),
        paint,
      );
      canvas.drawLine(
        Offset(p[0], p[1]),
        Offset(p[0], p[1] + corner * p[3]),
        paint,
      );
    }
  }

  void _drawNidsBackGuide(Canvas canvas, Rect card) {
    _label(
      canvas,
      'BACK • LINE UP ENTIRE CARD',
      Offset(card.center.dx, card.top - 30),
      centered: true,
      fontSize: 10.5,
    );

    final qrSize = card.height * .31;
    final qr = Rect.fromLTWH(
      card.right - qrSize - card.width * .065,
      card.top + card.height * .095,
      qrSize,
      qrSize,
    );
    _drawCodeTarget(canvas, qr, 'QR');

    final dataPaint = Paint()
      ..color = const Color(0x9EFFFFFF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final left = card.left + card.width * .065;
    final rightLimit = qr.left - card.width * .045;
    final available = rightLimit - left;
    for (final row in <List<double>>[
      [card.top + card.height * .16, .46],
      [card.top + card.height * .27, .66],
      [card.top + card.height * .38, .55],
      [card.top + card.height * .49, .79],
    ]) {
      canvas.drawLine(
        Offset(left, row[0]),
        Offset(left + available * row[1], row[0]),
        dataPaint,
      );
    }

    final dividerY = card.top + card.height * .60;
    canvas.drawLine(
      Offset(card.left + card.width * .055, dividerY),
      Offset(card.right - card.width * .055, dividerY),
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 1,
    );

    final mrzRect = Rect.fromLTWH(
      card.left + card.width * .055,
      card.top + card.height * .64,
      card.width * .89,
      card.height * .27,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(mrzRect, const Radius.circular(9)),
      Paint()
        ..color = const Color(0x166EA2FF)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(mrzRect, const Radius.circular(9)),
      Paint()
        ..color = const Color(0x8F6EA2FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final mrzPaint = Paint()
      ..color = const Color(0xB8FFFFFF)
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.square;
    for (var i = 0; i < 3; i++) {
      final y = mrzRect.top + mrzRect.height * (.26 + i * .28);
      canvas.drawLine(
        Offset(mrzRect.left + mrzRect.width * .035, y),
        Offset(mrzRect.right - mrzRect.width * .035, y),
        mrzPaint,
      );
    }
    _label(
      canvas,
      'MACHINE-READABLE LINES',
      Offset(mrzRect.left + mrzRect.width * .035, mrzRect.top - 15),
      centered: false,
      fontSize: 7.5,
    );
  }

  void _drawStaffGuide(Canvas canvas, Rect card) {
    final portrait = Rect.fromLTWH(
      card.left + card.width * .055,
      card.top + card.height * .17,
      card.width * .25,
      card.height * .64,
    );
    _drawPortraitGhost(canvas, portrait);

    final linePaint = Paint()
      ..color = const Color(0x8FFFFFFF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = card.left + card.width * .37;
    final width = card.width * .42;
    for (final row in <List<double>>[
      [card.top + card.height * .25, .88],
      [card.top + card.height * .39, .68],
      [card.top + card.height * .53, .80],
      [card.top + card.height * .67, .58],
    ]) {
      canvas.drawLine(
        Offset(x, row[0]),
        Offset(x + width * row[1], row[0]),
        linePaint,
      );
    }

    final codeSize = card.height * .22;
    final code = Rect.fromLTWH(
      card.right - codeSize - card.width * .055,
      card.bottom - codeSize - card.height * .07,
      codeSize,
      codeSize,
    );
    _drawCodeTarget(canvas, code, 'CODE');
    _label(
      canvas,
      'STAFF BADGE',
      Offset(card.center.dx, card.top - 28),
      centered: true,
    );
  }

  void _drawPortraitGhost(Canvas canvas, Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(9)),
      Paint()
        ..color = const Color(0x8FFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final ghost = Paint()..color = const Color(0x52FFFFFF);
    canvas.drawCircle(
      Offset(rect.center.dx, rect.top + rect.height * .31),
      rect.width * .17,
      ghost,
    );
    final shoulders = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top + rect.height * .68),
      width: rect.width * .62,
      height: rect.height * .27,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        shoulders,
        Radius.circular(shoulders.height * .45),
      ),
      ghost,
    );
  }

  void _drawCodeTarget(Canvas canvas, Rect rect, String label) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0x1C6EA2FF),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = _blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8,
    );
    _label(
      canvas,
      label,
      Offset(rect.center.dx, rect.top - 18),
      centered: true,
      fontSize: 8.5,
    );
  }

  void _drawWristbandGuide(Canvas canvas, Rect rect) {
    final inner = rect.deflate(rect.height * .17);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(10)),
      Paint()
        ..color = const Color(0x7FFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    _label(
      canvas,
      'WRISTBAND QR',
      Offset(rect.center.dx, rect.top - 28),
      centered: true,
    );
  }

  void _drawMedicationGuide(Canvas canvas, Rect rect) {
    final squareSize = math.min(rect.height * .56, rect.width * .24);
    final square = Rect.fromCenter(
      center: Offset(rect.left + rect.width * .28, rect.center.dy),
      width: squareSize,
      height: squareSize,
    );
    _drawCodeTarget(canvas, square, '2D CODE');

    final barcode = Rect.fromCenter(
      center: Offset(rect.left + rect.width * .67, rect.center.dy),
      width: rect.width * .42,
      height: rect.height * .36,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barcode, const Radius.circular(8)),
      Paint()
        ..color = const Color(0x8FFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    _label(
      canvas,
      'BARCODE',
      Offset(barcode.center.dx, barcode.top - 18),
      centered: true,
      fontSize: 8.5,
    );
    _label(
      canvas,
      'MEDICATION CODE',
      Offset(rect.center.dx, rect.top - 28),
      centered: true,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset position, {
    required bool centered,
    double fontSize = 10,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _softBlue,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: .9,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centered
          ? Offset(position.dx - painter.width / 2, position.dy)
          : position,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) =>
      oldDelegate.purpose != purpose;
}
