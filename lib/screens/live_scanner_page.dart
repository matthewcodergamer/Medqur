import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../widgets/common.dart';

enum ScanPurpose { staffBadge, patientWristband, nidsCard, medication }

extension ScanPurposeLabel on ScanPurpose {
  String get title => switch (this) {
        ScanPurpose.staffBadge => 'Scan staff ID',
        ScanPurpose.patientWristband => 'Scan patient wristband',
        ScanPurpose.nidsCard => 'Scan NIDS / NIC',
        ScanPurpose.medication => 'Scan medication',
      };

  String get guidance => switch (this) {
        ScanPurpose.staffBadge => 'Fit the staff badge inside the card outline.',
        ScanPurpose.patientWristband => 'Place the wristband QR or barcode inside the square.',
        ScanPurpose.nidsCard => 'Fit the identity card inside the card outline.',
        ScanPurpose.medication => 'Place the package QR or barcode inside the scan area.',
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
      Navigator.of(context).pop(ScanCapture(value: value, format: barcode.format));
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
        title: Text(widget.purpose.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (!kIsWeb)
            IconButton(tooltip: 'Flash', onPressed: _controller.toggleTorch, icon: const Icon(Icons.flashlight_on_rounded)),
          IconButton(tooltip: 'Switch camera', onPressed: _controller.switchCamera, icon: const Icon(Icons.cameraswitch_rounded)),
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
            placeholderBuilder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (context, error) => _CameraError(error: error, retry: _controller.start),
          ),
          IgnorePointer(child: CustomPaint(painter: _ScanOverlayPainter(widget.purpose))),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(18),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(color: const Color(0xE6101724), borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(widget.purpose.guidance, style: const TextStyle(color: Colors.white, height: 1.35, fontWeight: FontWeight.w600))),
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
              const Icon(Icons.no_photography_outlined, color: Colors.white, size: 44),
              const SizedBox(height: 14),
              const Text('Camera access is needed to scan.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB9C7D8), fontSize: 12)),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: retry, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Try camera again')),
            ]),
          ),
        ),
      );
}

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter(this.purpose);
  final ScanPurpose purpose;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .43);
    final width = switch (purpose) {
      ScanPurpose.staffBadge || ScanPurpose.nidsCard => size.width * .82,
      ScanPurpose.medication => size.width * .82,
      ScanPurpose.patientWristband => size.shortestSide * .68,
    };
    final height = switch (purpose) {
      ScanPurpose.staffBadge || ScanPurpose.nidsCard => width / 1.58,
      ScanPurpose.medication => width * .42,
      ScanPurpose.patientWristband => width,
    };
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    final frame = RRect.fromRectAndRadius(rect, Radius.circular(purpose == ScanPurpose.patientWristband ? 24 : 20));

    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(frame);
    canvas.drawPath(shade, Paint()..color = const Color(0x8A000000));
    canvas.drawRRect(frame, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.2);

    final accent = Paint()..color = const Color(0xFF6EA2FF)..strokeWidth = 4..strokeCap = StrokeCap.round;
    const corner = 28.0;
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

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) => oldDelegate.purpose != purpose;
}
