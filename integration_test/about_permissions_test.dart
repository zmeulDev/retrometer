import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('about: version + nav rows; permissions screen shows live GPS',
      (WidgetTester tester) async {
    await pumpRetrometer(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Open the About screen from the cockpit top bar (ℹ button).
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.text('Despre aplicație'), findsOneWidget);
    expect(find.text('Retrometer'), findsOneWidget);
    expect(find.textContaining('Versiune'), findsOneWidget);
    expect(find.text('Ghid de utilizare'), findsOneWidget);
    expect(find.text('Politică de confidențialitate'), findsOneWidget);
    expect(find.text('Permisiuni'), findsOneWidget);

    // Open the Permissions screen.
    await tester.tap(find.text('Permisiuni'));
    await tester.pumpAndSettle();
    expect(find.text('Permisiuni'), findsOneWidget);
    expect(find.text('Locație (GPS)'), findsOneWidget);
    expect(find.text('Vibrație'), findsOneWidget);
    expect(find.text('Ecran aprins'), findsOneWidget);
    // The fake GPS reports while-in-use + service enabled.
    expect(find.text('Acordată · în folosire'), findsOneWidget);
  });
}