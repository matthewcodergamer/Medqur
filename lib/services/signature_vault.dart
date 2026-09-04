import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

enum PrescriptionInk { blue, black }

extension PrescriptionInkInfo on PrescriptionInk {
  String get label => this == PrescriptionInk.blue ? 'Blue pen' : 'Black pen';

  int get argb => this == PrescriptionInk.blue ? 0xFF154AA6 : 0xFF17202B;

  String get storageValue => name;
}

enum DoctorSignatureSource { drawn, paperPhoto }

class StoredDoctorSignature {
  const StoredDoctorSignature({
    required this.id,
    required this.label,
    required this.source,
    required this.imageBase64,
    required this.createdAt,
    required this.ink,
    this.vectorPayload,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final DoctorSignatureSource source;
  final String imageBase64;
  final DateTime createdAt;
  final PrescriptionInk ink;
  final String? vectorPayload;
  final bool isDefault;

  Uint8List get imageBytes => Uint8List.fromList(base64Decode(imageBase64));

  StoredDoctorSignature copyWith({
    String? label,
    bool? isDefault,
  }) =>
      StoredDoctorSignature(
        id: id,
        label: label ?? this.label,
        source: source,
        imageBase64: imageBase64,
        createdAt: createdAt,
        ink: ink,
        vectorPayload: vectorPayload,
        isDefault: isDefault ?? this.isDefault,
      );

  Map<String, dynamic> toJson() => {
        'v': 1,
        'id': id,
        'label': label,
        'source': source.name,
        'imageBase64': imageBase64,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'ink': ink.storageValue,
        'vectorPayload': vectorPayload,
        'isDefault': isDefault,
      };

  factory StoredDoctorSignature.fromJson(Map<String, dynamic> json) {
    final sourceName = json['source']?.toString() ?? '';
    final inkName = json['ink']?.toString() ?? '';
    return StoredDoctorSignature(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Signature',
      source: DoctorSignatureSource.values.firstWhere(
        (item) => item.name == sourceName,
        orElse: () => DoctorSignatureSource.drawn,
      ),
      imageBase64: json['imageBase64']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      ink: PrescriptionInk.values.firstWhere(
        (item) => item.name == inkName,
        orElse: () => PrescriptionInk.blue,
      ),
      vectorPayload: json['vectorPayload']?.toString(),
      isDefault: json['isDefault'] == true,
    );
  }
}

class PreparedPrescriptionSignature {
  const PreparedPrescriptionSignature({
    required this.signature,
    required this.payload,
    required this.digest,
    required this.signedAt,
  });

  final StoredDoctorSignature signature;
  final String payload;
  final String digest;
  final DateTime signedAt;
}

class DoctorSignatureVault {
  static const _prefix = 'medqur_doctor_signature_v2_';

  Future<List<StoredDoctorSignature>> load(String staffId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$staffId');
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return const [];
      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(StoredDoctorSignature.fromJson)
          .where((item) => item.id.isNotEmpty && item.imageBase64.isNotEmpty)
          .toList();
      items.sort((a, b) {
        if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return items;
    } on Object {
      return const [];
    }
  }

  Future<void> save(String staffId, List<StoredDoctorSignature> signatures) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeDefault(signatures);
    await prefs.setString(
      '$_prefix$staffId',
      jsonEncode(normalized.map((item) => item.toJson()).toList()),
    );
  }

  Future<StoredDoctorSignature> add({
    required String staffId,
    required String label,
    required DoctorSignatureSource source,
    required Uint8List imageBytes,
    required PrescriptionInk ink,
    String? vectorPayload,
    bool makeDefault = false,
  }) async {
    final items = (await load(staffId)).toList();
    final now = DateTime.now().toUtc();
    final imageDigest = sha256.convert(imageBytes).toString();
    final id = 'SIG-${now.microsecondsSinceEpoch}-${imageDigest.substring(0, 8)}';
    final signature = StoredDoctorSignature(
      id: id,
      label: label.trim().isEmpty ? 'Signature ${items.length + 1}' : label.trim(),
      source: source,
      imageBase64: base64Encode(imageBytes),
      createdAt: now,
      ink: ink,
      vectorPayload: vectorPayload,
      isDefault: makeDefault || items.isEmpty,
    );
    if (signature.isDefault) {
      for (var i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(isDefault: false);
      }
    }
    items.add(signature);
    await save(staffId, items);
    return signature;
  }

  Future<void> setDefault(String staffId, String signatureId) async {
    final items = (await load(staffId))
        .map((item) => item.copyWith(isDefault: item.id == signatureId))
        .toList();
    await save(staffId, items);
  }

  Future<void> rename(String staffId, String signatureId, String label) async {
    final items = (await load(staffId))
        .map((item) => item.id == signatureId ? item.copyWith(label: label.trim()) : item)
        .toList();
    await save(staffId, items);
  }

  Future<void> delete(String staffId, String signatureId) async {
    final items = (await load(staffId)).where((item) => item.id != signatureId).toList();
    await save(staffId, items);
  }

  PreparedPrescriptionSignature prepare({
    required StoredDoctorSignature signature,
    required String prescriberId,
  }) {
    final usedAt = DateTime.now().toUtc();
    final imageSha = sha256.convert(signature.imageBytes).toString();
    final payload = jsonEncode({
      'v': 2,
      'kind': 'stored-prescriber-signature',
      'signatureId': signature.id,
      'source': signature.source.name,
      'imageSha256': imageSha,
      'prescriberId': prescriberId,
      'usedAt': usedAt.toIso8601String(),
    });
    return PreparedPrescriptionSignature(
      signature: signature,
      payload: payload,
      digest: sha256.convert(utf8.encode(payload)).toString(),
      signedAt: usedAt,
    );
  }

  List<StoredDoctorSignature> _normalizeDefault(List<StoredDoctorSignature> input) {
    if (input.isEmpty) return const [];
    final hasDefault = input.any((item) => item.isDefault);
    var claimed = false;
    return input.map((item) {
      if (hasDefault && item.isDefault && !claimed) {
        claimed = true;
        return item.copyWith(isDefault: true);
      }
      if (!hasDefault && !claimed) {
        claimed = true;
        return item.copyWith(isDefault: true);
      }
      return item.copyWith(isDefault: false);
    }).toList();
  }
}

abstract final class SignatureImageProcessor {
  /// Extracts pen strokes from a photograph of a signature on plain paper.
  ///
  /// The old implementation treated every dark pixel as ink. A shadow, table
  /// edge or unevenly lit paper could therefore become one large opaque blob.
  /// This version estimates the paper brightness in small blocks and only keeps
  /// pixels that are meaningfully darker than their local background (or have a
  /// strong blue-ink colour signal). It also removes isolated camera noise and
  /// rejects captures that still look like a large filled region.
  static Future<Uint8List> fromPaperPhoto(
    Uint8List sourceBytes, {
    PrescriptionInk ink = PrescriptionInk.blue,
  }) async {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('The signature photo could not be decoded.');
    }

    var source = img.bakeOrientation(decoded);
    const maxDimension = 1400;
    if (source.width >= source.height && source.width > maxDimension) {
      source = img.copyResize(
        source,
        width: maxDimension,
        interpolation: img.Interpolation.average,
      );
    } else if (source.height > maxDimension) {
      source = img.copyResize(
        source,
        height: maxDimension,
        interpolation: img.Interpolation.average,
      );
    }

    const blockSize = 36;
    final blocksX = (source.width + blockSize - 1) ~/ blockSize;
    final blocksY = (source.height + blockSize - 1) ~/ blockSize;
    final sums = List<double>.filled(blocksX * blocksY, 0);
    final counts = List<int>.filled(blocksX * blocksY, 0);

    double luminance(img.Pixel p) {
      final r = p.r.toDouble();
      final g = p.g.toDouble();
      final b = p.b.toDouble();
      return (0.299 * r) + (0.587 * g) + (0.114 * b);
    }

    for (var y = 0; y < source.height; y++) {
      final by = y ~/ blockSize;
      for (var x = 0; x < source.width; x++) {
        final bx = x ~/ blockSize;
        final index = by * blocksX + bx;
        sums[index] += luminance(source.getPixel(x, y));
        counts[index]++;
      }
    }

    final backgrounds = List<double>.generate(sums.length, (index) {
      final count = counts[index];
      if (count == 0) return 255;
      // A small lift compensates for dark pen strokes lowering the block mean.
      return (sums[index] / count + 10).clamp(0, 255).toDouble();
    });

    double backgroundAt(int x, int y) {
      final bx = (x ~/ blockSize).clamp(0, blocksX - 1);
      final by = (y ~/ blockSize).clamp(0, blocksY - 1);
      return backgrounds[by * blocksX + bx];
    }

    bool strongInkAt(int x, int y) {
      final p = source.getPixel(x, y);
      final r = p.r.toDouble();
      final g = p.g.toDouble();
      final b = p.b.toDouble();
      final lum = luminance(p);
      final localDrop = backgroundAt(x, y) - lum;
      final blueBias = b - (r > g ? r : g);
      final chromaMax = r > g ? (r > b ? r : b) : (g > b ? g : b);
      final chromaMin = r < g ? (r < b ? r : b) : (g < b ? g : b);
      final chroma = chromaMax - chromaMin;
      final bluePen = blueBias > 10 && chroma > 18 && lum < 238;

      if (bluePen && localDrop >= 10) return true;
      return localDrop >= 36 && lum < 225;
    }

    final pixelCount = source.width * source.height;
    final rawMask = Uint8List(pixelCount);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        if (strongInkAt(x, y)) rawMask[y * source.width + x] = 1;
      }
    }

