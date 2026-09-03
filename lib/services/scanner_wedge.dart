import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

/// Collects characters from USB/Bluetooth/Zebra/Honeywell scanners configured
/// in keyboard-wedge mode. Most devices terminate a scan with Enter.
///
/// The UI should only enable this collector while a dedicated scan field has
/// focus so normal typing cannot accidentally become a clinical scan.
class ScannerWedgeCollector {
  ScannerWedgeCollector({
    this.timeout = const Duration(milliseconds: 120),
    required this.onScan,
  });

  final Duration timeout;
  final ValueChanged<String> onScan;
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastInputAt;

  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final now = DateTime.now();
    if (_lastInputAt != null && now.difference(_lastInputAt!) > timeout) {
      _buffer.clear();
    }
    _lastInputAt = now;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final value = _buffer.toString().trim();
      _buffer.clear();
      if (value.isNotEmpty) onScan(value);
      return KeyEventResult.handled;
    }

    final character = event.character;
    if (character != null &&
        character.length == 1 &&
        character.codeUnitAt(0) >= 32) {
      _buffer.write(character);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void reset() {
    _buffer.clear();
    _lastInputAt = null;
  }
}
