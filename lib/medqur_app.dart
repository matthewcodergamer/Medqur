import 'package:flutter/material.dart';

import 'mock_data.dart';
import 'models.dart';
import 'screens/clinical_shell_v2.dart';
import 'screens/facility_screen.dart';
import 'screens/sign_in_screen.dart';
import 'services/patient_store.dart';
import 'services/realtime_sync.dart';
import 'widgets/common.dart';

class MedqurApp extends StatefulWidget {
  const MedqurApp({super.key});

  @override
  State<MedqurApp> createState() => _MedqurAppState();
}

class _MedqurAppState extends State<MedqurApp> {
  StaffProfile? _staff;
  Facility? _facility;
  final PatientStore _patientStore = PatientStore();
  final ClinicalSyncGateway _syncGateway = const DisconnectedClinicalSyncGateway();
  List<Patient>? _patients;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final stored = await _patientStore.load();
    final patients = stored ?? buildDemoPatients();
    if (stored == null) await _patientStore.save(patients);
    if (!mounted) return;
    setState(() => _patients = patients);
  }

  Future<void> _persistPatients() async {
    final patients = _patients;
    if (patients == null) return;
    await _patientStore.save(patients);
    await _syncGateway.publishPatients(patients);
  }

  ThemeData _theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: medqurBlue,
        brightness: Brightness.light,
        surface: Colors.white,
      ).copyWith(
        primary: medqurBlue,
        onPrimary: Colors.white,
        secondary: medqurNavy,
        surface: Colors.white,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF8FAFD),
        surfaceContainer: const Color(0xFFF3F6FA),
        outline: medqurLine,
        error: medqurRed,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF6F8FB),
      splashFactory: InkSparkle.splashFactory,
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          color: medqurInk,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.15,
          height: 1.08,
        ),
        headlineSmall: const TextStyle(
          color: medqurInk,
          fontSize: 27,
          fontWeight: FontWeight.w800,
          letterSpacing: -.75,
          height: 1.12,
        ),
        titleLarge: const TextStyle(
          color: medqurInk,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -.35,
        ),
        titleMedium: const TextStyle(
          color: medqurInk,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -.12,
        ),
        bodyLarge: const TextStyle(
          color: Color(0xFF43546A),
          fontSize: 15.5,
          fontWeight: FontWeight.w400,
          height: 1.38,
        ),
        bodyMedium: const TextStyle(
          color: Color(0xFF5D6C7E),
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.38,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -.08,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: medqurInk,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: medqurInk,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.white,
        indicatorColor: const Color(0xFFE7EFFF),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? medqurBlue : const Color(0xFF657286),
            size: 23,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? medqurInk : const Color(0xFF657286),
            fontSize: 10.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        labelStyle: const TextStyle(color: Color(0xFF68778A), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF9AA6B6), fontSize: 13),
        prefixIconColor: const Color(0xFF65748A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: medqurLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: medqurLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: medqurBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: medqurRed),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: medqurBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: medqurNavy,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: Color(0xFFCAD4E2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: medqurBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFE8F0FF),
        side: const BorderSide(color: Color(0xFFD7DFEA)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(color: medqurInk, fontSize: 12, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        showDragHandle: true,
      ),
      dividerTheme: const DividerThemeData(color: medqurLine, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: medqurBlue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medqur',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _buildStage(),
      ),
    );
  }

  Widget _buildStage() {
    if (_patients == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MedqurLogo(width: 166),
                SizedBox(height: 18),
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
              ],
            ),
          ),
        ),
      );
    }
    if (_staff == null) {
      return SignInScreen(
        key: const ValueKey('signin-v3'),
        onSignedIn: (staff) => setState(() => _staff = staff),
      );
    }
    if (_facility == null) {
      return FacilityScreen(
        key: const ValueKey('facility-v3'),
        staff: _staff!,
        onBack: () => setState(() => _staff = null),
        onStartShift: (facility) => setState(() => _facility = facility),
      );
    }
    return ClinicalShellV2(
      key: const ValueKey('shell-v3'),
      staff: _staff!,
      facility: _facility!,
      patients: _patients!,
      onPatientsChanged: _persistPatients,
      onEndShift: () => setState(() => _facility = null),
    );
  }
}
