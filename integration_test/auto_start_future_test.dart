import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:retrometer/competition_providers.dart';
import 'package:retrometer/models.dart';
import 'package:retrometer/state_providers.dart';

import 'helpers/fake_gps_service.dart';
import 'helpers/test_app.dart';

/// Reproduces the user's scenario: a stage armed with a start time a couple of
/// minutes in the FUTURE, then waiting for the clock to reach it. The monitor
/// polls every 5 s using real `DateTime.now()`, so this test lets real
/// wall-clock time pass (via `Future.delayed`) and pumps frames to process the
/// resulting prompt — unlike `auto_start_time_test.dart`, which seeds an
/// already-due time and triggers on the first tick.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'auto-start: future start time prompts once the clock reaches it',
      (WidgetTester tester) async {
    final stage = PlannedStage(
      id: 'stage-future',
      name: 'Future Stage',
      // 8 s in the future — short enough for a test, long enough that the
      // monitor's first tick (fired off build) sees it as not-yet-due.
      startTime: DateTime.now().add(const Duration(seconds: 8)),
      autoStart: true,
    );
    final comp = Competition(
      id: 'comp-future',
      name: 'Future Comp',
      stages: [stage],
    );

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

    // Not yet — the start time is 8 s in the future.
    expect(find.text('Pornire stage'), findsNothing);

    // Let real wall-clock time pass so the monitor's 5 s poll (real
    // Timer.periodic + DateTime.now()) eventually sees the time as met. Poll
    // interval is 5 s, grace window 10 min, so by ~13 s the prompt must appear.
    for (var i = 0; i < 20; i++) {
      if (find.text('Pornire stage').evaluate().isNotEmpty) break;
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    }

    // The auto-start confirmation dialog is now on screen.
    expect(find.text('Pornire stage'), findsOneWidget);
    expect(find.textContaining('Doriți să porniți'), findsOneWidget);

    await tester.tap(find.text('Da'));
    await tester.pumpAndSettle();

    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.inProgress,
    );
    final comps = container.read(competitionsProvider).valueOrNull!;
    expect(comps.single.stages.single.started, true);
  });
}