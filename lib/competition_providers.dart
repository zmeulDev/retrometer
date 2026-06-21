import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services/device_service.dart';
import 'services/gps_service.dart';
import 'state_providers.dart';

const _kCompetitionsKey = 'retrometer.competitions';

/// Legacy flat-schedule key (pre-competition versions). Used only for one-time
/// migration into a default competition on first load.
const _kLegacyScheduleKey = 'retrometer.schedule';

/// How often the auto-start monitor polls the clock + location.
const _autoStartPollInterval = Duration(seconds: 5);

/// If a stage's start time is this far in the past, it's considered missed and
/// won't auto-start (avoids firing a stale stage on a late app launch).
const _autoStartGraceWindow = Duration(minutes: 10);

/// Stages starting within this horizon from now count as "pending" and keep
/// the screen awake so the timer can fire (foreground-only app: the OS
/// suspends timers when the screen locks).
const _autoStartAwakeHorizon = Duration(hours: 24);

/// A planned stage paired with the competition it belongs to. Produced by
/// flattening all competitions' stages, so the auto-start monitor (and any
/// cross-competition logic) can iterate a single list while still knowing
/// which competition owns each stage (needed to mark it started).
class ScheduledStage {
  const ScheduledStage({required this.competition, required this.stage});

  final Competition competition;
  final PlannedStage stage;
}

/// Persisted list of competitions, each owning its stages.
///
/// Hydrated from `SharedPreferences` on first build; every mutation is written
/// back so the plan survives restarts (plan in the morning, drive later). On
/// the very first load, if a legacy flat schedule exists (pre-competition
/// versions), it is migrated into a single "Importate" competition so no
/// planned data is lost.
class CompetitionNotifier extends AsyncNotifier<List<Competition>> {
  @override
  Future<List<Competition>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_kCompetitionsKey);
    if (encoded != null) return competitionsFromJson(encoded);

    // First launch on a pre-competition install: migrate the flat schedule.
    final legacy = prefs.getString(_kLegacyScheduleKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      final stages = plannedStagesFromJson(legacy);
      if (stages.isNotEmpty) {
        final migrated = [
          Competition(
            id: 'comp-${DateTime.now().millisecondsSinceEpoch}',
            name: 'Importate',
            stages: stages,
          ),
        ];
        await prefs.setString(_kCompetitionsKey, competitionsToJson(migrated));
        return migrated;
      }
    }
    return const [];
  }

  Future<void> _persist(List<Competition> competitions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCompetitionsKey, competitionsToJson(competitions));
  }

  /// All stages across all competitions, flattened (earliest-first is the UI's
  /// job; here we preserve competition/stage order).
  List<ScheduledStage> flatten() {
    final comps = state.valueOrNull ?? const <Competition>[];
    return [
      for (final c in comps)
        for (final s in c.stages) ScheduledStage(competition: c, stage: s),
    ];
  }

  /// Add a new competition.
  Future<void> addCompetition(Competition competition) async {
    final current = state.valueOrNull ?? const <Competition>[];
    final next = <Competition>[...current, competition];
    state = AsyncData(next);
    await _persist(next);
  }

  /// Replace an existing competition by id.
  Future<void> updateCompetition(Competition competition) async {
    final current = state.valueOrNull ?? const <Competition>[];
    final next = <Competition>[
      for (final c in current)
        if (c.id == competition.id) competition else c,
    ];
    state = AsyncData(next);
    await _persist(next);
  }

  /// Remove a competition (and its stages) by id.
  Future<void> removeCompetition(String id) async {
    final current = state.valueOrNull ?? const <Competition>[];
    final next = <Competition>[for (final c in current) if (c.id != id) c];
    state = AsyncData(next);
    await _persist(next);
  }

  /// Add a stage to a competition.
  Future<void> addStage(String competitionId, PlannedStage stage) async {
    final current = state.valueOrNull ?? const <Competition>[];
    final next = <Competition>[
      for (final c in current)
        if (c.id == competitionId)
          c.copyWith(stages: [...c.stages, stage])
        else
          c,
    ];
    state = AsyncData(next);
    await _persist(next);
  }

  /// Replace an existing stage by id within a competition.
  Future<void> updateStage(
    String competitionId,
    PlannedStage stage,
  ) async {
    final current = state.valueOrNull ?? const <Competition>[];
    final next = <Competition>[
      for (final c in current)
        if (c.id == competitionId)
          c.copyWith(
            stages: [
              for (final s in c.stages) if (s.id == stage.id) stage else s,
            ],
          )
        else
          c,
    ];
    state = AsyncData(next);
    await _persist(next);
  }

  /// Remove a stage by id from a competition.
  Future<void> removeStage(String competitionId, String stageId) async {
    final current = state.valueOrNull ?? const <Competition>[];
    final next = <Competition>[
      for (final c in current)
        if (c.id == competitionId)
          c.copyWith(
            stages: [for (final s in c.stages) if (s.id != stageId) s],
          )
        else
          c,
    ];
    state = AsyncData(next);
    await _persist(next);
  }

  /// Mark a stage as started (auto-start or manual) so it won't re-trigger.
  Future<void> markStarted(String competitionId, String stageId) async {
    final current = state.valueOrNull ?? const <Competition>[];
    final next = <Competition>[
      for (final c in current)
        if (c.id == competitionId)
          c.copyWith(
            stages: [
              for (final s in c.stages)
                if (s.id == stageId) s.copyWith(started: true) else s,
            ],
          )
        else
          c,
    ];
    state = AsyncData(next);
    await _persist(next);
  }
}

