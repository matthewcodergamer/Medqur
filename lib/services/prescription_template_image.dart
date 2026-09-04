import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../generated/prescription_template_data.dart'
    show kPrescriptionTemplatePngBase64;

/// Returns the embedded SRHA/MRH prescription form as a conventional RGBA PNG.
///
/// The compact source is line-wrapped base64 and uses a space-efficient,
/// low-bit-depth PNG pixel format. Some image decoders expose 1-bit channel
/// values as 0/1 rather than expanding them to 0/255. This normalizer detects
/// that channel range, expands it to full 8-bit RGB, fixes an inverted palette
/// when necessary, and emits the same RGBA PNG for Flutter web, native Flutter
/// and the PDF renderer.
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

    // Determine the numeric range exposed by the decoder. Indexed/1-bit PNGs
    // can report channel values as 0/1, which would otherwise become an almost
    // solid black image when copied directly into an 8-bit RGBA image.
    var sampledMax = 0.0;
    for (var y = 0; y < decoded.height; y += 12) {
      for (var x = 0; x < decoded.width; x += 12) {
        final p = decoded.getPixel(x, y);
        sampledMax = _max4(
          sampledMax,
          p.r.toDouble(),
          p.g.toDouble(),
          p.b.toDouble(),
        );
      }
    }

    final scale = sampledMax <= 1.5
        ? 255.0
        : sampledMax <= 15.5
            ? 17.0
            : sampledMax <= 31.5
                ? 255.0 / 31.0
                : sampledMax <= 63.5
                    ? 255.0 / 63.0
                    : 1.0;

    // A prescription form is overwhelmingly light paper with dark ink. If an
    // indexed palette is decoded in reverse, detect that from representative
    // samples and invert during normalization.
    var lightSamples = 0;
    var darkSamples = 0;
    for (var y = 0; y < decoded.height; y += 12) {
      for (var x = 0; x < decoded.width; x += 12) {
        final p = decoded.getPixel(x, y);
        final luminance =
            (p.r.toDouble() + p.g.toDouble() + p.b.toDouble()) / 3 * scale;
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
        final pixel = decoded.getPixel(x, y);
        var r = _to8Bit(pixel.r.toDouble() * scale);
        var g = _to8Bit(pixel.g.toDouble() * scale);
        var b = _to8Bit(pixel.b.toDouble() * scale);
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

  static int _to8Bit(double value) => value.round().clamp(0, 255).toInt();

  static double _max4(double a, double b, double c, double d) {
    var result = a;
    if (b > result) result = b;
    if (c > result) result = c;
    if (d > result) result = d;
    return result;
  }
}
