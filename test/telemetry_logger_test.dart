import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:retrometer/models.dart';
import 'package:retrometer/services/telemetry_logger.dart';

StageConfig get _config => const StageConfig(
      id: 'stg1',
      name: 'SS1',
      targetAvgSpeed: 60,
      maxSpeedLimit: 90,
      totalDistanceKm: 12,
      allocatedTimeSeconds: 720,
    );

Position _pos({double speed = 0}) => Position(
      longitude: 24.0,
      latitude: 46.0,
      timestamp: DateTime.utc(2026, 6, 24, 10, 0, 0),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 90,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: 0,
    );

Future<String> _pathOf(Directory dir) async =>
    '${dir.path}${Platform.pathSeparator}telemetry.log';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('telemetry_logger_test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('FileTelemetryLogger writes fix/stageEvent/event records as JSONL',
      () async {
    final logger = FileTelemetryLogger(pathProvider: () async => _pathOf(dir));
    logger.fix(
      pos: _pos(speed: 0),
      addedMetres: 30,
      dtMs: 1000,
      gpsSpeedKmh: 0.0,
      speedKmh: 108.0,
      distanceKm: 0.03,
      maxSpeedKmh: 108.0,
      minSpeedKmh: 0.0,
      baseline: false,
      status: StageStatus.inProgress,
    );
    logger.stageEvent(
      type: 'start',
      config: _config,
      telemetry: StageTelemetry(startTime: DateTime.utc(2026, 6, 24, 10, 0, 0)),
    );
    logger.event(type: 'finish_entered', data: {'dToEndM': 45, 'radiusM': 50});
    await logger.flush();

    final file = File(await _pathOf(dir));
    expect(file.existsSync(), isTrue);
    final lines = file.readAsLinesSync();
    expect(lines.length, 3);

    final fix = jsonDecode(lines[0]) as Map<String, dynamic>;
    expect(fix['type'], 'fix');
    expect(fix['lat'], 46.0);
    expect(fix['rawSpeedMps'], 0.0);
    expect(fix['speedKmh'], 108.0);
    expect(fix['addedM'], 30);
    expect(fix['dtMs'], 1000);
    expect(fix['status'], 'inProgress');
    expect(fix['session'], isA<String>());
    expect(fix['ts'], isA<String>());
    final session = fix['session'];

    final start = jsonDecode(lines[1]) as Map<String, dynamic>;
    expect(start['type'], 'start');
    expect(start['stageId'], 'stg1');
    expect(start['name'], 'SS1');
    expect(start['session'], session); // shared across records
    expect(start['config'], isA<Map>());
    expect((start['config'] as Map)['targetAvgSpeed'], 60);

    final finish = jsonDecode(lines[2]) as Map<String, dynamic>;
    expect(finish['type'], 'finish_entered');
    expect(finish['dToEndM'], 45);
    expect(finish['session'], session);

    await logger.close();
  });

  test('FileTelemetryLogger rotates to <file>.1 past maxBytes and keeps the '
      'tail in <file>', () async {
    // Each fix record is ~230 bytes, so a 1 KB threshold lets a few records
    // accumulate before rotation fires (rather than rotating on every single
    // write). Write enough that rotation fires once mid-stream with several
    // records still to come — so the live file ends up holding the fresh tail.
    final logger = FileTelemetryLogger(
      pathProvider: () async => _pathOf(dir),
      maxBytes: 1000,
    );
    for (var i = 0; i < 20; i++) {
      logger.fix(
        pos: _pos(speed: 10),
        addedMetres: 100,
        dtMs: 1000,
        gpsSpeedKmh: 36.0,
        speedKmh: 36.0,
        distanceKm: 0.1 * i,
        maxSpeedKmh: 36.0,
        minSpeedKmh: 36.0,
        baseline: i == 0,
        status: StageStatus.inProgress,
      );
    }
    // One more record after the bulk: if the last bulk write triggered a
    // rotation (renaming `live` → `.1`), this reopens a fresh `live` so the
    // tail is always on disk. Without it the final rotation would leave no
    // live file at all.
    logger.fix(
      pos: _pos(speed: 0),
      addedMetres: 0,
      dtMs: 0,
      gpsSpeedKmh: 0.0,
      speedKmh: 0.0,
      distanceKm: 2.0,
      maxSpeedKmh: 36.0,
      minSpeedKmh: 0.0,
      baseline: false,
      status: StageStatus.completed,
    );
    await logger.flush();

    final live = File(await _pathOf(dir));
    final rotated = File('${await _pathOf(dir)}.1');
    expect(rotated.existsSync(), isTrue, reason: 'rotated chunk should exist');
    expect(live.existsSync(), isTrue, reason: 'fresh tail should be the live file');

    // The session id is consistent across the rotation boundary.
    final liveLines = live.readAsLinesSync();
    final rotatedLines = rotated.readAsLinesSync();
    expect(liveLines, isNotEmpty);
    expect(rotatedLines, isNotEmpty);
    final liveSession =
        (jsonDecode(liveLines.first) as Map<String, dynamic>)['session'];
    final rotatedSession =
        (jsonDecode(rotatedLines.first) as Map<String, dynamic>)['session'];
    expect(liveSession, rotatedSession);

    await logger.close();
  });

  test('the provider default is a no-op that never touches disk', () async {
    // With no override, telemetryLoggerProvider yields the internal null logger.
    // Calling every method (and flush/close) must be safe and create no file —
    // this is what keeps the many test files that don't override the logger
    // from writing to disk.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final logger = container.read(telemetryLoggerProvider);
    logger.fix(
      pos: _pos(speed: 0),
      addedMetres: 0,
      dtMs: 0,
      gpsSpeedKmh: null,
      speedKmh: 0,
      distanceKm: 0,
      maxSpeedKmh: 0,
      minSpeedKmh: null,
      baseline: true,
      status: StageStatus.idle,
    );
    logger.stageEvent(type: 'start', config: _config);
    logger.event(type: 'autostart_prompt', data: {'stageId': 'stg1'});
    await logger.flush();
    await logger.close();

    // Nothing was written: no telemetry.log in the temp dir (the null logger
    // has no path, but assert the dir stays clean regardless).
    final entries = dir.listSync();
    expect(entries, isEmpty);
  });
}