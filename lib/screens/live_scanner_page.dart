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
        ScanPurpose.nidsCard => 'Scan NIDS / NIC',
        ScanPurpose.medication => 'Scan medication',
      };

  String get guidance => switch (this) {
        ScanPurpose.staffBadge =>
          'Center the whole staff badge. Match the portrait area and keep the machine code visible.',
        ScanPurpose.patientWristband =>
          'Center the wristband code inside the wide guide and hold still.',
        ScanPurpose.nidsCard =>
          'Center the whole card. Match the portrait area on the left and keep all four card edges visible.',
        ScanPurpose.medication =>
          'Center the package DataMatrix, QR, or barcode inside the scan area.',
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
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 350,
      autoZoom: widget.purpose == ScanPurpose.medication,
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xE6101724),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(children: [
                  const Icon(Icons.center_focus_strong_rounded, color: Colors.white),
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
                ]),
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
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
            ]),
          ),
        ),
      );
}

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter(this.purpose);
  final ScanPurpose purpose;

  static const _blue = Color(0xFF6EA2FF);
  static const _softBlue = Color(0xFFBFD4FF);
  static const _cardAspect = 85.60 / 53.98; // ISO/IEC 7810 ID-1 / CR80 proportions.

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _frameRect(size);
    final radius = switch (purpose) {
      ScanPurpose.patientWristband => 18.0,
      ScanPurpose.medication => 18.0,
      _ => 22.0,
    };
    final frame = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frame);
    canvas.drawPath(shade, Paint()..color = const Color(0xA3000000));

    canvas.drawRRect(
      frame,
      Paint()
        ..color = const Color(0x14FFFFFF)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      frame,
      Paint()
        ..color = const Color(0xD9FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    _drawCorners(canvas, rect);

    switch (purpose) {
      case ScanPurpose.nidsCard:
        _drawNidsCardGuide(canvas, rect);
        break;
      case ScanPurpose.staffBadge:
        _drawStaffCardGuide(canvas, rect);
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
    final center = Offset(size.width / 2, size.height * .44);

    if (purpose == ScanPurpose.nidsCard || purpose == ScanPurpose.staffBadge) {
      final maxWidthFromHeight = size.height * .52 * _cardAspect;
      final width = math.min(
        math.min(size.width * .90, maxWidthFromHeight),
        590.0,
      );
      return Rect.fromCenter(
        center: center,
        width: width,
        height: width / _cardAspect,
      );
    }

    if (purpose == ScanPurpose.patientWristband) {
      final width = math.min(size.width * .92, 650.0);
      return Rect.fromCenter(
        center: center,
        width: width,
        height: width * .28,
      );
    }

    final width = math.min(size.width * .86, 560.0);
    return Rect.fromCenter(
      center: center,
      width: width,
      height: width * .40,
    );
  }

  void _drawCorners(Canvas canvas, Rect rect) {
    final accent = Paint()
      ..color = _blue
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    final corner = math.min(38.0, rect.shortestSide * .16);

    for (final pair in [
      [rect.left, rect.top, 1.0, 1.0],
      [rect.right, rect.top, -1.0, 1.0],
      [rect.left, rect.bottom, 1.0, -1.0],
      [rect.right, rect.bottom, -1.0, -1.0],
    ]) {
      final x = pair[0];
      final y = pair[1];
      final sx = pair[2];
      final sy = pair[3];
      canvas.drawLine(Offset(x, y), Offset(x + corner * sx, y), accent);
      canvas.drawLine(Offset(x, y), Offset(x, y + corner * sy), accent);
    }
  }

  void _drawNidsCardGuide(Canvas canvas, Rect card) {
    // The uploaded Jamaica NIC reference places the portrait on the left third
    // with identity text to the right. These guides are only alignment hints;
    // they do not reproduce the official card artwork or security features.
    final photo = Rect.fromLTWH(
      card.left + card.width * .035,
      card.top + card.height * .245,
      card.width * .285,
      card.height * .565,
    );
    _drawPortraitGhost(canvas, photo, label: 'PHOTO');

    final linePaint = Paint()
      ..color = const Color(0x8FFFFFFF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = card.left + card.width * .38;
    final available = card.width * .51;
    final ys = <double>[
      card.top + card.height * .20,
      card.top + card.height * .34,
      card.top + card.height * .47,
      card.top + card.height * .61,
      card.top + card.height * .74,
    ];
    final factors = <double>[.80, .55, .67, .48, .62];
    for (var i = 0; i < ys.length; i++) {
      canvas.drawLine(
        Offset(x, ys[i]),
        Offset(x + available * factors[i], ys[i]),
        linePaint,
      );
    }

    final testCode = Rect.fromLTWH(
      card.right - card.width * .205,
      card.bottom - card.height * .245,
      card.height * .17,
      card.height * .17,
    );
    _drawCodeTarget(canvas, testCode, label: 'BACK QR');

    _drawLabel(
      canvas,
      'NIDS / NIC CARD',
      Offset(card.center.dx, card.top - 28),
      centered: true,
    );
  }

  void _drawStaffCardGuide(Canvas canvas, Rect card) {
    final photo = Rect.fromLTWH(
      card.left + card.width * .055,
      card.top + card.height * .17,
      card.width * .25,
      card.height * .64,
    );
    _drawPortraitGhost(canvas, photo, label: 'PHOTO');

    final linePaint = Paint()
      ..color = const Color(0x86FFFFFF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = card.left + card.width * .37;
    final width = card.width * .42;
    for (final item in [
      [card.top + card.height * .25, .88],
      [card.top + card.height * .39, .68],
      [card.top + card.height * .53, .80],
      [card.top + card.height * .67, .58],
    ]) {
      canvas.drawLine(
        Offset(x, item[0]),
        Offset(x + width * item[1], item[0]),
        linePaint,
      );
    }

    final code = Rect.fromLTWH(
      card.right - card.width * .20,
      card.bottom - card.height * .28,
      card.height * .20,
      card.height * .20,
    );
    _drawCodeTarget(canvas, code, label: 'CODE');
    _drawLabel(
      canvas,
      'STAFF BADGE',
      Offset(card.center.dx, card.top - 28),
      centered: true,
    );
  }

  void _drawPortraitGhost(Canvas canvas, Rect rect, {required String label}) {
    final border = Paint()
      ..color = const Color(0x8FFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.width * .08)),
      border,
    );

    final ghost = Paint()
      ..color = const Color(0x52FFFFFF)
      ..style = PaintingStyle.fill;
    final headRadius = rect.width * .17;
    final head = Offset(rect.center.dx, rect.top + rect.height * .31);
    canvas.drawCircle(head, headRadius, ghost);

    final shoulderRect = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top + rect.height * .68),
      width: rect.width * .62,
      height: rect.height * .27,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        shoulderRect,
        Radius.circular(shoulderRect.height * .45),
      ),
      ghost,
    );

    _drawLabel(
      canvas,
      label,
      Offset(rect.center.dx, rect.bottom + 6),
      centered: true,
      fontSize: 8,
      color: const Color(0xBFFFFFFF),
    );
  }

  void _drawCodeTarget(
    Canvas canvas,
    Rect rect, {
    required String label,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = _blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0x126EA2FF)
        ..style = PaintingStyle.fill,
    );
    _drawLabel(
      canvas,
      label,
      Offset(rect.center.dx, rect.top - 17),
      centered: true,
      fontSize: 8.5,
      color: _softBlue,
    );
  }

  void _drawWristbandGuide(Canvas canvas, Rect rect) {
    final inner = rect.deflate(rect.height * .18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(10)),
      Paint()
        ..color = const Color(0x75FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    final centerLine = Paint()
      ..color = const Color(0x6FFFFFFF)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(inner.left + inner.width * .16, inner.center.dy),
      Offset(inner.right - inner.width * .16, inner.center.dy),
      centerLine,
    );
    _drawLabel(
      canvas,
      'WRISTBAND CODE',
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
    _drawCodeTarget(canvas, square, label: '2D CODE');

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
    _drawLabel(
      canvas,
      'BARCODE',
      Offset(barcode.center.dx, barcode.top - 17),
      centered: true,
      fontSize: 8.5,
    );
    _drawLabel(
      canvas,
      'MEDICATION CODE',
      Offset(rect.center.dx, rect.top - 28),
      centered: true,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset position, {
    bool centered = false,
    double fontSize = 10,
    Color color = _softBlue,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
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
