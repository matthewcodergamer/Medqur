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
  final ClinicalSyncGateway _syncGateway =
      const DisconnectedClinicalSyncGateway();
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
      fontFamily: 'Inter',
      fontFamilyFallback: const [
        'SF Pro Text',
        'Segoe UI',
        'Roboto',
        'Arial',
      ],
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
        surfaceContainerLow: const Color(0xFFFAFBFC),
        surfaceContainer: const Color(0xFFF4F6F8),
        outline: medqurLine,
        error: medqurRed,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      splashFactory: InkRipple.splashFactory,
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          color: medqurInk,
          fontSize: 29,
          fontWeight: FontWeight.w700,
          letterSpacing: -.72,
          height: 1.08,
        ),
        headlineSmall: const TextStyle(
          color: medqurInk,
          fontSize: 23,
          fontWeight: FontWeight.w700,
          letterSpacing: -.48,
          height: 1.12,
        ),
        titleLarge: const TextStyle(
          color: medqurInk,
          fontSize: 18.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
        ),
        titleMedium: const TextStyle(
          color: medqurInk,
          fontSize: 14.75,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(
          color: Color(0xFF44515F),
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.38,
        ),
        bodyMedium: const TextStyle(
          color: Color(0xFF626E7B),
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.38,
        ),
        labelLarge: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: -.02,
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
          fontSize: 16.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -.15,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 62,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.white,
        indicatorColor: const Color(0xFFF0F3F6),
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? medqurNavy
                : const Color(0xFF737E8A),
            size: 21,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? medqurInk
                : const Color(0xFF737E8A),
            fontSize: 9.75,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        labelStyle:
            const TextStyle(color: Color(0xFF6D7885), fontSize: 12.25),
        hintStyle:
            const TextStyle(color: Color(0xFF9CA4AE), fontSize: 12.25),
        prefixIconColor: const Color(0xFF707B88),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: medqurLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: medqurLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: medqurBlue, width: 1.25),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: medqurRed),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: medqurBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 47),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: medqurNavy,
          minimumSize: const Size(0, 46),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFD5DAE0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.75),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: medqurBlue,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.25,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFF0F3F6),
        side: const BorderSide(color: Color(0xFFDDE1E6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        labelStyle: const TextStyle(
          color: medqurInk,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        showDragHandle: true,
      ),
      dividerTheme: const DividerThemeData(
        color: medqurLine,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: medqurBlue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medqur',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 190),
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
                MedqurLogo(width: 148),
                SizedBox(height: 15),
                SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_staff == null) {
      return SignInScreen(
        key: const ValueKey('signin-v5'),
        onSignedIn: (staff) => setState(() => _staff = staff),
      );
    }
    if (_facility == null) {
      return FacilityScreen(
        key: const ValueKey('facility-v5'),
        staff: _staff!,
        onBack: () => setState(() => _staff = null),
        onStartShift: (facility) => setState(() => _facility = facility),
      );
    }
    return ClinicalShellV2(
      key: const ValueKey('shell-v5'),
      staff: _staff!,
      facility: _facility!,
      patients: _patients!,
      onPatientsChanged: _persistPatients,
      onEndShift: () => setState(() => _facility = null),
    );
  }
}
