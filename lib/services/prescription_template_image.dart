import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

/// Loads the supplied SRHA/MRH prescription form as a conventional opaque RGBA
/// PNG that behaves the same in Flutter web, Android, iOS and the PDF renderer.
///
/// The source file is stored as a normal Flutter asset rather than as a giant
/// Dart/base64 constant. The exact form image supplied for the Medqur prototype
/// is decoded, validated and flattened onto opaque white paper before use.
abstract final class PrescriptionTemplateImage {
  static const String assetPath = 'assets/forms/mrh_prescription.png';

  static Future<Uint8List>? _cache;

  static Future<Uint8List> bytes() => _cache ??= _load();

  static Future<Uint8List> _load() async {
    final byteData = await rootBundle.load(assetPath);
    final compact = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    final decoded = img.decodePng(compact);
    if (decoded == null) {
      throw const FormatException(
        'The bundled prescription form could not be decoded.',
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
        'The bundled prescription form decoded without usable printed content.',
      );
    }

    return Uint8List.fromList(img.encodePng(normalized, level: 6));
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
