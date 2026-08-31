import 'package:flutter/material.dart';
import 'mock_data.dart';
import 'models.dart';
import 'screens/clinical_shell.dart';
import 'screens/facility_screen.dart';
import 'screens/sign_in_screen.dart';
import 'widgets/common.dart';

class MedqurApp extends StatefulWidget {
  const MedqurApp({super.key});
  @override
  State<MedqurApp> createState() => _MedqurAppState();
}

class _MedqurAppState extends State<MedqurApp> {
  StaffProfile? _staff;
  Facility? _facility;
  late final List<Patient> _patients = buildDemoPatients();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medqur',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: medqurBlue,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: medqurSurface,
        textTheme: const TextTheme(
          displaySmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.1, color: medqurInk),
          headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.5, color: medqurInk),
          titleLarge: TextStyle(fontWeight: FontWeight.w800, color: medqurInk),
          bodyLarge: TextStyle(color: Color(0xFF43546A), height: 1.35),
          bodyMedium: TextStyle(color: Color(0xFF5C6B7D), height: 1.35),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: medqurLine)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: medqurLine)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: medqurBlue, width: 1.5)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: medqurBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _buildStage(),
      ),
    );
  }

  Widget _buildStage() {
    if (_staff == null) {
      return SignInScreen(key: const ValueKey('signin'), onSignedIn: (staff) => setState(() => _staff = staff));
    }
    if (_facility == null) {
      return FacilityScreen(
        key: const ValueKey('facility'),
        staff: _staff!,
        onBack: () => setState(() => _staff = null),
        onStartShift: (facility) => setState(() => _facility = facility),
      );
    }
    return ClinicalShell(
      key: const ValueKey('shell'),
      staff: _staff!,
      facility: _facility!,
      patients: _patients,
      onEndShift: () => setState(() => _facility = null),
    );
  }
}