/// Provider for the persisted list of competitions.
final competitionsProvider =
    AsyncNotifierProvider<CompetitionNotifier, List<Competition>>(
  CompetitionNotifier.new,
);

/// The competition the currently-active stage belongs to, if any. Matches the
/// running stage's config id against the stages across all competitions.
/// `null` when no stage is running or the running stage isn't from a planned
/// competition (e.g. a quick ad-hoc START from the cockpit).
final activeCompetitionProvider = Provider<Competition?>((ref) {
  final stageId = ref.watch(
    stageControllerProvider.select((s) => s.config.id),
  );
  if (stageId.isEmpty) return null;
  final comps =
      ref.watch(competitionsProvider).valueOrNull ?? const <Competition>[];
  for (final c in comps) {
    if (c.stages.any((s) => s.id == stageId)) return c;
  }
  return null;
});

/// Diagnostics surfaced to the UI so the crew can see *why* auto-start did or
/// didn't fire (last check, next due stage, last fix, last reason).
class AutoStartStatus {
  const AutoStartStatus({
    this.lastTick,
    this.message = 'monitor oprit',
    this.nextDueName,
    this.lastFixAccuracyM,
    this.lastDistanceM,
    this.lastStageId,
  });

  final DateTime? lastTick;
  final String message;
  final String? nextDueName;
  final double? lastFixAccuracyM;
  final double? lastDistanceM;
  final String? lastStageId;

  AutoStartStatus copyWith({
    DateTime? lastTick,
    String? message,
    String? nextDueName,
    double? lastFixAccuracyM,
    double? lastDistanceM,
    String? lastStageId,
  }) =>
      AutoStartStatus(
        lastTick: lastTick ?? this.lastTick,
        message: message ?? this.message,
        nextDueName: nextDueName ?? this.nextDueName,
        lastFixAccuracyM: lastFixAccuracyM ?? this.lastFixAccuracyM,
        lastDistanceM: lastDistanceM ?? this.lastDistanceM,
        lastStageId: lastStageId ?? this.lastStageId,
      );
}

/// Watches the clock + competitions + current stage status and auto-starts a
/// planned stage when its time is due **and** the device is inside the
/// stage's geofence.
///
/// Iterates all stages across all competitions (flattened). The cockpit keeps
/// this alive by `ref.watch`-ing it. Polls every [_autoStartPollInterval] and
/// only acts while no stage is running (idle or completed), so it never
/// clobbers a running stage but **does** auto-start the next planned stage
/// after a previous one finishes.
///
/// **Foreground-only caveat:** the app has no background service, so the OS
/// suspends timers when the screen locks / the app is backgrounded. To keep
/// the timer firing up to the start time, the monitor holds a wakelock while
/// any pending auto-start stage exists (see [_autoStartAwakeHorizon]). This
/// trades some battery for reliability — the screen stays on. If the crew
/// backgrounds the app, auto-start may still miss; a foreground service would
/// be needed for true background reliability (out of scope here).
class AutoStartMonitor extends Notifier<AutoStartStatus> {
  Timer? _timer;
  bool _busy = false;

  @override
  AutoStartStatus build() {
    // Re-arm whenever the stage status flips. We poll while a stage is NOT
    // running (idle OR completed), so a finished stage doesn't block the next
    // one from auto-starting. Also watch the competitions so adding/editing a
    // stage rebuilds → immediate tick.
    final status = ref.watch(
      stageControllerProvider.select((s) => s.telemetry.status),
    );
    ref.watch(competitionsProvider);
    _timer?.cancel();
    if (status != StageStatus.inProgress) {
      _timer = Timer.periodic(_autoStartPollInterval, (_) => _tick());
      // Fire once immediately so a due stage starts without waiting.
      _tick();
    }
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return const AutoStartStatus(message: 'monitor pornit');
  }

  /// True if [s] still needs auto-start and starts within the awake horizon.
  bool _isPending(PlannedStage s, DateTime now) {
    if (!s.autoStart || s.started) return false;
    final delta = now.difference(s.startTime);
    // Not yet missed (within grace) and not too far in the future.
    return delta <= _autoStartGraceWindow &&
        s.startTime.isBefore(now.add(_autoStartAwakeHorizon));
  }

  void _setStatus(String message, {DateTime? now}) {
    // Guard: setting state on a disposed element throws.
    try {
      state = state.copyWith(message: message, lastTick: now ?? state.lastTick);
    } on StateError {
      // provider disposed mid-tick — ignore.
    }
  }

