import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../generated/prescription_template_data.dart'
    show kPrescriptionTemplatePngBase64;

/// Returns the embedded SRHA/MRH prescription form as a conventional RGBA PNG.
///
/// The source is an aggressively compact 1-bit PNG. Different PNG decoders can
/// expose that monochrome form as RGB, as an alpha mask, or as RGB plus a
/// transparency key. A naive alpha composite can therefore erase every printed
/// line and leave a completely white page. This normalizer evaluates the
/// plausible monochrome interpretations and chooses the one that actually looks
/// like white prescription paper containing sparse dark printed ink.
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
    var alphaMax = 0.0;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final p = decoded.getPixel(x, y);
        rgbMax = _max4(
          rgbMax,
          p.r.toDouble(),
          p.g.toDouble(),
          p.b.toDouble(),
        );
        if (p.a.toDouble() > alphaMax) alphaMax = p.a.toDouble();
      }
    }

    final rgbScale = _rangeScale(rgbMax);
    final alphaScale = _rangeScale(alphaMax);

    final candidates = <_TemplateCandidate>[];
    for (final mode in _TemplateMode.values) {
      candidates.add(
        _analyse(
          decoded,
          mode: mode,
          invert: false,
          rgbScale: rgbScale,
          alphaScale: alphaScale,
        ),
      );
      candidates.add(
        _analyse(
          decoded,
          mode: mode,
          invert: true,
          rgbScale: rgbScale,
          alphaScale: alphaScale,
        ),
      );
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final selected = candidates.first;

    // Never silently publish another empty/solid placeholder. If none of the
    // decoder interpretations contains both light paper and printed structure,
    // fail loudly so CI catches the form asset before it reaches clinicians.
    if (!selected.plausible) {
      throw const FormatException(
        'The embedded prescription form decoded without usable printed content.',
      );
    }

    final normalized = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 4,
    );
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final rgb = _pixel(
          decoded.getPixel(x, y),
          mode: selected.mode,
          invert: selected.invert,
          rgbScale: rgbScale,
          alphaScale: alphaScale,
        );
        normalized.setPixelRgba(x, y, rgb.$1, rgb.$2, rgb.$3, 255);
      }
    }

    final result = Uint8List.fromList(img.encodePng(normalized, level: 6));
    _cache = result;
    return result;
  }

  static _TemplateCandidate _analyse(
    img.Image decoded, {
    required _TemplateMode mode,
    required bool invert,
    required double rgbScale,
    required double alphaScale,
  }) {
    var light = 0;
    var nonWhite = 0;
    var dark = 0;
    var minLuminance = 255.0;
    var maxLuminance = 0.0;
    final total = decoded.width * decoded.height;

    // Inspect all pixels. Printed rules and small type in this form can be only
    // one pixel thick; coarse sampling was the reason earlier validation missed
    // the real form content.
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final rgb = _pixel(
          decoded.getPixel(x, y),
          mode: mode,
          invert: invert,
          rgbScale: rgbScale,
          alphaScale: alphaScale,
        );
        final luminance = .299 * rgb.$1 + .587 * rgb.$2 + .114 * rgb.$3;
        if (luminance > 245) light++;
        if (luminance < 250) nonWhite++;
        if (luminance < 180) dark++;
        if (luminance < minLuminance) minLuminance = luminance;
        if (luminance > maxLuminance) maxLuminance = luminance;
      }
    }

    final lightRatio = light / total;
    final nonWhiteRatio = nonWhite / total;
    final darkRatio = dark / total;
    final contrast = maxLuminance - minLuminance;
    final plausible = lightRatio > .45 &&
        nonWhiteRatio > .001 &&
        nonWhiteRatio < .50 &&
        darkRatio > .0005 &&
        contrast > 12;

    // Prescription paper should be mostly light, with a meaningful but sparse
    // amount of dark typography/rules and strong tonal contrast. The score makes
    // an all-white or all-black candidate lose to the real form interpretation.
    var score = lightRatio * 3.0;
    score += (nonWhiteRatio * 25).clamp(0.0, 1.5);
    score += (darkRatio * 45).clamp(0.0, 1.2);
    score += (contrast / 255).clamp(0.0, 1.0);
    if (nonWhiteRatio > .38) score -= (nonWhiteRatio - .38) * 8;
    if (nonWhiteRatio <= .001 || contrast <= 12) score -= 3;

    return _TemplateCandidate(
      mode: mode,
      invert: invert,
      score: score,
      plausible: plausible,
    );
  }

  static (int, int, int) _pixel(
    img.Pixel pixel, {
    required _TemplateMode mode,
    required bool invert,
    required double rgbScale,
    required double alphaScale,
  }) {
    final rawR = _to8Bit(pixel.r.toDouble() * rgbScale);
    final rawG = _to8Bit(pixel.g.toDouble() * rgbScale);
    final rawB = _to8Bit(pixel.b.toDouble() * rgbScale);
    final alpha = _to8Bit(pixel.a.toDouble() * alphaScale);

    int r;
    int g;
    int b;
    switch (mode) {
      case _TemplateMode.rgbIgnoringAlpha:
        // Critical fallback for 1-bit PNGs where the black form strokes carry
        // a transparency key. Compositing those pixels first would erase them.
        r = rawR;
        g = rawG;
        b = rawB;
      case _TemplateMode.rgbComposite:
        final opacity = alpha / 255.0;
        r = _to8Bit(rawR * opacity + 255 * (1 - opacity));
        g = _to8Bit(rawG * opacity + 255 * (1 - opacity));
        b = _to8Bit(rawB * opacity + 255 * (1 - opacity));
      case _TemplateMode.alphaHighIsInk:
        final value = 255 - alpha;
        r = value;
        g = value;
        b = value;
      case _TemplateMode.alphaLowIsInk:
        r = alpha;
        g = alpha;
        b = alpha;
    }

    if (invert) {
      r = 255 - r;
      g = 255 - g;
      b = 255 - b;
    }
    return (r, g, b);
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

enum _TemplateMode {
  rgbIgnoringAlpha,
  rgbComposite,
  alphaHighIsInk,
  alphaLowIsInk,
}

class _TemplateCandidate {
  const _TemplateCandidate({
    required this.mode,
    required this.invert,
    required this.score,
    required this.plausible,
  });

  final _TemplateMode mode;
  final bool invert;
  final double score;
  final bool plausible;
}
