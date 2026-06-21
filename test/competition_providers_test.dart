import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:retrometer/competition_providers.dart';
import 'package:retrometer/models.dart';
import 'package:retrometer/services/device_service.dart';
import 'package:retrometer/services/gps_service.dart';
import 'package:retrometer/state_providers.dart';

/// Fake GPS for competition tests: reports [distanceToGeofence] for every
/// `distanceBetween` call so a test can simulate in-geofence vs out-of-geofence,
/// and drives the auto-start monitor's fast path ([lastKnownPosition]) plus its
/// fallback ([currentPositionResult]).
class _FakeGpsService implements GpsService {
  _FakeGpsService();

  /// Metres reported for every `distanceBetween` call. Settable so a test can
  /// flip between in-geofence and out-of-geofence.
  double distanceToGeofence = 0.0;

  /// Position returned by [getLastKnownPosition]. `null` simulates "no
  /// last-known fix" → the monitor falls back to [getCurrentPosition].
  Position? lastKnownPosition;

  /// Position returned by [getCurrentPosition]. When `null`, the call throws a
  /// [TimeoutException] to simulate a device that can't acquire a fresh fix.
  Position? currentPositionResult;

  /// Number of times [isLocationServiceEnabled] was called. The monitor only
  /// touches the GPS service in Pass 2 (location pass), so a time-met stage
  /// (Pass 1) leaves this at 0 — handy for asserting "GPS was never acquired".
  int isLocationServiceEnabledCalls = 0;

  final StreamController<Position> controller =
      StreamController<Position>.broadcast();

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async {
    isLocationServiceEnabledCalls++;
    return true;
  }

  @override
  Future<Position?> getLastKnownPosition() async => lastKnownPosition;

