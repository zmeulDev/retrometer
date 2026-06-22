import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:retrometer/competition_providers.dart';
import 'package:retrometer/models.dart';
import 'package:retrometer/state_providers.dart';
import 'package:retrometer/widgets/cards.dart';

import 'helpers/fake_gps_service.dart';
import 'helpers/fake_positions.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'stage result: fake GPS feeds real speeds, STOP persists max/min/distance',
      (WidgetTester tester) async {
    // A planned stage with a known id, no finish geofence (so no auto-stop),
    // and auto-start off (the monitor must not prompt).
    final stage = PlannedStage(
      id: 'stage-res',
      name: 'Result Test',
      targetAvgSpeed: 40,
      autoStart: false,
    );
    final comp = Competition(
      id: 'comp-res',
      name: 'Result Comp',
      stages: [stage],
    );

    // 5 km reported for every consecutive fix pair → after two non-first
    // fixes the trip reads 10.00 km.
    final gps = FakeGpsService(fixedDistanceBetween: 5000);
    final container = await pumpRetrometer(
      tester,
      gps: gps,
      prefs: {'retrometer.competitions': competitionsToJson([comp])},
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Open the competition detail and start the stage from its tile (so the
    // running stage's config id is the planned one → the result persister can
    // write it back onto the planned stage).
    await tester.tap(find.byIcon(Icons.event_note));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Result Comp'));
    await tester.pumpAndSettle();

    final stageCard = find.ancestor(
      of: find.text('Result Test'),
      matching: find.byType(TappableCard),
    );
    await tester.tap(
      find.descendant(of: stageCard, matching: find.byIcon(Icons.play_arrow)),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.inProgress,
    );

    // Return to the cockpit to feed GPS and stop.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.pageBack(); // list → cockpit
    await tester.pumpAndSettle();

    // Feed fixes: first establishes a previous fix (0 m, speed 0 → min 0);
    // second adds 5 km at 18 km/h (5 m/s); third adds 5 km at 36 km/h (10 m/s).
    final t0 = DateTime.now();
    gps.controller.add(fakePosition(speed: 0, timestamp: t0));
    await tester.pump();
    gps.controller.add(fakePosition(speed: 5, timestamp: t0));
    await tester.pump();
    gps.controller.add(fakePosition(speed: 10, timestamp: t0));
    await tester.pumpAndSettle();
    expect(find.text('10.00'), findsOneWidget);

    // Stop → the persister writes the captured result onto the planned stage.
    await tester.tap(find.text('STOP'));
    await tester.pumpAndSettle();
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.completed,
    );

    final result =
        container.read(competitionsProvider).valueOrNull!.single.stages.single.result;
    expect(result, isNotNull);
    expect(result!.maxSpeedKmh, closeTo(36, 0.01));
    expect(result.minSpeedKmh, closeTo(0, 0.01));
    expect(result.totalDistanceKm, closeTo(10, 0.001));

    // The competition detail shows the "rezultat:" line on the stage tile.
    await tester.tap(find.byIcon(Icons.event_note));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Result Comp'));
    await tester.pumpAndSettle();
    expect(find.textContaining('rezultat:'), findsOneWidget);
  });
}