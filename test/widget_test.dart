import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrometer/cockpit_view.dart';
import 'package:retrometer/main.dart';
import 'package:retrometer/state_providers.dart';
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

    // Top zone: config gear and START control present.
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });

  testWidgets('Cockpit renders without overflow on a narrow portrait screen',
      (WidgetTester tester) async {
    // Phone portrait: narrow + tall ⇒ two-row top bar with labeled controls.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'retrometer.onboarded': true});

    await tester.pumpWidget(const ProviderScope(child: RetrometerApp()));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Two-row top bar still shows the labeled START control.
    expect(find.text('START'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    // The three zones are present.
    expect(find.text('LA TIMP'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
    // No overflow was reported by the framework during layout (a flex
    // overflow fails the test via FlutterError.onError).
  });

  testWidgets('target average speed shows decimals (35.9, not 36)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'retrometer.onboarded': true});

    // Use the auto-dispose ProviderScope (so the clock/auto-start timers are
    // cancelled when the tree unmounts), then grab its container to set a
    // fractional target.
    await tester
        .pumpWidget(const ProviderScope(child: MaterialApp(home: CockpitView())));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CockpitView)),
      listen: false,
    );
    container.read(stageControllerProvider.notifier).updateConfig(
          container
              .read(stageControllerProvider)
              .config
              .copyWith(targetAvgSpeed: 35.9),
        );
    await tester.pumpAndSettle();

    // The Δ zone bottom line shows the fractional target verbatim.
    expect(find.textContaining('țintă 35.9'), findsOneWidget);
  });

  testWidgets('whole-number target average stays clean (40, not 40.0)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'retrometer.onboarded': true});

    await tester
        .pumpWidget(const ProviderScope(child: MaterialApp(home: CockpitView())));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CockpitView)),
      listen: false,
    );
    container.read(stageControllerProvider.notifier).updateConfig(
          container
              .read(stageControllerProvider)
              .config
              .copyWith(targetAvgSpeed: 40.0),
        );
    await tester.pumpAndSettle();

    expect(find.textContaining('țintă 40'), findsOneWidget);
    expect(find.textContaining('țintă 40.0'), findsNothing);
  });
}