import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:retrometer/competition_providers.dart';
import 'package:retrometer/models.dart';
import 'package:retrometer/state_providers.dart';

import 'helpers/fake_gps_service.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auto-start: time-only stage prompts and starts on "Da"',
      (WidgetTester tester) async {
    // Seed a time-only armed stage whose start time is ~1 min in the past
    // (within the 10-min grace window), so the monitor's first tick (fired off
    // build) immediately surfaces a prompt via Pass 1 — no GPS needed.
    final stage = PlannedStage(
      id: 'stage-autotime',
      name: 'Auto Time',
      startTime: DateTime.now().subtract(const Duration(minutes: 1)),
      autoStart: true,
    );
    final comp = Competition(
      id: 'comp-autotime',
      name: 'Auto Comp',
      stages: [stage],
    );

    // No GPS fix available at all (both one-shot sources null). If the prompt
    // still appears, it must have come from the time path — proving Pass 1
    // fires without touching GPS.
    final gps = FakeGpsService(
      lastKnownPosition: null,
      currentPositionResult: null,
    );
    final container = await pumpRetrometer(
      tester,
      gps: gps,
      prefs: {'retrometer.competitions': competitionsToJson([comp])},
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // The auto-start confirmation dialog is on screen.
    expect(find.text('Pornire stage'), findsOneWidget);
    expect(find.textContaining('Doriți să porniți'), findsOneWidget);
    expect(find.text('Da'), findsOneWidget);

    // Confirm → the stage starts and is marked started.
    await tester.tap(find.text('Da'));
    await tester.pumpAndSettle();

    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.inProgress,
    );
    final comps = container.read(competitionsProvider).valueOrNull!;
    expect(comps.single.stages.single.started, true);
    expect(container.read(stageControllerProvider).config.name, 'Auto Time');
  });
}