    // Remove isolated sensor noise while retaining continuous pen strokes.
    final mask = Uint8List(pixelCount);
    for (var y = 1; y < source.height - 1; y++) {
      for (var x = 1; x < source.width - 1; x++) {
        final index = y * source.width + x;
        if (rawMask[index] == 0) continue;
        var neighbours = 0;
        for (var yy = -1; yy <= 1; yy++) {
          for (var xx = -1; xx <= 1; xx++) {
            if (xx == 0 && yy == 0) continue;
            neighbours += rawMask[(y + yy) * source.width + (x + xx)];
          }
        }
        if (neighbours >= 2) mask[index] = 1;
      }
    }

    var minX = source.width;
    var minY = source.height;
    var maxX = -1;
    var maxY = -1;
    var inkPixels = 0;
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        if (mask[y * source.width + x] == 0) continue;
        inkPixels++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    if (inkPixels < 60 || maxX < minX || maxY < minY) {
      throw const FormatException(
        'No clear signature strokes were detected. Fill most of the frame with clean white paper and write the signature in blue or black pen.',
      );
    }

    final boxWidth = maxX - minX + 1;
    final boxHeight = maxY - minY + 1;
    final boxArea = boxWidth * boxHeight;
    final fillRatio = boxArea == 0 ? 1.0 : inkPixels / boxArea;
    final coversMostFrame =
        boxWidth > source.width * .90 && boxHeight > source.height * .90;
    if ((coversMostFrame && fillRatio > .10) || fillRatio > .42) {
      throw const FormatException(
        'Too much dark content was detected. Retake the photo on plain white paper with the camera aimed directly at the signature and avoid shadows, table edges or printed text.',
      );
    }

