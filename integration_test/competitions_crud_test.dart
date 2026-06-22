import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:retrometer/widgets/cards.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Finder for the first [TextField] inside the currently open modal bottom
  /// sheet (the editor sheets). The sheets are scrollable, so [enterText] works
  /// even when the field is off-screen.
  Finder firstTextFieldInSheet() => find
      .descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      )
      .first;

  testWidgets('competitions CRUD: create competition, add/edit/delete stage',
      (WidgetTester tester) async {
    await pumpRetrometer(tester);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Open the competitions screen from the cockpit top bar (📅 button).
    await tester.tap(find.byIcon(Icons.event_note));
    await tester.pumpAndSettle();
    expect(find.text('Competiții'), findsOneWidget);
    expect(find.textContaining('Nicio competiție'), findsOneWidget);

    // Create a competition: + → fill name → Salvează.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Competiție nouă'), findsOneWidget);
    await tester.enterText(firstTextFieldInSheet(), 'Cup Test');
    await tester.scrollUntilVisible(
      find.text('Salvează'),
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Salvează'));
    await tester.pumpAndSettle();

    // The competition tile appears.
    expect(find.text('Cup Test'), findsOneWidget);

    // Open its detail and add a stage.
    await tester.tap(find.text('Cup Test'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Niciun stagiu'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Stage nou'), findsOneWidget);
    await tester.enterText(firstTextFieldInSheet(), 'SS1');
    await tester.scrollUntilVisible(
      find.text('Salvează'),
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Salvează'));
    await tester.pumpAndSettle();
    expect(find.text('SS1'), findsOneWidget);

    // Edit the stage: tap its tile → rename → save.
    await tester.tap(find.text('SS1'));
    await tester.pumpAndSettle();
    expect(find.text('Editare stage'), findsOneWidget);
    await tester.enterText(firstTextFieldInSheet(), 'SS1-editat');
    await tester.scrollUntilVisible(
      find.text('Salvează'),
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Salvează'));
    await tester.pumpAndSettle();
    expect(find.text('SS1-editat'), findsOneWidget);
    expect(find.text('SS1'), findsNothing);

    // Delete the stage via the tile's delete button.
    final stageCard = find.ancestor(
      of: find.text('SS1-editat'),
      matching: find.byType(TappableCard),
    );
    await tester.tap(
      find.descendant(of: stageCard, matching: find.byIcon(Icons.delete_outline)),
    );
    await tester.pumpAndSettle();
    expect(find.text('SS1-editat'), findsNothing);

    // Delete the competition from the detail screen's app bar. With the stage
    // tile gone, the only delete_outline left is the app-bar one. Confirm the
    // dialog → removeCompetition → onBack lands on the list.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Ștergi competiția?'), findsOneWidget);
    await tester.tap(find.text('Șterge'));
    await tester.pumpAndSettle();
    expect(find.text('Competiții'), findsOneWidget);
    expect(find.text('Cup Test'), findsNothing);
  });
}