  @override
  Future<Position> getCurrentPosition({Duration? timeLimit}) async {
    final result = currentPositionResult;
    if (result == null) {
      // Simulate a fresh-acquisition timeout (the real bug from todo.md).
      throw TimeoutException('no fresh fix', timeLimit ?? Duration.zero);
    }
    return result;
  }

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

/// Builds a [PlannedStage] for tests. All three trigger fields are nullable and
/// pass through as-is (no fallback): pass `latitude: null, longitude: null` for
/// a time-only stage, or `startTime: null` for a location-only stage. Existing
/// call sites that need coords must pass them explicitly.
PlannedStage _stage({
  DateTime? startTime,
  double? latitude,
  double? longitude,
  double radius = 200,
  bool autoStart = true,
  bool started = false,
}) =>
    PlannedStage(
      id: _stageId,
      name: 'Test',
      startTime: startTime,
      latitude: latitude,
      longitude: longitude,
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
  /// monitor and wait until it surfaces a pending prompt.
  ///
  /// The monitor no longer silently auto-starts; it sets `pendingPrompt`. By
  /// default [autoConfirm] is true: after the prompt appears, this helper calls
  /// `confirmPending()` and waits for the stage to actually start. Pass
  /// `autoConfirm: false` to leave the prompt pending so the test can assert on
  /// `pendingPrompt` directly.
  ///
  /// By default the fake serves a fresh [lastKnownPosition] (the monitor's fast
  /// path). Pass [useLastKnown]: false to force the [getCurrentPosition]
  /// fallback, and [useCurrentPosition]: false to make both paths fail (no fix
  /// at all — the real-device bug).
  Future<void> armMonitor(
    PlannedStage stage, {
    bool useLastKnown = true,
    bool useCurrentPosition = true,
    bool autoConfirm = true,
  }) async {
    final competitions = container.read(competitionsProvider.notifier);
    await container.read(competitionsProvider.future);
    await competitions.addCompetition(_competition(stages: [stage]));

    // Configure the fake's fix sources before arming (the monitor's first
    // tick fires synchronously off build()).
    gps.lastKnownPosition = useLastKnown ? _fix() : null;
    gps.currentPositionResult = useCurrentPosition ? _fix() : null;

    // Reading the monitor triggers build → immediate _tick().
    container.read(autoStartMonitorProvider);

    // Poll until the monitor surfaces a pending prompt (or we give up).
    for (var i = 0; i < 40; i++) {
      if (container.read(autoStartMonitorProvider).pendingPrompt != null) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    if (autoConfirm &&
        container.read(autoStartMonitorProvider).pendingPrompt != null) {
      await container.read(autoStartMonitorProvider.notifier).confirmPending();

      // Poll until the stage starts (or we give up).
      for (var i = 0; i < 40; i++) {
        if (container.read(stageControllerProvider).telemetry.status !=
            StageStatus.idle) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      // Wait for markStarted to land in the competition state.
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
  }

  Competition? currentCompetition() =>
      container.read(competitionsProvider).valueOrNull?.first;

  group('auto-start OR-logic', () {
    test('auto-start fires when stage is due and device is in geofence',
        () async {
      // Both triggers set, time 1 min ago, distance 0. Pass 1 (time) prompts,
      // confirmPending starts the stage.
      await armMonitor(
        _stage(
          startTime: DateTime.now().subtract(const Duration(minutes: 1)),
          latitude: 45.0,
          longitude: 24.0,
        ),
      );

      expect(
        container.read(stageControllerProvider).telemetry.status,
        StageStatus.inProgress,
      );
      expect(currentCompetition()!.stages.single.started, true);
      expect(container.read(stageControllerProvider).config.name, 'Test');
    });

    test('auto-start prompts on time-met even when out of geofence',
        () async {
      // Both triggers set, time 1 min ago (within grace), but device far away.
      // OLD (AND-logic): idle. NEW (OR-logic): time alone prompts (Pass 1, no
      // GPS).
      gps.distanceToGeofence = 9999;
      await armMonitor(
        _stage(
          startTime: DateTime.now().subtract(const Duration(minutes: 1)),
          latitude: 45.0,
          longitude: 24.0,
        ),
        autoConfirm: false,
      );

      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNotNull,
      );
      expect(
        container.read(stageControllerProvider).telemetry.status,
        StageStatus.idle,
      );
      expect(currentCompetition()!.stages.single.started, false);
    });

    test('auto-start does not fire for a future stage (time-only)', () async {
      // Time-only stage (no coords so there's no location trigger), start in 1h.
      // Time not met (future) and no location → no prompt.
      await armMonitor(
        _stage(startTime: DateTime.now().add(const Duration(hours: 1))),
        autoConfirm: false,
      );

      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNull,
      );
      expect(
        container.read(stageControllerProvider).telemetry.status,
        StageStatus.idle,
      );
      expect(currentCompetition()!.stages.single.started, false);
    });

    test('auto-start does not prompt when autoStart is disabled', () async {
      // autoStart off → not armed → no prompt regardless of time/coords.
      await armMonitor(
        _stage(
          startTime: DateTime.now().subtract(const Duration(minutes: 1)),
          latitude: 45.0,
          longitude: 24.0,
          autoStart: false,
        ),
        autoConfirm: false,
      );

      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNull,
      );
      expect(
        container.read(stageControllerProvider).telemetry.status,
        StageStatus.idle,
      );
    });

    test('auto-start prompts on location-met even when time is past grace',
        () async {
      // Both triggers set, time 20 min ago (beyond 10-min grace), but device in
      // geofence (distance 0). OLD (AND-logic): idle. NEW (OR-logic): location
      // alone prompts (Pass 2).
      gps.distanceToGeofence = 0;
      await armMonitor(
        _stage(
          startTime: DateTime.now().subtract(const Duration(minutes: 20)),
          latitude: 45.0,
          longitude: 24.0,
        ),
        autoConfirm: false,
      );

      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNotNull,
      );
      expect(
        container.read(stageControllerProvider).telemetry.status,
        StageStatus.idle,
      );
      expect(currentCompetition()!.stages.single.started, false);
    });

    test('auto-start fires via getCurrentPosition when last-known is missing',
        () async {
      // Location-only stage (no startTime so Pass 1 doesn't short-circuit),
      // no last-known fix → the monitor must fall back to getCurrentPosition
      // and still prompt.
      await armMonitor(
        _stage(latitude: 45.0, longitude: 24.0),
        useLastKnown: false,
      );

      expect(
        container.read(stageControllerProvider).telemetry.status,
        StageStatus.inProgress,
      );
      expect(currentCompetition()!.stages.single.started, true);
    });

    test('time-only stage prompts without acquiring GPS', () async {
      // Time-only stage (coords null), time 1 min ago. Pass 1 prompts without
      // ever touching the GPS service.
      gps.isLocationServiceEnabledCalls = 0;
      await armMonitor(
        _stage(startTime: DateTime.now().subtract(const Duration(minutes: 1))),
        autoConfirm: false,
      );

      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNotNull,
      );
      expect(gps.isLocationServiceEnabledCalls, 0);
    });

    test('location-only stage does not prompt when no GPS fix can be acquired',
        () async {
      // Location-only stage (startTime null), no last-known and a fresh
      // acquisition times out. Pass 2 can't get a fix → aborts with the message.
      await armMonitor(
        _stage(latitude: 45.0, longitude: 24.0),
        useLastKnown: false,
        useCurrentPosition: false,
        autoConfirm: false,
      );

      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNull,
      );
      expect(
        container.read(stageControllerProvider).telemetry.status,
        StageStatus.idle,
      );
      expect(currentCompetition()!.stages.single.started, false);
      expect(
        container.read(autoStartMonitorProvider).message,
        'nu am primit fix GPS',
      );
    });

