import 'package:flutter_test/flutter_test.dart';
import 'package:medqur/main.dart';

void main() {
  testWidgets('Medqur sign-in screen renders', (tester) async {
    await tester.pumpWidget(const MedqurApp());
    await tester.pumpAndSettle();

    expect(find.text('Secure staff access'), findsOneWidget);
    expect(find.textContaining('CONCEPT PROTOTYPE'), findsOneWidget);
  });
}
