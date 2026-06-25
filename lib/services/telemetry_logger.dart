import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models.dart';
import '../utils/formatting.dart';

/// Durable per-session diagnostic log. Records every GPS fix and every
/// stage/auto-start/finish lifecycle event as one JSON line so the file can be
/// pulled off the device after a real-track test and analyzed
/// (`tool/analyze_telemetry_log.dart`).
///
/// The default provider ([telemetryLoggerProvider]) is a no-op so test files
/// that don't override it never touch disk; production wires a
/// [FileTelemetryLogger] in `main.dart`.
abstract class TelemetryLogger {
  /// One record per GPS fix received during a stage.
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
  });

  /// A stage lifecycle event: `start`, `pause`, `resume`, `stop`, `reset`,
  /// `adjust`, `config_update`, `plan_loaded`.
  void stageEvent({
    required String type,
    required StageConfig config,
    StageTelemetry? telemetry,
    Map<String, Object?> extra = const {},
  });

  /// A generic event: `finish_entered`, `finish_time`, `finish_confirm`,
  /// `finish_dismiss`, `autostart_prompt`, `autostart_confirm`,
  /// `autostart_decline`.
  void event({required String type, Map<String, Object?> data = const {}});

  /// Flush buffered writes to disk.
  Future<void> flush();

  /// Flush and close the underlying sink. Idempotent.
  Future<void> close();
}

/// Riverpod provider for the telemetry logger. The default is a no-op so tests
/// that don't override it are safe (no disk). Production overrides it with a
/// [FileTelemetryLogger] in `main.dart`.
final telemetryLoggerProvider = Provider<TelemetryLogger>(
  (ref) => const _NullTelemetryLogger(),
);

/// A logger that records nothing — the provider default.
class _NullTelemetryLogger implements TelemetryLogger {
  const _NullTelemetryLogger();

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
  void event({required String type, Map<String, Object?> data = const {}}) {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

/// Writes JSONL records to a file (next to `retrometer.db` in production).
/// Rotates the file to `<path>.1` when it exceeds [maxBytes], keeping the
/// previous chunk. The path is resolved lazily (via [pathProvider], mirroring
/// `SqliteCompetitionRepository`) so construction is synchronous.
///
/// Writes are **synchronous** (`writeAsStringSync` with `flush: true`). This is
/// deliberate: the log fires at most once per GPS fix (a few Hz), so a tiny
/// blocking append is cheaper than the `IOSink` async-buffer/flush machinery —
/// and it guarantees a record pulled off the device mid-stage is already on
/// disk, with no flush-drain race to debug. Writes are still chained so an
/// in-flight rotate can't be stomped by a fix arriving mid-rotation.
class FileTelemetryLogger implements TelemetryLogger {
  FileTelemetryLogger({
    required this.pathProvider,
    this.maxBytes = 2 << 20,
  });

  final Future<String> Function() pathProvider;
  final int maxBytes;

  final String session = newId('session');

  String? _path;
  int _bytesWritten = 0;
  bool _closed = false;
  // Writes are chained so resolvePath/write/rotate run strictly one at a time
  // (a fix arriving while the path is still being resolved would otherwise
  // race on `_path`). Mirrors `SqliteCompetitionRepository._chain`.
  Future<void> _lastWrite = Future<void>.value();

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
  }) {
    _write({
      'type': 'fix',
      'lat': pos.latitude,
      'lon': pos.longitude,
      'rawSpeedMps': pos.speed,
      'accuracy': pos.accuracy,
      'heading': pos.heading,
      'addedM': addedMetres,
      'dtMs': dtMs,
      'gpsSpeedKmh': gpsSpeedKmh,
      'speedKmh': speedKmh,
      'distKm': distanceKm,
      'maxKmh': maxSpeedKmh,
      'minKmh': minSpeedKmh,
      'baseline': baseline,
      'status': status.name,
    });
  }