  Future<void> _tick() async {
    if (_busy) return; // a previous tick is still collecting a GPS fix
    _busy = true;
    try {
      await _tickInner();
    } finally {
      _busy = false;
    }
  }

  Future<void> _tickInner() async {
    // Resolve every dependency up front, before any awaited state change. The
    // monitor rebuilds when the stage status flips (it watches it), which can
    // invalidate `ref` mid-flight for an in-flight async tick.
    final competitions = ref.read(competitionsProvider.notifier);
    final stageController = ref.read(stageControllerProvider.notifier);
    final device = ref.read(deviceServiceProvider);
    final gps = ref.read(gpsServiceProvider);

    final all = ref.read(competitionsProvider).valueOrNull;
    final now = DateTime.now();
    if (all == null || all.isEmpty) {
      await device.disableWakelock();
      _setStatus('niciun stage programat', now: now);
      return;
    }
    final stages = competitions.flatten();
    if (stages.isEmpty) {
      await device.disableWakelock();
      _setStatus('niciun stage programat', now: now);
      return;
    }
    if (ref.read(stageControllerProvider).telemetry.status ==
        StageStatus.inProgress) {
      return;
    }

    // Keep the screen awake while any stage is pending auto-start (wakelock is
    // idempotent; StageController separately holds it during a running stage).
    if (stages.any((ss) => _isPending(ss.stage, now))) {
      await device.enableWakelock();
    } else {
      await device.disableWakelock();
    }

    // The next pending stage (for diagnostics), earliest first.
    final pending = stages
        .where((ss) => _isPending(ss.stage, now))
        .toList()
      ..sort((a, b) => a.stage.startTime.compareTo(b.stage.startTime));

    final due = stages.where((ss) {
      final s = ss.stage;
      if (!s.autoStart || s.started) return false;
      final delta = now.difference(s.startTime);
      // 0 <= elapsed <= grace window.
      return !delta.isNegative && delta <= _autoStartGraceWindow;
    }).toList()
      ..sort((a, b) => a.stage.startTime.compareTo(b.stage.startTime));

    if (due.isEmpty) {
      final next = pending.isEmpty
          ? null
          : '${pending.first.stage.name} la ${_hm(pending.first.stage.startTime)}';
      try {
        state = state.copyWith(
          message: pending.isEmpty ? 'nimic due' : 'așteptare',
          nextDueName: next,
          lastTick: now,
        );
      } on StateError {
        // ignore
      }
      return;
    }

    if (!await gps.isLocationServiceEnabled()) {
      _setStatus('GPS dezactivat', now: now);
      return;
    }
    var permission = await gps.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await gps.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _setStatus('permisiune locație refuzată', now: now);
      return;
    }

    // Collect fixes for up to 12 s and keep the most accurate one. A cold first
    // fix can be kilometres off; waiting a few seconds for a tighter fix avoids
    // silently failing the geofence check.
    Position? best;
    var bestAcc = double.infinity;
    try {
      final stream = gps.positionStream().timeout(
        const Duration(seconds: 12),
        onTimeout: (s) => s.close(),
      );
      await for (final p in stream) {
        final acc = p.accuracy.isNaN ? double.infinity : p.accuracy;
        if (acc < bestAcc) {
          bestAcc = acc;
          best = p;
        }
        if (acc <= 50) break; // good enough
      }
    } on Exception {
      // keep whatever fix we collected
    }
    if (best == null) {
      _setStatus('nu am primit fix GPS', now: now);
      return;
    }

    for (final ss in due) {
      if (ref.read(stageControllerProvider).telemetry.status ==
          StageStatus.inProgress) {
        return;
      }
      final stage = ss.stage;
      final distance = gps.distanceBetween(
        startLatitude: best.latitude,
        startLongitude: best.longitude,
        endLatitude: stage.latitude,
        endLongitude: stage.longitude,
      );
      try {
        state = AutoStartStatus(
          lastTick: now,
          message: distance <= stage.geofenceRadiusM
              ? 'pornesc ${stage.name}…'
              : 'în afara geofence-ului',
          nextDueName: stage.name,
          lastFixAccuracyM: bestAcc,
          lastDistanceM: distance,
          lastStageId: stage.id,
        );
      } on StateError {
        // ignore
      }
      if (distance <= stage.geofenceRadiusM) {
        // StageController will (re)hold the wakelock for the running stage.
        await device.disableWakelock();
        await stageController.startStageFromPlan(stage);
        await competitions.markStarted(ss.competition.id, stage.id);
        return; // a stage is now running
      }
    }
  }
}

String _hm(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.hour)}:${two(dt.minute)}';
}

/// Provider for the auto-start monitor. Keep it alive by watching it from the
/// cockpit (its value carries diagnostics shown in the competition screens).
final autoStartMonitorProvider =
    NotifierProvider<AutoStartMonitor, AutoStartStatus>(AutoStartMonitor.new);