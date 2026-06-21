import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrometer/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Cockpit renders the three zones with idle defaults',
      (WidgetTester tester) async {
    // Landscape dashboard mount.
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Skip the first-run onboarding dialog for this smoke test.
    SharedPreferences.setMockInitialValues({'retrometer.onboarded': true});

    await tester.pumpWidget(const ProviderScope(child: RetrometerApp()));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Center zone: Δ readout at 0.0 (idle ⇒ on-time / green) with a clear
    // label.
    expect(find.text('LA TIMP'), findsOneWidget);
    expect(find.text('+ 0.0'), findsOneWidget);

    // Bottom zone: distance readout and unit; two visible ±10 m adjust zones.
    expect(find.text('0.00'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
    expect(find.text('10 m'), findsNWidgets(2));
    expect(find.text('lung: 100 m'), findsNWidgets(2));

    // Top zone: config gear, help, and START control present.
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });
}