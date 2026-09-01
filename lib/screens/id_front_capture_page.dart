import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../widgets/common.dart';

class IdFrontCaptureResult {
  const IdFrontCaptureResult({
    required this.imageBytes,
    required this.capturedAt,
  });

  final Uint8List imageBytes;
  final DateTime capturedAt;
}

class IdFrontCapturePage extends StatefulWidget {
  const IdFrontCapturePage({
    super.key,
    required this.expectedName,
    required this.expectedId,
  });

  final String expectedName;
  final String expectedId;

  @override
  State<IdFrontCapturePage> createState() => _IdFrontCapturePageState();
}

class _IdFrontCapturePageState extends State<IdFrontCapturePage> {
  CameraController? _camera;
  bool _initializing = true;
  bool _capturing = false;
  Uint8List? _capturedBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _initializing = false;
            _error = 'No camera is available on this device.';
          });
        }
        return;
      }

      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _initializing = false;
        _error = null;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = error.description ?? error.code;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = '$error';
      });
    }
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final image = await camera.takePicture();
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _capturedBytes = bytes;
        _capturing = false;
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = error.description ?? error.code;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _error = '$error';
      });
    }
  }

  void _retake() {
    setState(() {
      _capturedBytes = null;
      _error = null;
    });
  }

  void _usePhoto() {
    final bytes = _capturedBytes;
    if (bytes == null) return;
    Navigator.of(context).pop(
      IdFrontCaptureResult(
        imageBytes: bytes,
        capturedAt: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final captured = _capturedBytes;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          captured == null ? 'Photograph front of ID' : 'Review front photo',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (captured != null)
                    Image.memory(captured, fit: BoxFit.cover)
                  else if (_camera != null && _camera!.value.isInitialized)
                    _CameraCover(controller: _camera!)
                  else if (_initializing)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else
                    const ColoredBox(color: Color(0xFF111827)),
                  const IgnorePointer(
                    child: CustomPaint(painter: _FrontCardOverlayPainter()),
                  ),
                  if (_error != null)
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xE6A61B2B),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFF0D1523),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        captured == null
                            ? Icons.badge_outlined
                            : Icons.check_circle_rounded,
                        color: captured == null ? const Color(0xFF9FC0FF) : medqurGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          captured == null
                              ? 'Line up the entire FRONT of the card. Put the portrait inside the person box, keep the printed details inside the guide, then tap the shutter. No typing is required.'
                              : 'Make sure the whole card, portrait and printed details are sharp and readable. Retake it if anything is cut off or blurry.',
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF162337),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Back scan expects: ${widget.expectedName} • ${widget.expectedId}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFCAD7EA),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (captured == null)
                    FilledButton.icon(
                      onPressed: _camera == null || _capturing ? null : _takePhoto,
                      icon: _capturing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt_rounded),
                      label: Text(_capturing ? 'Taking photo…' : 'Take front photo'),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _retake,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF61718A)),
                              minimumSize: const Size(0, 52),
                            ),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retake'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _usePhoto,
                            icon: const Icon(Icons.verified_user_rounded),
                            label: const Text('Use photo'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraCover extends StatelessWidget {
  const _CameraCover({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / previewSize.height;
        final scaledHeight = previewSize.width * scale;
        final coverScale = scaledHeight < constraints.maxHeight
            ? constraints.maxHeight / scaledHeight
            : 1.0;
        return Transform.scale(
          scale: coverScale,
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}

class _FrontCardOverlayPainter extends CustomPainter {
  const _FrontCardOverlayPainter();

  static const _blue = Color(0xFF75A8FF);
  static const _cardAspect = 85.60 / 53.98;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * .92;
    final height = width / _cardAspect;
    final maxHeight = size.height * .72;
    final cardHeight = height > maxHeight ? maxHeight : height;
    final cardWidth = cardHeight * _cardAspect;
    final card = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .47),
      width: cardWidth,
      height: cardHeight,
    );
    final rounded = RRect.fromRectAndRadius(card, const Radius.circular(22));

    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rounded);
    canvas.drawPath(shade, Paint()..color = const Color(0xA8000000));
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = const Color(0xE8FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    _drawCorners(canvas, card);

    final portrait = Rect.fromLTWH(
      card.left + card.width * .06,
      card.top + card.height * .17,
      card.width * .27,
      card.height * .64,
    );
    final portraitRRect = RRect.fromRectAndRadius(
      portrait,
      const Radius.circular(10),
    );
    canvas.drawRRect(
      portraitRRect,
      Paint()
        ..color = _blue.withValues(alpha: .14)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      portraitRRect,
      Paint()
        ..color = _blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    _drawPortraitGhost(canvas, portrait);

    final linePaint = Paint()
      ..color = const Color(0xAFFFFFFF)
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;
    final textLeft = card.left + card.width * .39;
    final textWidth = card.width * .49;
    for (final row in <List<double>>[
      [card.top + card.height * .23, .82],
      [card.top + card.height * .35, .60],
      [card.top + card.height * .47, .92],
      [card.top + card.height * .59, .73],
      [card.top + card.height * .71, .88],
    ]) {
      canvas.drawLine(
        Offset(textLeft, row[0]),
        Offset(textLeft + textWidth * row[1], row[0]),
        linePaint,
      );
    }

    _label(
      canvas,
      'FRONT • PORTRAIT',
      Offset(portrait.center.dx, portrait.top - 20),
      centered: true,
    );
    _label(
      canvas,
      'VISIBLE DETAILS',
      Offset(textLeft, card.top + card.height * .10),
      centered: false,
    );
    _label(
      canvas,
      'LINE UP THE ENTIRE CARD',
      Offset(card.center.dx, card.top - 30),
      centered: true,
      fontSize: 10.5,
    );
  }

  void _drawCorners(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = _blue
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.round;
    final c = rect.shortestSide * .13;
    for (final p in <List<double>>[
      [rect.left, rect.top, 1, 1],
      [rect.right, rect.top, -1, 1],
      [rect.left, rect.bottom, 1, -1],
      [rect.right, rect.bottom, -1, -1],
    ]) {
      canvas.drawLine(Offset(p[0], p[1]), Offset(p[0] + c * p[2], p[1]), paint);
      canvas.drawLine(Offset(p[0], p[1]), Offset(p[0], p[1] + c * p[3]), paint);
    }
  }

  void _drawPortraitGhost(Canvas canvas, Rect rect) {
    final ghost = Paint()..color = const Color(0x66FFFFFF);
    canvas.drawCircle(
      Offset(rect.center.dx, rect.top + rect.height * .31),
      rect.width * .17,
      ghost,
    );
    final shoulders = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top + rect.height * .69),
      width: rect.width * .64,
      height: rect.height * .29,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        shoulders,
        Radius.circular(shoulders.height * .48),
      ),
      ghost,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset position, {
    required bool centered,
    double fontSize = 8.5,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFFD5E4FF),
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
