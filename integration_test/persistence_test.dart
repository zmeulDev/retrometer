import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:retrometer/widgets/editor_sheet.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Finder for the first [TextField] inside the currently open full-screen
  /// editor page (the name field). The page is scrollable, so [enterText]
  /// works even when the field is off-screen.
  Finder firstTextFieldInEditor() => find
      .descendant(
        of: find.byType(EditorPageScaffold),
        matching: find.byType(TextField),
      )
      .first;

  testWidgets('persistence: a created competition survives an app restart',
      (WidgetTester tester) async {
    // First launch: create a competition (the notifier persists it to the
    // per-pump SQLite test DB).
    await pumpRetrometer(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.event_note));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(firstTextFieldInEditor(), 'Persist');
    // Save is always visible in the sticky bottom bar of the full-screen editor.
    await tester.tap(find.text('Salvează'));
    await tester.pumpAndSettle();
    expect(find.text('Persist'), findsOneWidget);

    // Simulate a cold restart: re-pump against the SAME test DB (resetDb: false)
    // so the fresh ProviderScope rehydrates competitionsProvider from SQLite
    // alone. If the round-trip works, "Persist" comes back.
    await pumpRetrometer(tester, resetDb: false, resetPrefs: false);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('Persist'), findsOneWidget);
  });
}