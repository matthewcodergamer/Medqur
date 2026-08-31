import 'package:flutter/material.dart';

import 'screens/app_router.dart';
import 'state/medqur_controller.dart';
import 'theme/medqur_theme.dart';

void main() {
  runApp(const MedqurApp());
}

class MedqurApp extends StatefulWidget {
  const MedqurApp({super.key});

  @override
  State<MedqurApp> createState() => _MedqurAppState();
}

class _MedqurAppState extends State<MedqurApp> {
  late final MedqurController controller;

  @override
  void initState() {
    super.initState();
    controller = MedqurController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medqur',
      debugShowCheckedModeBanner: false,
      theme: buildMedqurTheme(),
      home: AppRouter(controller: controller),
    );
  }
}
