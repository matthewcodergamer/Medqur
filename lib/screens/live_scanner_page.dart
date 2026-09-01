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
          'Keep the badge code sharp and inside the frame.',
        ScanPurpose.patientWristband =>
          'Keep the whole QR visible. Medqur now uses a short wristband token so it can scan from farther away.',
        ScanPurpose.nidsCard =>
          'Show the BACK of the card. Center the QR, keep the card flat, and avoid glare. You do not need to fill the whole screen.',
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
  static const _cardAspect = 85.60 / 53.98;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _frameRect(size);
    final frame = RRect.fromRectAndRadius(
      rect,
      Radius.circular(purpose == ScanPurpose.nidsCard ? 18 : 20),
    );

    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frame);
    canvas.drawPath(shade, Paint()..color = const Color(0x9C000000));
    canvas.drawRRect(
      frame,
      Paint()
        ..color = const Color(0xD9FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final accent = Paint()
      ..color = _blue
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    final corner = math.min(42.0, rect.shortestSide * .18);
    for (final p in <List<double>>[
      [rect.left, rect.top, 1, 1],
      [rect.right, rect.top, -1, 1],
      [rect.left, rect.bottom, 1, -1],
      [rect.right, rect.bottom, -1, -1],
    ]) {
      canvas.drawLine(
        Offset(p[0], p[1]),
        Offset(p[0] + corner * p[2], p[1]),
        accent,
      );
      canvas.drawLine(
        Offset(p[0], p[1]),
        Offset(p[0], p[1] + corner * p[3]),
        accent,
      );
    }

    _label(
      canvas,
      switch (purpose) {
        ScanPurpose.nidsCard => 'BACK • QR',
        ScanPurpose.patientWristband => 'WRISTBAND QR',
        ScanPurpose.staffBadge => 'STAFF CODE',
        ScanPurpose.medication => 'PACKAGE CODE',
      },
      Offset(rect.center.dx, rect.top - 26),
    );
  }

  Rect _frameRect(Size size) {
    final center = Offset(size.width / 2, size.height * .43);

    if (purpose == ScanPurpose.nidsCard) {
      // A large square guide is easier than forcing the whole ID into a card
      // outline. The barcode detector still receives the entire camera frame.
      final side = math.min(size.width * .78, size.height * .45);
      return Rect.fromCenter(
        center: center,
        width: side,
        height: side,
      );
    }

    if (purpose == ScanPurpose.staffBadge) {
      final width = math.min(
        math.min(size.width * .94, size.height * .58 * _cardAspect),
        640.0,
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
        height: width * .31,
      );
    }

    final width = math.min(size.width * .90, 600.0);
    return Rect.fromCenter(
      center: center,
      width: width,
      height: width * .44,
    );
  }

  void _label(Canvas canvas, String text, Offset position) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFBFD4FF),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .9,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(position.dx - painter.width / 2, position.dy),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) =>
      oldDelegate.purpose != purpose;
}
