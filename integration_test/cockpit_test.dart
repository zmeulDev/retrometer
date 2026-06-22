import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:retrometer/models.dart';
import 'package:retrometer/state_providers.dart';

import 'helpers/fake_gps_service.dart';
import 'helpers/fake_positions.dart';
import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cockpit: start, feed GPS, accumulate distance + speed, stop',
      (WidgetTester tester) async {
    // Portrait phone — the primary dashboard mount. (Landscape + status-bar
    // inset is a separate, pre-existing top-bar sizing case; the flow itself
    // is orientation-independent.)
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final gps = FakeGpsService(fixedDistanceBetween: 1000); // 1 km per fix pair
    final container = await pumpRetrometer(tester, gps: gps);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Idle defaults across the three zones.
    expect(find.text('LA TIMP'), findsOneWidget);
    expect(find.text('+ 0.0'), findsOneWidget);
    expect(find.text('0.00'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);

    // Start the stage (location disclosure flag is preset → no dialog).
    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.inProgress,
    );

    // Feed fixes: first establishes a previous fix (adds 0 m), second adds 1 km
    // and carries an 18 km/h speed (5 m/s). 5 * 3.6 = 18 (exact).
    final t0 = DateTime.now();
    gps.controller.add(fakePosition(speed: 0, timestamp: t0));
    await tester.pump();
    gps.controller.add(fakePosition(speed: 5, timestamp: t0));
    await tester.pumpAndSettle();

    expect(find.text('1.00'), findsOneWidget); // 1 km accumulated
    expect(find.textContaining('acum 18'), findsOneWidget);

    // Stop the stage → completed, START reappears.
    await tester.tap(find.text('STOP'));
    await tester.pumpAndSettle();
    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.completed,
    );
    expect(find.text('START'), findsOneWidget);
  });
}