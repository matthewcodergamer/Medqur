import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../generated/prescription_template_data.dart'
    show kPrescriptionTemplatePngBase64;

/// Returns the supplied SRHA/MRH prescription form as a conventional opaque
/// RGBA PNG that behaves the same in Flutter web, native Flutter and the PDF
/// renderer.
///
/// The embedded source is deliberately an ordinary 8-bit grayscale PNG. Older
/// revisions used a tiny 1-bit/transparency-masked PNG, which some decoder paths
/// interpreted as a mask and could turn into a blank white page or solid block.
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
    final decoded = img.decodePng(compact);
    if (decoded == null) {
      throw const FormatException(
        'The embedded prescription form could not be decoded.',
      );
    }
    if (decoded.width != 627 || decoded.height != 1114) {
      throw FormatException(
        'Unexpected prescription form dimensions: '
        '${decoded.width}x${decoded.height}.',
      );
    }

    final normalized = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 4,
    );

    var lightPixels = 0;
    var printedPixels = 0;
    var minLuminance = 255.0;
    var maxLuminance = 0.0;

    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final p = decoded.getPixel(x, y);
        final r = _channel8(p.r.toDouble());
        final g = _channel8(p.g.toDouble());
        final b = _channel8(p.b.toDouble());
        final luminance = .299 * r + .587 * g + .114 * b;

        if (luminance > 245) lightPixels++;
        if (luminance < 250) printedPixels++;
        if (luminance < minLuminance) minLuminance = luminance;
        if (luminance > maxLuminance) maxLuminance = luminance;

        // The prescription form itself is white paper. Always emit an opaque
        // image so alpha/transparency handling can never hide the printed form.
        normalized.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    final total = decoded.width * decoded.height;
    final lightRatio = lightPixels / total;
    final contrast = maxLuminance - minLuminance;
    if (printedPixels < 100 || lightRatio < .50 || contrast < 8) {
      throw const FormatException(
        'The embedded prescription form decoded without usable printed content.',
      );
    }

    final result = Uint8List.fromList(img.encodePng(normalized, level: 6));
    _cache = result;
    return result;
  }

  /// `package:image` normally exposes 8-bit PNG channels as 0..255. Retain a
  /// narrow compatibility path for a normalized 0..1 channel representation.
  static int _channel8(double value) {
    if (value >= 0 && value <= 1) {
      return (value * 255).round().clamp(0, 255).toInt();
    }
    return value.round().clamp(0, 255).toInt();
  }
}
