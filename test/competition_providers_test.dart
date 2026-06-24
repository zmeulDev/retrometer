import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:retrometer/competition_providers.dart';
import 'package:retrometer/models.dart';
import 'package:retrometer/services/competition_repository.dart';
import 'package:retrometer/services/device_service.dart';
import 'package:retrometer/services/gps_service.dart';
import 'package:retrometer/services/telemetry_logger.dart';
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

/// Captures every logger call in memory (no disk) so competition tests can
/// assert the auto-start hookpoints are recorded. Only `event` is exercised
/// here; the full-surface recorder lives in `state_providers_test.dart`.
class _RecordingLogger implements TelemetryLogger {
  final List<Map<String, Object?>> records = [];

  @override
  void fix({
    required Position pos,
    required double addedMetres,
    required int dtMs,
    required double? gpsSpeedKmh,
    required double speedKmh,
    required double distanceKm,
    required double maxSpeedKmh,
    required double? minSpeedKmh,
    required bool baseline,
    required StageStatus status,
  }) {}

  @override
  void stageEvent({
    required String type,
    required StageConfig config,
    StageTelemetry? telemetry,
    Map<String, Object?> extra = const {},
  }) {}

  @override
  void event({required String type, Map<String, Object?> data = const {}}) {
    records.add({'type': type, 'data': data});
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
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

/// Like [_fix] but with a non-zero speed (m/s). Used by the speed-telemetry
/// tests to feed fixes that carry instantaneous speed.
Position _fixWithSpeed(double mps) => Position(
      longitude: 24.0,
      latitude: 45.0,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: mps,
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
  late _RecordingLogger logger;
  late SqliteCompetitionRepository repo;
  late Directory repoDir;
  late ProviderContainer container;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    gps = _FakeGpsService();
    device = _FakeDeviceService();
    logger = _RecordingLogger();
    // SQLite-backed repository at a unique temp path (host `flutter test` has no
    // sqflite platform channels, so we drive an in-process ffi factory). The
    // same repo instance is reused by the "fresh container" test below so the
    // persisted data rehydrates from the same DB file.
    repoDir = Directory.systemTemp.createTempSync('retrometer_prov_test_');
    repo = SqliteCompetitionRepository(
      databaseFactory: databaseFactoryFfi,
      pathProvider: () async => path.join(repoDir.path, 'test.db'),
    );
    container = ProviderContainer(
      overrides: [
        gpsServiceProvider.overrideWithValue(gps),
        deviceServiceProvider.overrideWithValue(device),
        competitionRepositoryProvider.overrideWithValue(repo),
        telemetryLoggerProvider.overrideWithValue(logger),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    gps.controller.close();
    // Drain any in-flight persistence writes the persister fired
    // fire-and-forget (markResult/appendHistory) and close the handle before
    // the temp dir is torn down — otherwise an unfinished transaction loses its
    // rollback journal mid-write (readonly_rollback, code 1032).
    await repo.close();
    if (repoDir.existsSync()) repoDir.delete(recursive: true);
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

    test('auto-start prompt and decline are recorded in the telemetry log',
        () async {
      // Location-only stage, device in geofence → the monitor surfaces a
      // pending prompt (an `autostart_prompt` event). Declining records an
      // `autostart_decline` event.
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

      // A prompt event was logged carrying the trigger reason and stage id.
      final prompt = logger.records.firstWhere(
        (r) => r['type'] == 'autostart_prompt',
        orElse: () => fail('autostart_prompt not logged'),
      );
      final promptData = prompt['data'] as Map<String, Object?>;
      expect(promptData['stageId'], _stageId);
      // `reason` is a human-readable string (e.g. "în geofence (0 m)" for a
      // location pass, "la ora 12:00" for a time pass) — assert it's present.
      expect(promptData['reason'], isA<String>());
      expect((promptData['reason'] as String).isNotEmpty, isTrue);

      // Decline → snooze → an `autostart_decline` event is logged.
      container.read(autoStartMonitorProvider.notifier).dismissPending();
      final decline = logger.records.firstWhere(
        (r) => r['type'] == 'autostart_decline',
        orElse: () => fail('autostart_decline not logged'),
      );
      expect((decline['data'] as Map<String, Object?>)['stageId'], _stageId);
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

    // Fresh container reads the same DB (same repo instance) → persisted
    // competition survives.
    final container2 = ProviderContainer(
      overrides: [
        gpsServiceProvider.overrideWithValue(gps),
        deviceServiceProvider.overrideWithValue(device),
        competitionRepositoryProvider.overrideWithValue(repo),
        telemetryLoggerProvider.overrideWithValue(logger),
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
        competitionRepositoryProvider.overrideWithValue(repo),
        telemetryLoggerProvider.overrideWithValue(logger),
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

  // --- per-stage speed telemetry persistence --------------------------------

  test('stopStage persists the captured result onto the planned stage via the '
      'persister', () async {
    // No start/end coords and autoStart off: neither auto-start nor auto-stop
    // can interfere. The persister is kept alive (read) before the flip.
    final stage = _stage(latitude: null, longitude: null, autoStart: false);
    final competitions = container.read(competitionsProvider.notifier);
    await container.read(competitionsProvider.future);
    await competitions.addCompetition(_competition(stages: [stage]));

    gps.distanceToGeofence = 100; // each distanceBetween → 0.1 km

    // Keep the persister alive so its ref.listen fires on the status flip.
    container.read(stageResultPersisterProvider);

    await container.read(stageControllerProvider.notifier).startStageFromPlan(
      stage,
    );

    // Wait for inProgress.
    for (var i = 0; i < 40; i++) {
      if (container.read(stageControllerProvider).telemetry.status ==
          StageStatus.inProgress) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    // Feed fixes with speeds 10/20/15 m/s (36/72/54 km/h). First fix seeds
    // `last` (0 distance); subsequent two each add 0.1 km → 0.2 km total.
    // max=72, min=36.
    for (final mps in [10.0, 20.0, 15.0]) {
      gps.controller.add(_fixWithSpeed(mps));
      await Future<void>.delayed(Duration.zero);
    }

    container.read(stageControllerProvider.notifier).stopStage();

    // Poll until the persister's markResult lands in the competition state.
    for (var i = 0; i < 40; i++) {
      final comps = container.read(competitionsProvider).valueOrNull;
      if (comps != null &&
          comps.isNotEmpty &&
          comps.first.stages.isNotEmpty &&
          comps.first.stages.first.result != null) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    final result = container
        .read(competitionsProvider)
        .valueOrNull!
        .first
        .stages
        .first
        .result;
    expect(result, isNotNull);
    expect(result!.maxSpeedKmh, closeTo(72, 1e-9));
    expect(result.minSpeedKmh, closeTo(36, 1e-9));
    expect(result.totalDistanceKm, closeTo(0.2, 1e-9));
    // avg is wall-clock dependent; _buildResult returns 0.0 when elapsed is 0,
    // so `>= 0` is always safe.
    expect(result.avgSpeedKmh, greaterThanOrEqualTo(0.0));
  });

  test('StageResult round-trips through Competition JSON', () {
    final result = StageResult(
      maxSpeedKmh: 72,
      minSpeedKmh: 36,
      avgSpeedKmh: 60,
      totalDistanceKm: 12.5,
      elapsedSeconds: 750,
      completedAt: DateTime.utc(2026, 6, 22, 10, 0, 0),
    );
    final comp = _competition(stages: [_stage().copyWith(result: result)]);
    final encoded = competitionsToJson([comp]);
    final decoded = competitionsFromJson(encoded).single;
    final rtStage = decoded.stages.single;
    expect(rtStage.result, isNotNull);
    expect(rtStage.result!.maxSpeedKmh, closeTo(72, 1e-9));
    expect(rtStage.result!.minSpeedKmh, closeTo(36, 1e-9));
    expect(rtStage.result!.avgSpeedKmh, closeTo(60, 1e-9));
    expect(rtStage.result!.totalDistanceKm, closeTo(12.5, 1e-9));
    expect(rtStage.result!.elapsedSeconds, 750);
    expect(
      rtStage.result!.completedAt!.toIso8601String(),
      DateTime.utc(2026, 6, 22, 10, 0, 0).toIso8601String(),
    );
  });

  test('payload without result key loads with result null (backward compat)',
      () {
    // Minimal stage JSON with the required fields but no 'result' key — the
    // shape older app versions persisted before the result feature existed.
    final map = <String, dynamic>{
      'id': _stageId,
      'name': 'Test',
      'targetAvgSpeed': 40.0,
      'maxSpeedLimit': 60.0,
      'geofenceRadiusM': 200.0,
    };
    final stage = plannedStageFromJson(map);
    expect(stage.result, isNull);
    expect(stageResultFromJson(null), isNull);
  });

  // --- per-competition history log -----------------------------------------

  /// Run one full stage cycle (start, feed fixes, stop) and wait for the
  /// persister to land `markResult`. When [seedCompetition] is true (default),
  /// a fresh competition owning [stage] is added first; pass false to re-run
  /// the same stage against the already-seeded competition (for the append-
  /// twice test). Returns the result snapshotted by the controller.
  Future<StageResult> runStageOnce(
    PlannedStage stage, {
    bool seedCompetition = true,
  }) async {
    if (seedCompetition) {
      final competitions = container.read(competitionsProvider.notifier);
      await container.read(competitionsProvider.future);
      await competitions.addCompetition(_competition(stages: [stage]));
    }

    gps.distanceToGeofence = 100; // each distanceBetween → 0.1 km

    // Keep the persister alive so its ref.listen fires on the status flip.
    container.read(stageResultPersisterProvider);

    await container.read(stageControllerProvider.notifier).startStageFromPlan(
      stage,
    );

    // Wait for inProgress.
    for (var i = 0; i < 40; i++) {
      if (container.read(stageControllerProvider).telemetry.status ==
          StageStatus.inProgress) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    // Feed fixes with speeds 10/20/15 m/s (36/72/54 km/h). First fix seeds
    // `last` (0 distance); subsequent two each add 0.1 km → 0.2 km total.
    // max=72, min=36.
    for (final mps in [10.0, 20.0, 15.0]) {
      gps.controller.add(_fixWithSpeed(mps));
      await Future<void>.delayed(Duration.zero);
    }

    final startedAt = container.read(stageControllerProvider).telemetry.startTime;

    container.read(stageControllerProvider.notifier).stopStage();

    // Poll until the persister's markResult lands in the competition state.
    for (var i = 0; i < 40; i++) {
      final comps = container.read(competitionsProvider).valueOrNull;
      if (comps != null &&
          comps.isNotEmpty &&
          comps.first.stages.isNotEmpty &&
          comps.first.stages.first.result != null) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    final result = container
        .read(competitionsProvider)
        .valueOrNull!
        .first
        .stages
        .first
        .result!;
    // Cross-check startedAt snapshot (non-null after a real start).
    expect(startedAt, isNotNull);
    return result;
  }

  group('history', () {
    test('stopStage appends a StageRunHistory entry to the owning competition',
        () async {
      final stage = _stage(
        latitude: 46.0,
        longitude: 25.0,
        autoStart: false,
      ).copyWith(
        targetAvgSpeed: 35.0,
        maxSpeedLimit: 55.0,
        endLatitude: 46.1,
        endLongitude: 25.1,
        // autoStop off so the geofence doesn't cut the feed short after the
        // 2nd fix (distanceBetween=100m <= endGeofenceRadiusM=200m would trip
        // auto-stop before the 3rd fix lands). End coords are still recorded in
        // the history entry; we just don't want auto-stop here.
        autoStop: false,
      );
      final result = await runStageOnce(stage);

      // Wait for appendHistory to land as well (it fires alongside markResult).
      for (var i = 0; i < 40; i++) {
        final comps = container.read(competitionsProvider).valueOrNull;
        if (comps != null &&
            comps.isNotEmpty &&
            comps.first.history.isNotEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final comp = container.read(competitionsProvider).valueOrNull!.first;
      expect(comp.history, hasLength(1));
      final h = comp.history.single;
      expect(h.stageId, _stageId);
      expect(h.stageName, 'Test');
      expect(h.competitionName, 'Raliul Test');
      expect(h.maxSpeedKmh, closeTo(72, 1e-9));
      expect(h.minSpeedKmh, closeTo(36, 1e-9));
      expect(h.avgSpeedKmh, result.avgSpeedKmh);
      expect(h.totalDistanceKm, closeTo(0.2, 1e-9));
      expect(h.elapsedSeconds, result.elapsedSeconds);
      expect(h.startedAt, isNotNull);
      expect(h.completedAt, isNotNull);
      expect(h.startLatitude, closeTo(46.0, 1e-9));
      expect(h.startLongitude, closeTo(25.0, 1e-9));
      expect(h.endLatitude, closeTo(46.1, 1e-9));
      expect(h.endLongitude, closeTo(25.1, 1e-9));
      expect(h.targetAvgSpeed, 35.0);
      expect(h.maxSpeedLimit, 55.0);
      expect(h.id, startsWith('run-$_stageId-'));
    });

    test('two runs of the same stage append two history entries', () async {
      final stage = _stage(autoStart: false);
      await runStageOnce(stage);

      // Wait for the first history entry to land.
      for (var i = 0; i < 40; i++) {
        if (container
            .read(competitionsProvider)
            .valueOrNull!
            .first
            .history
            .isNotEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(
        container.read(competitionsProvider).valueOrNull!.first.history,
        hasLength(1),
      );

      // Reset the stage to idle before the second run so the telemetry is clean
      // (startStage() also resets, but resetStage makes the status transition
      // explicit and avoids any guard surprise).
      container.read(stageControllerProvider.notifier).resetStage();
      for (var i = 0; i < 40; i++) {
        if (container.read(stageControllerProvider).telemetry.status ==
            StageStatus.idle) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      // Re-run against the already-seeded competition (no new competition).
      await runStageOnce(stage, seedCompetition: false);

      // The persister appends a second entry; PlannedStage.result is the latest.
      for (var i = 0; i < 40; i++) {
        if (container
            .read(competitionsProvider)
            .valueOrNull!
            .first
            .history
            .length >=
            2) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final comp = container.read(competitionsProvider).valueOrNull!.first;
      expect(comp.history, hasLength(2));
      // Both history entries reference the same stage; the latest result is
      // still a single value on the PlannedStage.
      expect(comp.history.every((h) => h.stageId == _stageId), true);
      expect(comp.stages.single.result, isNotNull);
    });

    test('StageRunHistory round-trips through Competition JSON', () {
      final entry = StageRunHistory(
        id: 'run-s1-1719014400000',
        stageId: _stageId,
        stageName: 'Test',
        competitionName: 'Raliul Test',
        startedAt: DateTime.utc(2026, 6, 22, 9, 0, 0),
        completedAt: DateTime.utc(2026, 6, 22, 9, 12, 30),
        startLatitude: 46.0,
        startLongitude: 25.0,
        endLatitude: 46.1,
        endLongitude: 25.1,
        targetAvgSpeed: 35.0,
        maxSpeedLimit: 55.0,
        maxSpeedKmh: 72,
        minSpeedKmh: 36,
        avgSpeedKmh: 60,
        totalDistanceKm: 12.5,
        elapsedSeconds: 750,
      );
      final comp = _competition(stages: [_stage()]).copyWith(history: [entry]);
      final encoded = competitionsToJson([comp]);
      final decoded = competitionsFromJson(encoded).single;
      expect(decoded.history, hasLength(1));
      final h = decoded.history.single;
      expect(h.id, entry.id);
      expect(h.stageId, entry.stageId);
      expect(h.stageName, 'Test');
      expect(h.competitionName, 'Raliul Test');
      expect(
        h.startedAt!.toIso8601String(),
        DateTime.utc(2026, 6, 22, 9, 0, 0).toIso8601String(),
      );
      expect(
        h.completedAt!.toIso8601String(),
        DateTime.utc(2026, 6, 22, 9, 12, 30).toIso8601String(),
      );
      expect(h.startLatitude, closeTo(46.0, 1e-9));
      expect(h.startLongitude, closeTo(25.0, 1e-9));
      expect(h.endLatitude, closeTo(46.1, 1e-9));
      expect(h.endLongitude, closeTo(25.1, 1e-9));
      expect(h.targetAvgSpeed, 35.0);
      expect(h.maxSpeedLimit, 55.0);
      expect(h.maxSpeedKmh, closeTo(72, 1e-9));
      expect(h.minSpeedKmh, closeTo(36, 1e-9));
      expect(h.avgSpeedKmh, closeTo(60, 1e-9));
      expect(h.totalDistanceKm, closeTo(12.5, 1e-9));
      expect(h.elapsedSeconds, 750);
    });

    test('payload without history key loads with history [] (backward compat)',
        () {
      // Minimal competition JSON with the required fields but no 'history' key
      // — the shape older app versions persisted before the history feature.
      final map = <String, dynamic>{
        'id': _competitionId,
        'name': 'Raliul Vechi',
        'stages': [],
      };
      final decoded = competitionsFromJson(jsonEncode([map])).single;
      expect(decoded.history, isEmpty);
    });
  });
}