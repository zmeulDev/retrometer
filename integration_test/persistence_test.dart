import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:retrometer/competition_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Finder for the first [TextField] inside the currently open modal bottom
  /// sheet (the editor sheet).
  Finder firstTextFieldInSheet() => find
      .descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      )
      .first;

  testWidgets('persistence: a created competition survives an app restart',
      (WidgetTester tester) async {
    // First launch: create a competition (writes retrometer.competitions).
    await pumpRetrometer(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.event_note));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(firstTextFieldInSheet(), 'Persist');
    await tester.scrollUntilVisible(
      find.text('Salvează'),
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Salvează'));
    await tester.pumpAndSettle();
    expect(find.text('Persist'), findsOneWidget);

    // The competition was persisted to SharedPreferences (the notifier's
    // _persist writes on every mutation).
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('retrometer.competitions');
    expect(encoded, isNotNull);
    expect(encoded, contains('Persist'));

    // Simulate a cold restart: a brand-new ProviderContainer (no inherited
    // in-memory state) rehydrates competitionsProvider from SharedPreferences
    // alone. If the JSON round-trip works, "Persist" comes back.
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    final rehydrated = await restarted.read(competitionsProvider.future);
    expect(rehydrated, hasLength(1));
    expect(rehydrated.single.name, 'Persist');
  });
}