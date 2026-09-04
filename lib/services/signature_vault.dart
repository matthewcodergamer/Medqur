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
  static Future<Uint8List> fromPaperPhoto(
    Uint8List sourceBytes, {
    PrescriptionInk ink = PrescriptionInk.blue,
  }) async {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('The signature photo could not be decoded.');
    }
    var source = img.bakeOrientation(decoded);
    if (source.width > 1800) {
      source = img.copyResize(source, width: 1800, interpolation: img.Interpolation.average);
    }

    var minX = source.width;
    var minY = source.height;
    var maxX = -1;
    var maxY = -1;

    bool isInk(img.Pixel p) {
      final r = p.r.toDouble();
      final g = p.g.toDouble();
      final b = p.b.toDouble();
      final luminance = (0.299 * r) + (0.587 * g) + (0.114 * b);
      final bluePen = b > r + 10 && b > g + 4 && luminance < 225;
      return luminance < 178 || bluePen;
    }

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        if (!isInk(source.getPixel(x, y))) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < minX || maxY < minY) {
      throw const FormatException(
        'No clear pen strokes were detected. Use plain white paper and good lighting.',
      );
    }

    const padding = 24;
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

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final p = source.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        final luminance = (0.299 * r) + (0.587 * g) + (0.114 * b);
        final bluePen = b > r + 10 && b > g + 4 && luminance < 230;
        final strength = bluePen
            ? ((235 - luminance) * 2.8)
            : ((205 - luminance) * 4.0);
        final alpha = strength.clamp(0, 255).round();
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
      result = img.copyResize(result, width: 1100, interpolation: img.Interpolation.average);
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
