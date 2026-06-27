import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as path;
import 'package:retrometer/cockpit_view.dart';
import 'package:retrometer/cockpit/cockpit_tripmeter.dart';
import 'package:retrometer/main.dart';
import 'package:retrometer/services/competition_repository.dart';
import 'package:retrometer/services/device_service.dart';
import 'package:retrometer/services/gps_service.dart';
import 'package:retrometer/state_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fake GPS for the distance-fit tests: emits positions pushed into
/// [controller] and reports a fixed [metresPerStep] for every
/// `distanceBetween` call, so a stage fed two fixes lands on a known distance.
class _FakeGps implements GpsService {
  _FakeGps({this.metresPerStep = 100000});

  final double metresPerStep;
  final StreamController<Position> controller =
      StreamController<Position>.broadcast();

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 0,
    bool bestForNavigation = false,
  }) =>
      controller.stream;

  @override
  Future<Position?> getLastKnownPosition() async => null;

  @override
  Future<Position> getCurrentPosition({Duration? timeLimit}) =>
      throw UnimplementedError();

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) =>
      metresPerStep;
}

class _FakeDevice implements DeviceService {
  @override
  Future<void> enableWakelock() async {}
  @override
  Future<void> disableWakelock() async {}
  @override
  Future<void> haptic({int durationMs = 30}) async {}
}

/// A throwaway SQLite-backed repository at a unique temp path, so the full-app
/// pumps (which read `competitionsProvider` on the host) don't hit sqflite's
/// missing platform channels.
SqliteCompetitionRepository _newRepo() {
  final dir = Directory.systemTemp.createTempSync('retrometer_widget_test_');
  addTearDown(() {
    if (dir.existsSync()) dir.delete(recursive: true);
  });
  return SqliteCompetitionRepository(
    databaseFactory: databaseFactoryFfi,
    pathProvider: () async => path.join(dir.path, 'test.db'),
  );
}

Future<ProviderContainer> _startAndFeed(
  WidgetTester tester,
  double metresPerStep,
) async {
  final gps = _FakeGps(metresPerStep: metresPerStep);
  SharedPreferences.setMockInitialValues({'retrometer.onboarded': true});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gpsServiceProvider.overrideWithValue(gps),
        deviceServiceProvider.overrideWithValue(_FakeDevice()),
      ],
      child: const MaterialApp(home: Scaffold(body: TripmeterBar())),
    ),
  );
  await tester.pump();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(TripmeterBar)),
    listen: false,
  );
  await container.read(stageControllerProvider.notifier).startStage();
  await tester.pump();
  // Set the distance directly via the blind-touch offset (what the crew uses to
  // zero/trim the odometer). The GPS integrator can't produce a 100+ km reading
  // from a couple of fixes (speed is clamped), and these tests only check that
  // a large distance string fits the layout — not the GPS math itself.
  container
      .read(stageControllerProvider.notifier)
      .adjustDistance(metresPerStep / 1000.0);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('Cockpit renders the three zones with idle defaults',
      (WidgetTester tester) async {
    // Landscape dashboard mount.
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Skip the first-run onboarding dialog for this smoke test.
    SharedPreferences.setMockInitialValues({'retrometer.onboarded': true});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [competitionRepositoryProvider.overrideWithValue(_newRepo())],
        child: const RetrometerApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Center zone: Δ readout at 0.0 (idle ⇒ on-time / green) with a clear
    // label.
    expect(find.text('LA TIMP'), findsOneWidget);
    expect(find.text('+ 0.0'), findsOneWidget);
    // Stage name is on its own line at the bottom of the Δ zone.
    expect(find.text('Stage 1'), findsOneWidget);

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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [competitionRepositoryProvider.overrideWithValue(_newRepo())],
        child: const RetrometerApp(),
      ),
    );
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [competitionRepositoryProvider.overrideWithValue(_newRepo())],
        child: const MaterialApp(home: CockpitView()),
      ),
    );
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

    // The Δ zone's target-speed icon pair shows the fractional target verbatim
    // (flag icon + value, no 'țintă' label anymore).
    expect(find.text('35.9'), findsOneWidget);
  });

  testWidgets('whole-number target average stays clean (40, not 40.0)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'retrometer.onboarded': true});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [competitionRepositoryProvider.overrideWithValue(_newRepo())],
        child: const MaterialApp(home: CockpitView()),
      ),
    );
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

    // The whole-number target renders clean (40, not 40.0) next to the flag
    // icon.
    expect(find.text('40'), findsOneWidget);
    expect(find.text('40.0'), findsNothing);
  });

  testWidgets('trip-meter fits a large distance (100.00) on landscape',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _startAndFeed(tester, 100000);

    expect(find.text('100.00'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
    // No flex overflow reported during layout (fails via FlutterError.onError).
  });

  testWidgets('trip-meter fits a large distance (999.99) on portrait',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _startAndFeed(tester, 999990);

    expect(find.text('999.99'), findsOneWidget);
    expect(find.text('km'), findsOneWidget);
  });
}