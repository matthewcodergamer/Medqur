import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Produces prescription-safe signature artwork.
///
/// Paper-photo signatures are first cleaned by [SignatureImageProcessor]. This
/// helper then composites any transparency onto pure white. The MRH
/// prescription form is white, so the result blends into the form while also
/// avoiding browser/PDF alpha-decoding bugs that can display transparent PNGs
/// as dark or grey blocks.
abstract final class SignatureRendering {
  static Uint8List onWhitePaper(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) return sourceBytes;
    final source = img.bakeOrientation(decoded);
    final output = img.Image(
      width: source.width,
      height: source.height,
      numChannels: 4,
    );

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final pixel = source.getPixel(x, y);
        final alpha = pixel.a.toDouble() / 255.0;
        final red = (pixel.r * alpha + 255 * (1 - alpha)).round();
        final green = (pixel.g * alpha + 255 * (1 - alpha)).round();
        final blue = (pixel.b * alpha + 255 * (1 - alpha)).round();
        output.setPixelRgba(x, y, red, green, blue, 255);
      }
    }

    return Uint8List.fromList(img.encodePng(output, level: 8));
  }

  /// A small sanity check used before displaying/printing a stored signature.
  /// It rejects an image that is overwhelmingly dark, which is the visual
  /// failure mode that previously appeared as one large block.
  static bool looksLikeSignature(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null || decoded.width == 0 || decoded.height == 0) {
      return false;
    }
    var dark = 0;
    var sampled = 0;
    final step = (decoded.width > 800 || decoded.height > 800) ? 3 : 1;
    for (var y = 0; y < decoded.height; y += step) {
      for (var x = 0; x < decoded.width; x += step) {
        final p = decoded.getPixel(x, y);
        final luminance = .299 * p.r + .587 * p.g + .114 * p.b;
        final alpha = p.a.toDouble() / 255.0;
        final visibleLuminance = luminance * alpha + 255 * (1 - alpha);
        if (visibleLuminance < 110) dark++;
        sampled++;
      }
    }
    if (sampled == 0) return false;
    final darkRatio = dark / sampled;
    return darkRatio > .001 && darkRatio < .34;
  }
}
