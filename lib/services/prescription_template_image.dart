import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../generated/prescription_template_data.dart'
    show kPrescriptionTemplatePngBase64;

/// Returns the embedded SRHA/MRH prescription form as a conventional RGBA PNG.
///
/// The compact source is line-wrapped base64 and uses a space-efficient PNG
/// pixel format. Whitespace is removed before decoding, then the image is
/// normalized to four channels so Flutter web, native Flutter and the PDF
/// renderer receive the same predictable image representation.
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

    final normalized = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 4,
    );
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        normalized.setPixelRgba(
          x,
          y,
          pixel.r,
          pixel.g,
          pixel.b,
          255,
        );
      }
    }

    final result = Uint8List.fromList(img.encodePng(normalized, level: 6));
    _cache = result;
    return result;
  }
}
