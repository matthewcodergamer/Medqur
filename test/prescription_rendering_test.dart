import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:medqur/services/prescription_template_image.dart';
import 'package:medqur/services/signature_vault.dart';

void main() {
  test('MRH prescription template normalizes to a renderable RGBA PNG', () {
    final bytes = PrescriptionTemplateImage.bytes();
    expect(bytes, isNotEmpty);

    final decoded = img.decodePng(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 371);
    expect(decoded.height, 1114);
    expect(decoded.numChannels, 4);

    var darkPixels = 0;
    var lightPixels = 0;
    for (var y = 0; y < decoded.height; y += 10) {
      for (var x = 0; x < decoded.width; x += 10) {
        final p = decoded.getPixel(x, y);
        final lum = (p.r + p.g + p.b) / 3;
        if (lum < 110) darkPixels++;
        if (lum > 235) lightPixels++;
      }
    }
    expect(darkPixels, greaterThan(20));
    expect(lightPixels, greaterThan(200));
  });

  test('paper signature extraction keeps pen strokes without making a blob', () async {
    final source = img.Image(width: 760, height: 360, numChannels: 3);

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final shade = 250 -
            ((x / source.width) * 16).round() -
            ((y / source.height) * 7).round();
        source.setPixelRgb(x, y, shade, shade, shade);
      }
    }

    for (var y = 260; y < 340; y++) {
      for (var x = 0; x < 760; x++) {
        final p = source.getPixel(x, y);
        final value = (p.r - 18).clamp(0, 255).toInt();
        source.setPixelRgb(x, y, value, value, value);
      }
    }

    final blue = img.ColorRgb8(22, 70, 166);
    img.drawLine(
      source,
      x1: 170,
      y1: 185,
      x2: 255,
      y2: 125,
      color: blue,
      thickness: 6,
    );
    img.drawLine(
      source,
      x1: 255,
      y1: 125,
      x2: 310,
      y2: 205,
      color: blue,
      thickness: 6,
    );
    img.drawLine(
      source,
      x1: 310,
      y1: 205,
      x2: 375,
      y2: 135,
      color: blue,
      thickness: 6,
    );
    img.drawLine(
      source,
      x1: 375,
      y1: 135,
      x2: 480,
      y2: 185,
      color: blue,
      thickness: 6,
    );
    img.drawLine(
      source,
      x1: 215,
      y1: 205,
      x2: 520,
      y2: 210,
      color: blue,
      thickness: 5,
    );

    final output = await SignatureImageProcessor.fromPaperPhoto(
      Uint8List.fromList(img.encodePng(source)),
      ink: PrescriptionInk.blue,
    );
    final cleaned = img.decodePng(output);
    expect(cleaned, isNotNull);
    expect(cleaned!.numChannels, 4);
    expect(cleaned.width, lessThan(source.width));
    expect(cleaned.height, lessThan(source.height));

    var visible = 0;
    final total = cleaned.width * cleaned.height;
    for (var y = 0; y < cleaned.height; y++) {
      for (var x = 0; x < cleaned.width; x++) {
        if (cleaned.getPixel(x, y).a > 30) visible++;
      }
    }
    final fill = visible / total;
    expect(fill, greaterThan(.005));
    expect(fill, lessThan(.24));
  });
}
