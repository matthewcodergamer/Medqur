import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'common.dart';

class PrescriptionSignature {
  const PrescriptionSignature({
    required this.payload,
    required this.digest,
    required this.signedAt,
  });

  final String payload;
  final String digest;
  final DateTime signedAt;

  int get pointCount {
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return (decoded['strokes'] as List<dynamic>? ?? const [])
          .fold<int>(0, (sum, stroke) => sum + ((stroke as List<dynamic>?)?.length ?? 0));
    } on Object {
      return 0;
    }
  }
}

class PrescriptionSignaturePad extends StatefulWidget {
  const PrescriptionSignaturePad({
    super.key,
    this.height = 180,
    this.onChanged,
  });

  final double height;
  final ValueChanged<bool>? onChanged;

  @override
  State<PrescriptionSignaturePad> createState() => PrescriptionSignaturePadState();
}

class PrescriptionSignaturePadState extends State<PrescriptionSignaturePad> {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  bool get hasSignature => _strokes.any((stroke) => stroke.length > 2);

  void clear() {
    setState(_strokes.clear);
    widget.onChanged?.call(false);
  }

  PrescriptionSignature? buildSignature() {
    if (!hasSignature || _size.width <= 0 || _size.height <= 0) return null;
    final payload = jsonEncode({
      'v': 1,
      'canvas': {'w': 1000, 'h': 400},
      'strokes': _strokes
          .where((stroke) => stroke.length > 2)
          .map(
            (stroke) => stroke
                .map(
                  (point) => [
                    ((point.dx / _size.width).clamp(0.0, 1.0) * 1000).round(),
                    ((point.dy / _size.height).clamp(0.0, 1.0) * 400).round(),
                  ],
                )
                .toList(growable: false),
          )
          .toList(growable: false),
    });
    return PrescriptionSignature(
      payload: payload,
      digest: sha256.convert(utf8.encode(payload)).toString(),
      signedAt: DateTime.now().toUtc(),
    );
  }

  void _start(DragStartDetails details) {
    setState(() => _strokes.add([details.localPosition]));
  }

  void _update(DragUpdateDetails details) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(details.localPosition));
    widget.onChanged?.call(hasSignature);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, widget.height);
        return Container(
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasSignature ? medqurBlue.withValues(alpha: .55) : medqurLine,
              width: hasSignature ? 1.5 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _SignaturePainter(_strokes)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _start,
                onPanUpdate: _update,
              ),
              if (!hasSignature)
                const IgnorePointer(
                  child: Center(
                    child: Text(
                      'Sign here',
                      style: TextStyle(
                        color: Color(0xFF9AA6B6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Container(height: 1, color: const Color(0xFFE2E8F0)),
              ),
              const Positioned(
                left: 16,
                bottom: 7,
                child: Text(
                  'Prescriber signature',
                  style: TextStyle(color: Color(0xFF98A3B2), fontSize: 9.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SignaturePreview extends StatelessWidget {
  const SignaturePreview({super.key, required this.payload, this.height = 56});
  final String payload;
  final double height;

  @override
  Widget build(BuildContext context) {
    final strokes = <List<Offset>>[];
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      for (final rawStroke in decoded['strokes'] as List<dynamic>? ?? const []) {
        final stroke = <Offset>[];
        for (final rawPoint in rawStroke as List<dynamic>) {
          final point = rawPoint as List<dynamic>;
          stroke.add(Offset(
            (point[0] as num).toDouble() / 1000,
            (point[1] as num).toDouble() / 400,
          ));
        }
        if (stroke.length > 1) strokes.add(stroke);
      }
    } on Object {
      // Leave preview blank if an old/invalid payload is loaded.
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _NormalizedSignaturePainter(strokes)),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF11243E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

class _NormalizedSignaturePainter extends CustomPainter {
  _NormalizedSignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = medqurInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx * size.width, stroke[i].dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NormalizedSignaturePainter oldDelegate) => false;
}
