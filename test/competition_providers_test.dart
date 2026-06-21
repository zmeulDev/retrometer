import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:retrometer/competition_providers.dart';
import 'package:retrometer/models.dart';
import 'package:retrometer/services/device_service.dart';
import 'package:retrometer/services/gps_service.dart';
import 'package:retrometer/state_providers.dart';

/// Fake GPS for competition tests: emits positions pushed into [controller],
/// and reports [distanceToGeofence] for every `distanceBetween` call so a test
/// can simulate in-geofence vs out-of-geofence.
class _FakeGpsService implements GpsService {
  _FakeGpsService();

  /// Metres reported for every `distanceBetween` call. Settable so a test can
  /// flip between in-geofence and out-of-geofence.
  double distanceToGeofence = 0.0;

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
  }) =>
      controller.stream;

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) =>
      distanceToGeofence;
}

class _FakeDeviceService implements DeviceService {
  @override
  Future<void> enableWakelock() async {}

  @override
  Future<void> disableWakelock() async {}

  @override
  Future<void> haptic({int durationMs = 30}) async {}
}

Position _fix() => Position(
      longitude: 24.0,
      latitude: 45.0,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

const _competitionId = 'comp-test';
const _stageId = 's1';

PlannedStage _stage({
  required DateTime startTime,
  double radius = 200,
  bool autoStart = true,
  bool started = false,
}) =>
    PlannedStage(
      id: _stageId,
      name: 'Test',
      startTime: startTime,
      latitude: 45.0,
      longitude: 24.0,
      geofenceRadiusM: radius,
      autoStart: autoStart,
      started: started,
    );

Competition _competition({List<PlannedStage> stages = const []}) => Competition(
      id: _competitionId,
      name: 'Raliul Test',
      location: 'Cluj',
      pilot: 'Andrei',
      copilot: 'Mihai',
      car: 'BMW Z3',
      category: 'A',
      totalTeams: 12,
      stages: stages,
    );

void main() {
  late _FakeGpsService gps;
  late _FakeDeviceService device;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    gps = _FakeGpsService();
    device = _FakeDeviceService();
    container = ProviderContainer(
      overrides: [
        gpsServiceProvider.overrideWithValue(gps),
        deviceServiceProvider.overrideWithValue(device),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    gps.controller.close();
  });

  /// Hydrate competitions, seed one with [stage], then arm the auto-start
  /// monitor and feed it GPS fixes until it either starts the stage or gives
  /// up. The retry loop is needed because the broadcast stream drops events
  /// that arrive before the monitor's `.first` subscription is in place.
  Future<void> armMonitor(PlannedStage stage) async {
    final competitions = container.read(competitionsProvider.notifier);
    await container.read(competitionsProvider.future);
    await competitions.addCompetition(_competition(stages: [stage]));

    // Reading the monitor triggers build → immediate _tick().
    container.read(autoStartMonitorProvider);

    // Deliver fixes until the stage starts (or we give up).
    for (var i = 0; i < 40; i++) {
      if (container.read(stageControllerProvider).telemetry.status !=
          StageStatus.idle) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (!gps.controller.isClosed) gps.controller.add(_fix());
    }

    // If it started, wait for markStarted to land in the competition state.
    if (container.read(stageControllerProvider).telemetry.status !=
        StageStatus.idle) {
      for (var i = 0; i < 40; i++) {
        final comps = container.read(competitionsProvider).valueOrNull;
        final started = comps != null &&
            comps.isNotEmpty &&
            comps.first.stages.isNotEmpty &&
            comps.first.stages.first.started;
        if (started) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }
  }

  Competition? currentCompetition() =>
      container.read(competitionsProvider).valueOrNull?.first;

  test('auto-start fires when stage is due and device is in geofence',
      () async {
    await armMonitor(
        _stage(startTime: DateTime.now().subtract(const Duration(minutes: 1))));

    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.inProgress,
    );
    expect(currentCompetition()!.stages.single.started, true);
    expect(container.read(stageControllerProvider).config.name, 'Test');
  });

  test('auto-start does not fire when device is outside the geofence',
      () async {
    gps.distanceToGeofence = 9999;
    await armMonitor(
        _stage(startTime: DateTime.now().subtract(const Duration(minutes: 1))));

    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.idle,
    );
    expect(currentCompetition()!.stages.single.started, false);
  });

  test('auto-start does not fire for a future stage', () async {
    await armMonitor(
        _stage(startTime: DateTime.now().add(const Duration(hours: 1))));

    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.idle,
    );
    expect(currentCompetition()!.stages.single.started, false);
  });

  test('auto-start does not fire when autoStart is disabled', () async {
    await armMonitor(_stage(
      startTime: DateTime.now().subtract(const Duration(minutes: 1)),
      autoStart: false,
    ));

    expect(
      container.read(stageControllerProvider).telemetry.status,
      StageStatus.idle,
    );
  });

  test('competitions + stages persist add/update/remove across a fresh '
      'container', () async {
    final competitions = container.read(competitionsProvider.notifier);
    await container.read(competitionsProvider.future);
    await competitions.addCompetition(_competition(stages: [
      _stage(startTime: DateTime.now().add(const Duration(hours: 2))),
    ]));
    // Rename the stage via updateStage.
    await competitions.updateStage(
      _competitionId,
      _stage(startTime: DateTime.now().add(const Duration(hours: 2)))
          .copyWith(name: 'Renamed'),
    );

    // Fresh container reads the same prefs → persisted competition survives.
    final container2 = ProviderContainer(
      overrides: [
        gpsServiceProvider.overrideWithValue(gps),
        deviceServiceProvider.overrideWithValue(device),
      ],
    );
    addTearDown(container2.dispose);
    final loaded = await container2.read(competitionsProvider.future);
    expect(loaded.single.name, 'Raliul Test');
    expect(loaded.single.location, 'Cluj');
    expect(loaded.single.stages.single.name, 'Renamed');

    await container2
        .read(competitionsProvider.notifier)
        .removeStage(_competitionId, _stageId);
    final afterRemove = container2.read(competitionsProvider).valueOrNull!;
    expect(afterRemove.single.stages, isEmpty);

    // Removing the competition itself drops it entirely.
    await container2
        .read(competitionsProvider.notifier)
        .removeCompetition(_competitionId);
    expect(container2.read(competitionsProvider).valueOrNull, isEmpty);
  });

  test('legacy flat schedule migrates into a default competition on first load',
      () async {
    SharedPreferences.setMockInitialValues({
      'retrometer.schedule': plannedStagesToJson([
        _stage(startTime: DateTime.now().add(const Duration(hours: 2))),
      ]),
    });
    final fresh = ProviderContainer(
      overrides: [
        gpsServiceProvider.overrideWithValue(gps),
        deviceServiceProvider.overrideWithValue(device),
      ],
    );
    addTearDown(fresh.dispose);
    final loaded = await fresh.read(competitionsProvider.future);
    expect(loaded.length, 1);
    expect(loaded.single.name, 'Importate');
    expect(loaded.single.stages.single.name, 'Test');
  });

  test('Competition JSON round-trips all metadata fields', () {
    final c = _competition(stages: [_stage(startTime: DateTime(2026, 6, 21, 9))])
        .copyWith(
      contactPerson: 'Ion',
      contactPhone: '0700',
      cost: 150.0,
      overallStanding: 3,
      categoryStanding: 2,
      date: DateTime(2026, 6, 21),
    );
    final encoded = competitionsToJson([c]);
    final decoded = competitionsFromJson(encoded).single;
    expect(decoded.name, 'Raliul Test');
    expect(decoded.location, 'Cluj');
    expect(decoded.pilot, 'Andrei');
    expect(decoded.copilot, 'Mihai');
    expect(decoded.car, 'BMW Z3');
    expect(decoded.category, 'A');
    expect(decoded.totalTeams, 12);
    expect(decoded.contactPerson, 'Ion');
    expect(decoded.contactPhone, '0700');
    expect(decoded.cost, 150.0);
    expect(decoded.overallStanding, 3);
    expect(decoded.categoryStanding, 2);
    expect(decoded.date, DateTime(2026, 6, 21));
    expect(decoded.stages.single.id, _stageId);
  });
}