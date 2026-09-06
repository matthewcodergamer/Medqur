import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medqur/mock_data.dart';
import 'package:medqur/screens/clinical_worklist_page.dart';
import 'package:medqur/screens/doctor_orders_hub_page.dart';
import 'package:medqur/screens/facility_screen.dart';
import 'package:medqur/screens/home_dashboard_page.dart';
import 'package:medqur/screens/patient_queue_page.dart';
import 'package:medqur/widgets/common.dart';
import 'package:medqur/widgets/medqur_design.dart';
import 'package:medqur/widgets/medqur_responsive.dart';

Future<void> _setViewport(
  WidgetTester tester,
  double width,
  double height,
) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SafeArea(child: child)),
    );

void main() {
  group('responsive primitives', () {
    for (final width in <double>[320, 360, 390, 768, 1024, 1440]) {
      testWidgets('core cards do not overflow at ${width.toInt()}px',
          (tester) async {
        await _setViewport(tester, width, 900);
        await tester.pumpWidget(
          _host(
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const MedqurPageHeader(
                      eyebrow: 'Medical Officer • active shift',
                      title: 'Good morning, Dr. Maya Brown',
                      subtitle:
                          'Mandeville Regional Hospital • Type B hospital',
                      trailing: StatusPill(
                        label: 'Online',
                        color: medqurGreen,
                        icon: Icons.cloud_done_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    MedqurActionCard(
                      icon: Icons.medication_outlined,
                      title: 'Prescriptions and medication orders',
                      subtitle:
                          'Create, sign and review structured medication orders without filling the screen with helper copy.',
                      badge: '12',
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    const SectionTitle(
                      'Encounter timeline',
                      trailing: StatusPill(
                        label: '24-hour clock',
                        color: medqurBlue,
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ResponsiveFields(
                      minFieldWidth: 170,
                      children: [
                        TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'Dose amount'),
                        ),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Unit with a longer label',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('real screens', () {
    for (final width in <double>[320, 390, 768, 1440]) {
      testWidgets('dashboard fits ${width.toInt()}px viewport', (tester) async {
        await _setViewport(tester, width, 900);
        await tester.pumpWidget(
          _host(
            HomeDashboardPage(
              staff: demoDoctor,
              facility: facilities.first,
              patients: buildDemoPatients(),
              onPatients: () {},
              onScan: () {},
              onMedications: () {},
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('facility picker fits ${width.toInt()}px viewport',
          (tester) async {
        await _setViewport(tester, width, 900);
        await tester.pumpWidget(
          MaterialApp(
            home: FacilityScreen(
              staff: demoDoctor,
              onBack: () {},
              onStartShift: (_) {},
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    for (final width in <double>[320, 390, 1440]) {
      testWidgets('patient queue fits ${width.toInt()}px viewport',
          (tester) async {
        await _setViewport(tester, width, 900);
        await tester.pumpWidget(
          _host(
            PatientQueuePage(
              staff: demoDoctor,
              patients: buildDemoPatients(),
              onOpenPatient: (_) {},
              onNewEncounter: () {},
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('doctor orders fits ${width.toInt()}px viewport',
          (tester) async {
        await _setViewport(tester, width, 900);
        await tester.pumpWidget(
          _host(
            DoctorOrdersHubPage(
              staff: demoDoctor,
              patients: buildDemoPatients(),
              diagnosticOrders: const [],
              onOpenPatient: (_) {},
              onCreatePrescription: () {},
              onCreateDiagnosticOrder: () {},
              onOpenDiagnosticOrder: (_) {},
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('clinical worklist fits ${width.toInt()}px viewport',
          (tester) async {
        await _setViewport(tester, width, 900);
        await tester.pumpWidget(
          _host(
            ClinicalWorklistPage(
              staff: demoNurse,
              patients: buildDemoPatients(),
              orders: const [],
              onOpenPatient: (_) {},
              onOpenOrder: (_) {},
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