    test('time-only stage prompts on time', () async {
      await armMonitor(
        _stage(startTime: DateTime.now().subtract(const Duration(minutes: 1))),
        autoConfirm: false,
      );

      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNotNull,
      );
      expect(gps.isLocationServiceEnabledCalls, 0);
    });

    test('location-only stage prompts in geofence', () async {
      // Location-only (no startTime), device in geofence → Pass 2 prompts.
      gps.distanceToGeofence = 0;
      await armMonitor(
        _stage(latitude: 45.0, longitude: 24.0),
        autoConfirm: false,
      );

      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNotNull,
      );
    });

    test('location-only stage does not prompt out of geofence', () async {
      gps.distanceToGeofence = 9999;
      await armMonitor(
        _stage(latitude: 45.0, longitude: 24.0),
        autoConfirm: false,
      );

      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNull,
      );
    });

    test('both-set prompts on time-met out-of-geofence', () async {
      // Time met → Pass 1 prompts, GPS never acquired (isLocationServiceEnabled
      // untouched).
      gps.distanceToGeofence = 9999;
      await armMonitor(
        _stage(
          startTime: DateTime.now().subtract(const Duration(minutes: 1)),
          latitude: 45.0,
          longitude: 24.0,
        ),
        autoConfirm: false,
      );

      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNotNull,
      );
      expect(gps.isLocationServiceEnabledCalls, 0);
    });

    test('both-set prompts on location-met before time', () async {
      // Future start time (time not met) but device in geofence → Pass 2
      // prompts on location.
      gps.distanceToGeofence = 0;
      await armMonitor(
        _stage(
          startTime: DateTime.now().add(const Duration(hours: 1)),
          latitude: 45.0,
          longitude: 24.0,
        ),
        autoConfirm: false,
      );

      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNotNull,
      );
    });

    test('stage with neither time nor location does not prompt', () async {
      await armMonitor(
        _stage(),
        autoConfirm: false,
      );

      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNull,
      );
    });

    test('confirmPending starts the stage and marks started', () async {
      await armMonitor(
        _stage(startTime: DateTime.now().subtract(const Duration(minutes: 1))),
        autoConfirm: true,
      );

      expect(
        container.read(stageControllerProvider).telemetry.status,
        StageStatus.inProgress,
      );
      expect(currentCompetition()!.stages.single.started, true);
      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNull,
      );
    });

    test('decline snoozes for 5 minutes', () async {
      // Location-only stage, device in geofence. Drive the monitor's clock via
      // the `now` field override; force re-evaluation by refreshing
      // competitionsProvider (the monitor watches it → rebuild → immediate
      // _tick()).
      final baseNow = DateTime(2026, 6, 21, 12, 0);
      container.read(autoStartMonitorProvider.notifier).now = () => baseNow;
      gps.distanceToGeofence = 0;

      await armMonitor(
        _stage(latitude: 45.0, longitude: 24.0),
        autoConfirm: false,
      );
      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNotNull,
      );

      // Decline → snoozed for 5 min, prompt cleared.
      container.read(autoStartMonitorProvider.notifier).dismissPending();
      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNull,
      );

      // Within the snooze window: re-evaluate → still snoozed, no prompt.
      container.refresh(competitionsProvider);
      await container.read(competitionsProvider.future);
      for (var i = 0; i < 40; i++) {
        if (container.read(autoStartMonitorProvider).pendingPrompt != null) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNull,
      );

      // Advance the clock past the snooze (6 min later): re-evaluate → location
      // still met → prompt re-surfaces.
      container.read(autoStartMonitorProvider.notifier).now =
          () => baseNow.add(const Duration(minutes: 6));
      container.refresh(competitionsProvider);
      await container.read(competitionsProvider.future);
      for (var i = 0; i < 40; i++) {
        if (container.read(autoStartMonitorProvider).pendingPrompt != null) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(
        container.read(autoStartMonitorProvider).pendingPrompt,
        isNotNull,
      );
    });
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
      startDate: DateTime(2026, 6, 21),
      endDate: DateTime(2026, 6, 23),
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
    expect(decoded.startDate, DateTime(2026, 6, 21));
    expect(decoded.endDate, DateTime(2026, 6, 23));
    expect(decoded.stages.single.id, _stageId);
  });

  test('legacy single-date payload migrates into startDate', () {
    // Pre-multi-day wire format: a `date` key and no `startDate`/`endDate`.
    final legacy = jsonEncode([
      {
        'id': _competitionId,
        'name': 'Raliul Vechi',
        'location': 'Cluj',
        'date': DateTime(2026, 6, 21).toIso8601String(),
        'stages': [],
      },
    ]);
    final decoded = competitionsFromJson(legacy).single;
    expect(decoded.startDate, DateTime(2026, 6, 21));
    expect(decoded.endDate, isNull);
  });
}