  @override
  void stageEvent({
    required String type,
    required StageConfig config,
    StageTelemetry? telemetry,
    Map<String, Object?> extra = const {},
  }) {
    final record = <String, Object?>{
      'type': type,
      'stageId': config.id,
      'name': config.name,
      'config': _configJson(config),
      if (telemetry != null) 'telemetry': _telemetryJson(telemetry),
      ...extra,
    };
    _write(record);
  }

  @override
  void event({required String type, Map<String, Object?> data = const {}}) {
    _write({'type': type, ...data});
  }

  @override
  Future<void> flush() async {
    // No-op: writes are synchronous and durable by the time they return. Keep
    // the chain ordered so callers awaiting flush() still wait for pending
    // writes to finish.
    await _chain(() async {});
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    // Drain any in-flight writes (e.g. a path still resolving) so close()
    // doesn't return before they land.
    await _lastWrite;
  }

  Future<void> _chain(Future<void> Function() op) {
    final next = _lastWrite.then((_) => op());
    // Keep the chain alive even if an op throws (otherwise one failed write
    // would block every subsequent one forever — same guard as the repo).
    _lastWrite = next.catchError((Object error) {});
    return next;
  }

  Map<String, Object?> _configJson(StageConfig c) => {
        'targetAvgSpeed': c.targetAvgSpeed,
        'maxSpeedLimit': c.maxSpeedLimit,
        'endLat': c.endLatitude,
        'endLon': c.endLongitude,
        'endGeofenceRadiusM': c.endGeofenceRadiusM,
        'autoStop': c.autoStop,
        'totalDistanceKm': c.totalDistanceKm,
        'allocatedTimeSeconds': c.allocatedTimeSeconds,
      };

  Map<String, Object?> _telemetryJson(StageTelemetry t) => {
        'status': t.status.name,
        // NOTE: these stay as in-memory (local) ISO strings, on purpose. The
        // `stop`/`start` lifecycle records also carry `result.completedAt` /
        // history `startedAt`/`completedAt` (via model `toJson`, also local), so
        // keeping `startTime`/`pausedSince` local keeps each lifecycle record
        // internally consistent. The envelope `ts` is UTC; standalone event-data
        // fields that are compared directly with `ts` (snoozeUntil, prompt
        // startTime) are serialized as UTC to match — see competition_providers.
        'startTime': t.startTime?.toIso8601String(),
        'distKm': t.currentDistance,
        'speedKmh': t.currentSpeed,
        'maxKmh': t.maxSpeedKmh,
        'minKmh': t.minSpeedKmh,
        'pausedSince': t.pausedSince?.toIso8601String(),
        'pauseOffsetSeconds': t.pauseOffsetSeconds,
      };

  Map<String, Object?> _envelope(Map<String, Object?> record) => {
        'ts': DateTime.now().toUtc().toIso8601String(),
        'session': session,
        ...record,
      };

  /// Fire-and-forget write: queues the synchronous append onto the write chain
  /// so concurrent fixes stay ordered. The append itself is synchronous
  /// (`writeAsStringSync` with `flush: true`), so by the time the chained op
  /// returns the line is on disk.
  void _write(Map<String, Object?> record) {
    if (_closed) return;
    final line = jsonEncode(_envelope(record));
    _chain(() => _doWrite(line));
  }

  Future<void> _doWrite(String line) async {
    await _resolvePath();
    if (_closed || _path == null) return;
    final file = File(_path!);
    file.writeAsStringSync(
      '$line\n',
      mode: FileMode.append,
      flush: true,
    );
    _bytesWritten += line.length + 1;
    if (_bytesWritten > maxBytes) {
      _rotate();
    }
  }

  Future<void> _resolvePath() async {
    if (_path != null) return;
    _path = await pathProvider();
    final file = File(_path!);
    _bytesWritten = file.existsSync() ? file.lengthSync() : 0;
  }

  void _rotate() {
    if (_path == null) return;
    final rotated = File('$_path.1');
    try {
      if (rotated.existsSync()) rotated.deleteSync();
      File(_path!).renameSync('$_path.1');
    } on Object {
      // Rotation best-effort; the next record opens a fresh file.
    }
    _bytesWritten = 0;
  }
}