    const padding = 28;
    minX = (minX - padding).clamp(0, source.width - 1).toInt();
    minY = (minY - padding).clamp(0, source.height - 1).toInt();
    maxX = (maxX + padding).clamp(0, source.width - 1).toInt();
    maxY = (maxY + padding).clamp(0, source.height - 1).toInt();

    final out = img.Image(
      width: maxX - minX + 1,
      height: maxY - minY + 1,
      numChannels: 4,
    );
    final target = ink == PrescriptionInk.blue
        ? const [21, 74, 166]
        : const [23, 32, 43];

    bool hasStrongNeighbour(int x, int y) {
      for (var yy = -1; yy <= 1; yy++) {
        final py = y + yy;
        if (py < 0 || py >= source.height) continue;
        for (var xx = -1; xx <= 1; xx++) {
          final px = x + xx;
          if (px < 0 || px >= source.width) continue;
          if (mask[py * source.width + px] == 1) return true;
        }
      }
      return false;
    }

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final p = source.getPixel(x, y);
        final lum = luminance(p);
        final localDrop = backgroundAt(x, y) - lum;
        final strong = mask[y * source.width + x] == 1;
        final edge = !strong && localDrop >= 18 && hasStrongNeighbour(x, y);
        if (!strong && !edge) {
          out.setPixelRgba(x - minX, y - minY, 0, 0, 0, 0);
          continue;
        }

        final alpha = (localDrop * (strong ? 5.1 : 2.7))
            .clamp(0, 255)
            .round();
        out.setPixelRgba(
          x - minX,
          y - minY,
          target[0],
          target[1],
          target[2],
          alpha,
        );
      }
    }

    var result = out;
    if (result.width > 1100) {
      result = img.copyResize(
        result,
        width: 1100,
        interpolation: img.Interpolation.average,
      );
    }
    return Uint8List.fromList(img.encodePng(result, level: 8));
  }

  static Future<Uint8List> fromVectorPayload(
    String payload, {
    PrescriptionInk ink = PrescriptionInk.blue,
  }) async {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Signature vector data is invalid.');
    }
    final rawStrokes = decoded['strokes'] as List<dynamic>? ?? const [];
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const width = 1000.0;
    const height = 400.0;
    final paint = ui.Paint()
      ..color = ui.Color(ink.argb)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 5.2
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;

    for (final rawStroke in rawStrokes) {
      if (rawStroke is! List<dynamic> || rawStroke.length < 2) continue;
      final path = ui.Path();
      var first = true;
      for (final rawPoint in rawStroke) {
        if (rawPoint is! List<dynamic> || rawPoint.length < 2) continue;
        final x = (rawPoint[0] as num)
            .toDouble()
            .clamp(0.0, 1000.0)
            .toDouble();
        final y = (rawPoint[1] as num)
            .toDouble()
            .clamp(0.0, 400.0)
            .toDouble();
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('Signature preview could not be rendered.');
    }
    return bytes.buffer.asUint8List();
  }
}
