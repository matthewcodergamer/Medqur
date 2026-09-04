import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../generated/prescription_template_data.dart'
    show kPrescriptionTemplatePngBase64;

/// Returns the embedded SRHA/MRH prescription form as a conventional RGBA PNG.
///
/// The compact source is line-wrapped base64 and uses a very small monochrome
/// PNG representation. Depending on the decoder, that source may expose its
/// paper/ink information through 1-bit RGB values, an alpha mask, or an indexed
/// palette. This normalizer converts all of those cases to an ordinary black-on-
/// white 8-bit RGBA image so Flutter web, native Flutter and the PDF renderer see
/// the same prescription form instead of a grey/black placeholder.
abstract final class PrescriptionTemplateImage {
  static Uint8List? _cache;

  static Uint8List bytes() {
    final cached = _cache;
    if (cached != null) return cached;

    final encoded = kPrescriptionTemplatePngBase64.replaceAll(
      RegExp(r'\s+'),
      '',
    );
    final compact = Uint8List.fromList(base64Decode(encoded));
    final decoded = img.decodeImage(compact);
    if (decoded == null) {
      throw const FormatException(
        'The embedded prescription form could not be decoded.',
      );
    }

    var rgbMax = 0.0;
    var alphaMin = double.infinity;
    var alphaMax = 0.0;
    for (var y = 0; y < decoded.height; y += 8) {
      for (var x = 0; x < decoded.width; x += 8) {
        final p = decoded.getPixel(x, y);
        rgbMax = _max4(
          rgbMax,
          p.r.toDouble(),
          p.g.toDouble(),
          p.b.toDouble(),
        );
        final alpha = p.a.toDouble();
        if (alpha < alphaMin) alphaMin = alpha;
        if (alpha > alphaMax) alphaMax = alpha;
      }
    }

    final rgbScale = _rangeScale(rgbMax);
    final alphaScale = _rangeScale(alphaMax);

    // Some ultra-compact monochrome PNGs store a solid black RGB value and use
    // alpha only as the ink mask. In that case a direct RGB copy produces one
    // giant black rectangle. Treat transparent/low-alpha pixels as white paper
    // and opaque/high-alpha pixels as black ink instead.
    final alphaCarriesInk = rgbMax <= 0.5 && alphaMax > alphaMin;

    List<int> compositePixel(img.Pixel pixel) {
      if (alphaCarriesInk) {
        final alpha = _to8Bit(pixel.a.toDouble() * alphaScale);
        final paper = 255 - alpha;
        return [paper, paper, paper];
      }

      final r = _to8Bit(pixel.r.toDouble() * rgbScale);
      final g = _to8Bit(pixel.g.toDouble() * rgbScale);
      final b = _to8Bit(pixel.b.toDouble() * rgbScale);
      final a = _to8Bit(pixel.a.toDouble() * alphaScale);

      if (a >= 255) return [r, g, b];
      final opacity = a / 255.0;
      return [
        _to8Bit(r * opacity + 255 * (1 - opacity)),
        _to8Bit(g * opacity + 255 * (1 - opacity)),
        _to8Bit(b * opacity + 255 * (1 - opacity)),
      ];
    }

    // The intended form is light paper with dark printed lines. If the compact
    // palette was decoded backwards, flip it after alpha compositing.
    var lightSamples = 0;
    var darkSamples = 0;
    for (var y = 0; y < decoded.height; y += 8) {
      for (var x = 0; x < decoded.width; x += 8) {
        final rgb = compositePixel(decoded.getPixel(x, y));
        final luminance = (rgb[0] + rgb[1] + rgb[2]) / 3;
        if (luminance >= 128) {
          lightSamples++;
        } else {
          darkSamples++;
        }
      }
    }
    final invert = darkSamples > lightSamples;

    final normalized = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 4,
    );
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final rgb = compositePixel(decoded.getPixel(x, y));
        var r = rgb[0];
        var g = rgb[1];
        var b = rgb[2];
        if (invert) {
          r = 255 - r;
          g = 255 - g;
          b = 255 - b;
        }
        normalized.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    final result = Uint8List.fromList(img.encodePng(normalized, level: 6));
    _cache = result;
    return result;
  }

  static double _rangeScale(double maxValue) {
    if (maxValue <= 1.5) return 255.0;
    if (maxValue <= 15.5) return 17.0;
    if (maxValue <= 31.5) return 255.0 / 31.0;
    if (maxValue <= 63.5) return 255.0 / 63.0;
    return 1.0;
  }

  static int _to8Bit(double value) => value.round().clamp(0, 255).toInt();

  static double _max4(double a, double b, double c, double d) {
    var result = a;
    if (b > result) result = b;
    if (c > result) result = c;
    if (d > result) result = d;
    return result;
  }
}
