import 'package:flutter/material.dart';

abstract final class MedqurColors {
  static const primary = Color(0xFF3978E1);
  static const primaryDark = Color(0xFF173F88);
  static const navy = Color(0xFF112B58);
  static const canvas = Color(0xFFF5F8FC);
  static const border = Color(0xFFDCE5F0);
  static const success = Color(0xFF197A55);
  static const warning = Color(0xFFB96A10);
  static const danger = Color(0xFFB43A3A);
  static const inkMuted = Color(0xFF667085);
}

ThemeData buildMedqurTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MedqurColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: MedqurColors.primary,
    onPrimary: Colors.white,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: MedqurColors.canvas,
    fontFamily: 'sans-serif',
    dividerColor: MedqurColors.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MedqurColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MedqurColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MedqurColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: MedqurColors.border),
      ),
    ),
  );
}
