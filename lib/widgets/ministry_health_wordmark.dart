import 'package:flutter/material.dart';

/// Clean vector reconstruction of the Ministry of Health & Wellness emblem.
///
/// The previous raster asset showed corruption/glitch lines in Safari. This
/// painter uses the Ministry's recognizable green heart/ECG + yellow figure
/// treatment directly in Flutter, so there is no browser-decoded PNG to tear,
/// stretch, or display with damaged scan lines.
class MinistryHealthEmblem extends StatelessWidget {
  const MinistryHealthEmblem({
    super.key,
    this.width = 132,
    this.height,
  });

  final double width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height ?? width * .70,
      child: const CustomPaint(
        painter: _MinistryHealthEmblemPainter(),
      ),
    );
  }
}

class MinistryHealthWordmark extends StatelessWidget {
  const MinistryHealthWordmark({
    super.key,
    this.width = 320,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * .31;
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MinistryHealthEmblem(
            width: width * .38,
            height: height,
          ),
          SizedBox(width: width * .025),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: const SizedBox(
                width: 300,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'M I N I S T R Y   O F',
                      maxLines: 1,
                      style: TextStyle(
                        color: Color(0xFF211F1E),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'HEALTH &',
                      maxLines: 1,
                      style: TextStyle(
                        color: Color(0xFF211F1E),
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: .92,
                        letterSpacing: -1.1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'WELLNESS',
                      maxLines: 1,
                      style: TextStyle(
                        color: Color(0xFF211F1E),
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: .92,
                        letterSpacing: -1.1,
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

class _MinistryHealthEmblemPainter extends CustomPainter {
  const _MinistryHealthEmblemPainter();

  static const _green = Color(0xFF119447);
  static const _yellow = Color(0xFFFFBB16);
  static const _black = Color(0xFF171717);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final heartPaint = Paint()
      ..color = _green
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .065
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final heart = Path()
      ..moveTo(w * .50, h * .91)
      ..cubicTo(w * .39, h * .82, w * .07, h * .61, w * .07, h * .31)
      ..cubicTo(w * .07, h * .12, w * .22, h * .05, w * .36, h * .10)
      ..cubicTo(w * .44, h * .13, w * .49, h * .20, w * .51, h * .25)
      ..cubicTo(w * .55, h * .18, w * .62, h * .10, w * .72, h * .09)
      ..cubicTo(w * .88, h * .07, w * .96, h * .19, w * .94, h * .35)
      ..cubicTo(w * .91, h * .58, w * .71, h * .77, w * .50, h * .91);
    canvas.drawPath(heart, heartPaint);

    final ecgPaint = Paint()
      ..color = _black
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .025
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final ecg = Path()
      ..moveTo(w * .11, h * .44)
      ..lineTo(w * .22, h * .44)
      ..lineTo(w * .27, h * .36)
      ..lineTo(w * .34, h * .55)
      ..lineTo(w * .40, h * .22)
      ..lineTo(w * .46, h * .56)
      ..lineTo(w * .53, h * .38)
      ..lineTo(w * .59, h * .44)
      ..lineTo(w * .67, h * .44);
    canvas.drawPath(ecg, ecgPaint);

    final figurePaint = Paint()
      ..color = _yellow
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(w * .79, h * .24),
      w * .058,
      figurePaint,
    );

    final figure = Path()
      ..moveTo(w * .91, h * .34)
      ..cubicTo(w * .82, h * .36, w * .73, h * .40, w * .66, h * .49)
      ..cubicTo(w * .60, h * .57, w * .56, h * .69, w * .48, h * .83)
      ..cubicTo(w * .57, h * .76, w * .66, h * .70, w * .72, h * .62)
      ..cubicTo(w * .79, h * .52, w * .84, h * .42, w * .91, h * .34)
      ..close();
    canvas.drawPath(figure, figurePaint);

    final yellowSweep = Path()
      ..moveTo(w * .84, h * .45)
      ..cubicTo(w * .76, h * .54, w * .69, h * .66, w * .65, h * .80)
      ..cubicTo(w * .62, h * .89, w * .56, h * .94, w * .51, h * .97)
      ..cubicTo(w * .62, h * .93, w * .73, h * .86, w * .78, h * .75)
      ..cubicTo(w * .83, h * .64, w * .86, h * .54, w * .84, h * .45)
      ..close();
    canvas.drawPath(yellowSweep, figurePaint);

    final blackSweep = Path()
      ..moveTo(w * .76, h * .65)
      ..cubicTo(w * .70, h * .73, w * .64, h * .84, w * .62, h * .94)
      ..cubicTo(w * .60, h * .98, w * .57, h * .99, w * .54, h * .99)
      ..cubicTo(w * .61, h * .94, w * .68, h * .87, w * .72, h * .79)
      ..cubicTo(w * .76, h * .72, w * .78, h * .68, w * .76, h * .65)
      ..close();
    canvas.drawPath(blackSweep, Paint()..color = _black);
  }

  @override
  bool shouldRepaint(covariant _MinistryHealthEmblemPainter oldDelegate) =>
      false;
}
