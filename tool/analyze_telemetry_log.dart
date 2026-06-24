// Standalone analyzer for a pulled telemetry log.
//
// Usage:
//   dart run tool/analyze_telemetry_log.dart <path-to-retrometer_telemetry.log>
//
// Reads the JSONL written by FileTelemetryLogger and prints a human-readable
// summary: per-session time range, per-fix speed stats (incl. whether the
// device ever reported a non-zero raw speed), a speed-trace sample, a stage
// timeline (start→stop with config + result), and a finish/auto-start event
// timeline. No Flutter deps — only dart:io + dart:convert.
//
// This is a standalone CLI tool whose entire purpose is to print to stdout, so
// `avoid_print` doesn't apply here.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/analyze_telemetry_log.dart <log-path>');
    exit(64);
  }
  final file = File(args.first);
  if (!file.existsSync()) {
    stderr.writeln('File not found: ${args.first}');
    exit(66);
  }

  final records = <Map<String, dynamic>>[];
  var malformed = 0;
  for (final raw in file.readAsLinesSync()) {
    if (raw.trim().isEmpty) continue;
    try {
      final obj = jsonDecode(raw);
      if (obj is Map<String, dynamic>) {
        records.add(obj);
      } else {
        malformed++;
      }
    } on FormatException {
      malformed++;
    }
  }

  if (records.isEmpty) {
    print('No records found${malformed > 0 ? " ($malformed malformed lines skipped)" : ""}.');
    exit(0);
  }

  // --- Sessions -----------------------------------------------------------
  final bySession = <String, List<Map<String, dynamic>>>{};
  for (final r in records) {
    final s = (r['session'] ?? '?').toString();
    (bySession[s] ??= []).add(r);
  }
  print('=== Sessions ===');
  print('  records: ${records.length}'
      '${malformed > 0 ? "  ($malformed malformed lines skipped)" : ""}');
  for (final entry in bySession.entries) {
    final rs = entry.value;
    final first = _ts(rs.first);
    final last = _ts(rs.last);
    print('  session ${entry.key}: ${rs.length} records  $first → $last');
  }

  // --- Fix stats -----------------------------------------------------------
  final fixes = records.where((r) => r['type'] == 'fix').toList();
  print('\n=== GPS fixes ===');
  if (fixes.isEmpty) {
    print('  (no fix records — was a stage run?)');
  } else {
    final rawNonzero =
        fixes.where((f) => (f['rawSpeedMps'] as num? ?? 0) > 0).length;
    final speeds = fixes
        .map((f) => (f['speedKmh'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    final added = fixes
        .map((f) => (f['addedM'] as num?)?.toDouble() ?? 0)
        .toList();
    final dts = fixes
        .map((f) => (f['dtMs'] as num?)?.toInt() ?? 0)
        .where((d) => d > 0)
        .toList();
    final distKm = (fixes.last['distKm'] as num?)?.toDouble();
    final sumAddedKm =
        added.fold<double>(0, (a, b) => a + b) / 1000.0;
    final baselineCount = fixes.where((f) => f['baseline'] == true).length;
    print('  count: ${fixes.length}  (baselines/first-fixes: $baselineCount)');
    print('  raw speed > 0 m/s: $rawNonzero / ${fixes.length}'
        '  ← if 0, the device never reported a real speed (the A059 case; '
        'speedKmh is then distance/time-derived)');
    if (speeds.isNotEmpty) {
      speeds.sort();
      final avg = speeds.reduce((a, b) => a + b) / speeds.length;
      print('  speedKmh: min ${speeds.first.toStringAsFixed(1)}  '
          'max ${speeds.last.toStringAsFixed(1)}  '
          'avg ${avg.toStringAsFixed(1)}');
    }
    print('  distance: final=${distKm?.toStringAsFixed(3) ?? "—"} km  '
      'sum(addedM)=${sumAddedKm.toStringAsFixed(3)} km'
      '  (large gap ⇒ GPS jitter drifting the odometer while stopped)');
    if (dts.isNotEmpty) {
      dts.sort();
      final avgDt = dts.reduce((a, b) => a + b) / dts.length;
      print('  fix interval (dtMs): min ${dts.first}  max ${dts.last}  '
          'avg ${avgDt.toStringAsFixed(0)}');
    } else {
      print('  fix interval: all dtMs=0 (test fixes pushed synchronously)');
    }
    _printTrace('  speed trace (first 3 / middle 3 / last 3)', fixes);
  }

  // --- Stage timeline -----------------------------------------------------
  print('\n=== Stage timeline ===');
  final stages = _stages(records);
  if (stages.isEmpty) {
    print('  (no start events)');
  } else {
    for (final s in stages) {
      print('  • ${s.name} (${s.stageId})  source=${s.source}');
      print('      start: ${s.startTs}');
      if (s.stopTs != null) {
        print('      stop:  ${s.stopTs}  '
            'dur=${s.durationSec != null ? "${s.durationSec}s" : "—"}');
      } else {
        print('      stop:  (no stop event — stage not ended in this log)');
      }
      final c = s.config;
      if (c != null) {
        print('      config: target=${c['targetAvgSpeed']} max=${c['maxSpeedLimit']}'
            '  finish=${c['endLat'] != null ? "set (${c['endGeofenceRadiusM']}m)" : "—"}'
            '  allocated=${c['allocatedTimeSeconds']}s  planKm=${c['totalDistanceKm']}');
      }
      final r = s.result;
      if (r != null) {
        print('      result: max=${r['maxSpeedKmh']} min=${r['minSpeedKmh'] ?? "—"}'
            ' avg=${r['avgSpeedKmh']} km=${r['totalDistanceKm']}'
            ' elapsed=${r['elapsedSeconds']}s');
      }
      if (s.interEvents.isNotEmpty) {
        print('      between: ${s.interEvents.join(", ")}');
      }
    }
  }

  // --- Events timeline -----------------------------------------------------
  print('\n=== Finish / auto-start events ===');
  final events = records.where((r) {
    final t = r['type'] as String?;
    return t != null &&
        (t.startsWith('finish_') || t.startsWith('autostart_'));
  }).toList();
  if (events.isEmpty) {
    print('  (none)');
  } else {
    for (final e in events) {
      final t = e['type'];
      final bits = <String>[];
      for (final k in [
        'reason', 'stageName', 'dToEndM', 'radiusM', 'elapsedSec',
        'distanceM', 'snoozeUntil',
      ]) {
        if (e[k] != null) bits.add('$k=${e[k]}');
      }
      print('  ${_ts(e)}  $t  ${bits.join("  ")}');
    }
  }
}

String _ts(Map<String, dynamic> r) => (r['ts'] as String?) ?? '—';

void _printTrace(String label, List<Map<String, dynamic>> fixes) {
  List<Map<String, dynamic>> slice(int start, int count) {
    if (fixes.length <= count) return fixes.sublist(0);
    final end = (start + count).clamp(0, fixes.length);
    return fixes.sublist(start, end);
  }

  String fmt(Map<String, dynamic> f) =>
      'dt=${(f['dtMs'] ?? "—")}ms raw=${(f['rawSpeedMps'] ?? "—")}m/s'
      ' gps=${f['gpsSpeedKmh'] ?? "—"} v=${_fmtNum(f['speedKmh'])}km/h'
      ' +${_fmtNum(f['addedM'])}m  d=${_fmtNum(f['distKm'])}km';

  final out = <String>[];
  if (fixes.length <= 9) {
    out.addAll(fixes.map(fmt));
  } else {
    out.add('first:');
    out.addAll(slice(0, 3).map(fmt));
    out.add('middle:');
    out.addAll(slice(fixes.length ~/ 2 - 1, 3).map(fmt));
    out.add('last:');
    out.addAll(slice(fixes.length - 3, 3).map(fmt));
  }
  print(label);
  for (final line in out) {
    print('    $line');
  }
}

String _fmtNum(Object? v) {
  if (v == null) return '—';
  if (v is num) return v.toStringAsFixed(2);
  return v.toString();
}

class _Stage {
  _Stage(this.start);
  final Map<String, dynamic> start;
  String get stageId => (start['stageId'] ?? '?').toString();
  String get name => (start['name'] ?? '?').toString();
  String? get source => start['source'] as String?;
  String get startTs => _ts(start);
  Map<String, dynamic>? get config => start['config'] as Map<String, dynamic>?;
  Map<String, dynamic>? get result => start['result'] as Map<String, dynamic>?;
  String? stopTs;
  int? durationSec;
  final interEvents = <String>[];
}

List<_Stage> _stages(List<Map<String, dynamic>> records) {
  final stages = <_Stage>[];
  _Stage? open;
  for (final r in records) {
    switch (r['type']) {
      case 'plan_loaded':
        if (open != null) open.interEvents.add('plan_loaded(${r['stageId']})');
      case 'start':
        open = _Stage(r);
        stages.add(open);
      case 'stop':
        if (open != null) {
          open.stopTs = _ts(r);
          final result = r['result'] as Map<String, dynamic>?;
          open.durationSec = result?['elapsedSeconds'] as int?;
          open = null;
        }
      case 'pause':
        open?.interEvents.add('pause');
      case 'resume':
        open?.interEvents.add('resume');
      case 'adjust':
        open?.interEvents
            .add('adjust(${r['offsetKm'] ?? "?"}→${r['newDistanceKm'] ?? "?"})');
      case 'config_update':
        open?.interEvents.add('config_update');
      case 'reset':
        // reset ends the current stage without a result.
        if (open != null) {
          open.stopTs = _ts(r);
          open = null;
        }
      default:
        break;
    }
  }
  return stages;
}