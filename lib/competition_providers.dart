import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// How long the auto-start prompt is suppressed after the crew taps "Nu"
/// (declines starting a stage). Prevents re-prompting every tick (5 s) while a
/// condition stays met.
const _autoStartSnooze = Duration(minutes: 5);

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

  /// Persist a finished stage's captured [result] onto its planned stage. Searched
  /// by stage id across all competitions (the running stage knows its config id,
  /// not which competition owns it). No-op if the stage isn't found in any
  /// competition (e.g. an ad-hoc stage started from the cockpit without a plan).
  Future<void> markResult(String stageId, StageResult result) async {
    final current = state.valueOrNull ?? const <Competition>[];
    final next = <Competition>[
      for (final c in current)
        c.copyWith(
          stages: [
            for (final s in c.stages)
              if (s.id == stageId) s.copyWith(result: result) else s,
          ],
        ),
    ];
    state = AsyncData(next);
    await _persist(next);
  }

  /// Append a finished stage's run to the owning competition's history log.
  /// Searched by stage id across all competitions (the running stage knows its
  /// config id, not which competition owns it). No-op for ad-hoc stages whose id
  /// isn't in any competition (same convention as [markResult]).
  Future<void> appendHistory(String stageId, StageRunHistory entry) async {
    final current = state.valueOrNull ?? const <Competition>[];
    final next = <Competition>[
      for (final c in current)
        c.copyWith(
          history: c.stages.any((s) => s.id == stageId)
              ? [...c.history, entry]
              : c.history,
        ),
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
/// didn't fire (last check, next due stage, last fix, last reason), plus the
/// pending confirmation prompt (if any).
class AutoStartStatus {
  const AutoStartStatus({
    this.lastTick,
    this.message = 'monitor oprit',
    this.nextDueName,
    this.lastFixAccuracyM,
    this.lastDistanceM,
    this.lastStageId,
    this.pendingPrompt,
  });

  final DateTime? lastTick;
  final String message;
  final String? nextDueName;
  final double? lastFixAccuracyM;
  final double? lastDistanceM;
  final String? lastStageId;

  /// A stage whose time OR location condition is met, awaiting the crew's
  /// confirmation before it starts. The cockpit shows a "Doriți să porniți
  /// X?" dialog while this is non-null. `null` = no prompt pending.
  final ScheduledStage? pendingPrompt;

  /// Like a plain copyWith, but [pendingPrompt] uses a sentinel so it can be
  /// cleared to `null` (pass `pendingPrompt: null` explicitly); omitting it
  /// preserves the current value.
  AutoStartStatus copyWith({
    DateTime? lastTick,
    String? message,
    String? nextDueName,
    double? lastFixAccuracyM,
    double? lastDistanceM,
    String? lastStageId,
    Object? pendingPrompt = _unset,
  }) {
    final pp = identical(pendingPrompt, _unset)
        ? this.pendingPrompt
        : pendingPrompt as ScheduledStage?;
    return AutoStartStatus(
      lastTick: lastTick ?? this.lastTick,
      message: message ?? this.message,
      nextDueName: nextDueName ?? this.nextDueName,
      lastFixAccuracyM: lastFixAccuracyM ?? this.lastFixAccuracyM,
      lastDistanceM: lastDistanceM ?? this.lastDistanceM,
      lastStageId: lastStageId ?? this.lastStageId,
      pendingPrompt: pp,
    );
  }
}

/// Sentinel for [AutoStartStatus.copyWith]'s nullable-clearing argument.
const _unset = Object();

/// Watches the clock + competitions + current stage status and prompts the
/// crew to start a planned stage when **either** its time is due **or** the
/// device is inside the stage's geofence (each optional — a stage may be
/// time-only, location-only, or both).
///
/// Instead of silently auto-starting, it surfaces a pending prompt
/// ([AutoStartStatus.pendingPrompt]) that the cockpit turns into a
/// "Doriți să porniți X?" dialog. The crew confirms ([confirmPending]) or
/// declines ([dismissPending], which snoozes the stage for
/// [_autoStartSnooze] so it isn't re-prompted every tick).
///
/// Iterates all stages across all competitions (flattened). The cockpit keeps
/// this alive by `ref.watch`-ing it. Polls every [_autoStartPollInterval] and
/// only acts while no stage is running (idle or completed), so it never
/// clobbers a running stage but **does** prompt for the next planned stage
/// after a previous one finishes.
///
/// Two evaluation passes per tick keep GPS off when it isn't needed:
/// - **Pass 1 (time):** no GPS. A stage with a `startTime` whose time is due
///   (within the grace window) prompts immediately. If any time-met stage is
///   found, the tick returns — GPS is never acquired.
/// - **Pass 2 (location):** only if Pass 1 found nothing and at least one armed
///   stage has start coords. Acquires a GPS fix and prompts for the first armed
///   stage whose geofence contains the device.
///
/// **Foreground-only caveat:** the app has no background service, so the OS
/// suspends timers when the screen locks / the app is backgrounded. To keep
/// the timer firing up to a scheduled start time, the monitor holds a wakelock
/// while any time-pending stage exists (see [_autoStartAwakeHorizon]) or while a
/// prompt is on screen. Location-only stages (no `startTime`) don't hold the
/// wakelock — they rely on the 5 s poll while the app is foregrounded.
class AutoStartMonitor extends Notifier<AutoStartStatus> {
  Timer? _timer;
  bool _busy = false;

  /// Per-stage snooze-until timestamps, set when the crew declines a prompt.
  final Map<String, DateTime> _snooze = {};

  /// Clock source, overridable in tests to exercise snooze expiry without
  /// waiting real time.
  @visibleForTesting
  DateTime Function() now = DateTime.now;

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
      // Fire once immediately so a due stage prompts without waiting. Called
      // directly (not deferred): the synchronous prefix of _tickInner must not
      // read `state` (it isn't committed until build() returns), but may use
      // `ref.read` (dependencies haven't changed yet at this point). The first
      // `state` read happens only after the first `await` inside _tickInner.
      _tick();
    }
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return const AutoStartStatus(message: 'monitor pornit');
  }

  /// True if [s] still needs auto-start and starts within the awake horizon.
  /// Location-only stages (no `startTime`) return false — they have no
  /// scheduled wake to keep the screen on for.
  bool _isPending(PlannedStage s, DateTime now) {
    if (!s.autoStart || s.started) return false;
    final start = s.startTime;
    if (start == null) return false;
    final delta = now.difference(start);
    // Not yet missed (within grace) and not too far in the future.
    return delta <= _autoStartGraceWindow &&
        start.isBefore(now.add(_autoStartAwakeHorizon));
  }

  /// Whether [s] can trigger a prompt this tick: autoStart on, not started, has
  /// at least one trigger source (time or location), and not currently snoozed.
  bool _isArmed(PlannedStage s, DateTime now) {
    if (!s.autoStart || s.started) return false;
    final hasTime = s.startTime != null;
    final hasLoc = s.latitude != null && s.longitude != null;
    if (!hasTime && !hasLoc) return false; // nothing to trigger on
    final until = _snooze[s.id];
    return until == null || !until.isAfter(now);
  }

  /// Time condition met: `startTime` set and within the grace window (not
  /// future, not missed).
  bool _timeMet(PlannedStage s, DateTime now) {
    final start = s.startTime;
    if (start == null) return false;
    final delta = now.difference(start);
    return !delta.isNegative && delta <= _autoStartGraceWindow;
  }

  void _setStatus(String message, {DateTime? now}) {
    try {
      state =
          state.copyWith(message: message, lastTick: now ?? state.lastTick);
    } on StateError {
      // provider disposed mid-tick — ignore.
    }
  }

  /// Surface [ss] as the pending prompt (with a human [reason]).
  void _setPending(ScheduledStage ss, DateTime now, String reason,
      {double? fixAccuracy, double? distance}) {
    try {
      state = AutoStartStatus(
        lastTick: now,
        message: '${ss.stage.name}: $reason — confirmă?',
        nextDueName: ss.stage.name,
        lastFixAccuracyM: fixAccuracy,
        lastDistanceM: distance,
        lastStageId: ss.stage.id,
        pendingPrompt: ss,
      );
    } on StateError {
      // ignore
    }
  }

  /// Clear the pending prompt (preserve diagnostics).
  void _clearPending() {
    try {
      state = state.copyWith(pendingPrompt: null);
    } on StateError {
      // ignore
    }
  }

  /// Confirm the pending prompt: start the stage and mark it started. Called
  /// from the cockpit dialog after the location disclosure is accepted.
  Future<void> confirmPending() async {
    final ss = state.pendingPrompt;
    if (ss == null) return;
    // Resolve every dependency up front — startStageFromPlan flips the stage
    // status, which rebuilds this monitor and invalidates `ref` mid-flight
    // (the same gotcha _tickInner guards against).
    final competitions = ref.read(competitionsProvider.notifier);
    final stageController = ref.read(stageControllerProvider.notifier);
    final device = ref.read(deviceServiceProvider);
    // Clear the prompt + snooze first so a rebuild during the awaits can't
    // re-surface it.
    _snooze.remove(ss.stage.id);
    _clearPending();
    try {
      await device.disableWakelock();
      await stageController.startStageFromPlan(ss.stage);
      await competitions.markStarted(ss.competition.id, ss.stage.id);
    } on StateError {
      // provider disposed mid-flight — ignore
    }
  }

  /// Decline the pending prompt: snooze the stage for [snooze] (default
  /// [_autoStartSnooze]) so it isn't re-prompted every tick. After the snooze
  /// expires, if a condition is still met, it prompts again.
  void dismissPending({Duration? snooze}) {
    final ss = state.pendingPrompt;
    if (ss == null) return;
    _snooze[ss.stage.id] = now().add(snooze ?? _autoStartSnooze);
    _clearPending();
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
    final now = this.now();
    if (all == null || all.isEmpty) {
      debugPrint('[autostart] no competitions loaded');
      await device.disableWakelock();
      _setStatus('niciun stage programat', now: now);
      return;
    }
    final stages = competitions.flatten();
    if (stages.isEmpty) {
      debugPrint('[autostart] no stages across competitions');
      await device.disableWakelock();
      _setStatus('niciun stage programat', now: now);
      return;
    }
    if (stageController.telemetry.status == StageStatus.inProgress) {
      debugPrint('[autostart] a stage is already inProgress — skip tick');
      return;
    }

    // Clean up snooze entries for stages no longer armed (deleted, autoStart
    // off, or started) so the map can't grow unbounded.
    final byId = {for (final ss in stages) ss.stage.id: ss.stage};
    _snooze.removeWhere((id, _) {
      final s = byId[id];
      return s == null || !s.autoStart || s.started;
    });

    debugPrint('[autostart] tick now=$now stages=${stages.length}');
    for (final ss in stages) {
      final s = ss.stage;
      final deltaStr = s.startTime == null
          ? '—'
          : '${now.difference(s.startTime!).inSeconds}s '
              '(${now.difference(s.startTime!).isNegative ? "future" : "past"})';
      debugPrint(
        '[autostart]   stage "${s.name}" (id=${s.id}) '
        'autoStart=${s.autoStart} started=${s.started} '
        'startTime=${s.startTime?.toIso8601String() ?? "—"} delta=$deltaStr '
        'lat=${s.latitude?.toStringAsFixed(5) ?? "—"} '
        'lng=${s.longitude?.toStringAsFixed(5) ?? "—"} '
        'radius=${s.geofenceRadiusM}m'
        '${_snooze[s.id] != null ? " snoozed" : ""}',
      );
    }

    // Keep the screen awake while any time-pending stage exists (wakelock is
    // idempotent; StageController separately holds it during a running stage).
    // Location-only stages don't hold it (no scheduled wake) — a pending prompt
    // re-arms it below. This is the first `await` on the main path; `state` is
    // only safe to read after it returns (see the build() note above).
    final wantWake = stages.any((ss) => _isPending(ss.stage, now));
    if (wantWake) {
      await device.enableWakelock();
    } else {
      await device.disableWakelock();
    }

    // A prompt is already on screen — don't re-evaluate (avoids re-prompting
    // the same stage every tick and saves the GPS cost while the dialog is up).
    // Read after the wakelock await so `state` is committed (and guard against
    // the monitor being disposed mid-tick).
    final ScheduledStage? pendingPrompt;
    try {
      pendingPrompt = state.pendingPrompt;
    } on StateError {
      return; // monitor disposed mid-tick — nothing to do.
    }
    if (pendingPrompt != null) {
      debugPrint(
        '[autostart] prompt pending for "${pendingPrompt.stage.name}" '
        '— skip tick',
      );
      // Keep the screen on while a prompt is on screen (idempotent with the
      // wakelock block above; forces ON even for location-only stages where
      // _isPending returned false).
      await device.enableWakelock();
      return;
    }

    // Next pending stage (diagnostics), earliest first.
    final pending = stages
        .where((ss) => _isPending(ss.stage, now))
        .toList()
      ..sort(_byStartThenId);

    final armedStages = stages.where((ss) => _isArmed(ss.stage, now)).toList();

    // --- Pass 1: time-met stages (no GPS) -------------------------------
    final timeMet = armedStages
        .where((ss) => _timeMet(ss.stage, now))
        .toList()
      ..sort(_byStartThenId);
    if (timeMet.isNotEmpty) {
      final chosen = timeMet.first;
      debugPrint('[autostart] time-met "${chosen.stage.name}" — prompting');
      _setPending(chosen, now, 'la ora ${_hm(chosen.stage.startTime)}');
      return;
    }

    // --- Pass 2: location-met stages (GPS) -----------------------------
    final locStages = armedStages
        .where((ss) => ss.stage.latitude != null && ss.stage.longitude != null)
        .toList()
      ..sort(_byStartThenId);
    if (locStages.isEmpty) {
      // No armed stage can trigger right now (time not met, no location).
      debugPrint('[autostart] no trigger candidate — diagnostics only');
      final next = pending.isEmpty
          ? null
          : '${pending.first.stage.name} la ${_hm(pending.first.stage.startTime)}';
      try {
        state = state.copyWith(
          message: pending.isEmpty ? 'așteptare' : 'așteptare',
          nextDueName: next,
          lastTick: now,
        );
      } on StateError {
        // ignore
      }
      return;
    }

    if (!await gps.isLocationServiceEnabled()) {
      debugPrint('[autostart] GPS service disabled — abort location pass');
      _setStatus('GPS dezactivat', now: now);
      return;
    }
    var permission = await gps.checkPermission();
    debugPrint('[autostart] checkPermission=$permission');
    if (permission == LocationPermission.denied) {
      permission = await gps.requestPermission();
      debugPrint('[autostart] after requestPermission=$permission');
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('[autostart] location permission refused — abort location pass');
      _setStatus('permisiune locație refuzată', now: now);
      return;
    }

    // Acquire a position. Use the OS last-known fix first (instant, no
    // cold-start) — it's fine for a hundreds-of-metres geofence. A fresh
    // high-accuracy stream pays a cold-start tax on every tick and, on a
    // stationary device, FusedLocationProvider may throttle it to zero fixes
    // within a short window. Fall back to a fresh getCurrentPosition only when
    // last-known is missing or stale (> 5 min).
    Position? best = await gps.getLastKnownPosition();
    if (best == null ||
        now.difference(best.timestamp) > const Duration(minutes: 5)) {
      debugPrint('[autostart] last-known missing/stale — requesting fresh fix');
      try {
        best = await gps.getCurrentPosition(
          timeLimit: const Duration(seconds: 15),
        );
      } on Exception {
        // fresh acquisition failed; keep whatever we have (last-known or null)
      }
    }
    if (best == null) {
      debugPrint('[autostart] no GPS fix acquired — abort location pass');
      _setStatus('nu am primit fix GPS', now: now);
      return;
    }
    final bestAcc = best.accuracy.isNaN ? double.infinity : best.accuracy;
    debugPrint(
      '[autostart] fix lat=${best.latitude} lng=${best.longitude} '
      'accuracy=${bestAcc.toStringAsFixed(1)}m',
    );

    // Find the first location-met stage (sorted), reporting each distance.
    ScheduledStage? met;
    double? metDistance;
    for (final ss in locStages) {
      // Read status via the notifier (captured up front) — `ref` is invalidated
      // once the status flips, so `ref.read` would hit the !_didChangeDependency
      // assertion. The notifier's `telemetry` getter reads its own live state.
      if (stageController.telemetry.status == StageStatus.inProgress) {
        debugPrint('[autostart] stage went inProgress mid-loop — stop');
        return;
      }
      final s = ss.stage;
      final distance = gps.distanceBetween(
        startLatitude: best.latitude,
        startLongitude: best.longitude,
        endLatitude: s.latitude!,
        endLongitude: s.longitude!,
      );
      debugPrint(
        '[autostart] loc "${s.name}" distance=${distance.toStringAsFixed(1)}m '
        'vs radius=${s.geofenceRadiusM}m '
        'inGeofence=${distance <= s.geofenceRadiusM}',
      );
      if (distance <= s.geofenceRadiusM) {
        met = ss;
        metDistance = distance;
        break;
      }
    }

    if (met != null) {
      debugPrint('[autostart] location-met "${met.stage.name}" — prompting');
      _setPending(
        met,
        now,
        'în geofence (${metDistance!.toStringAsFixed(0)} m)',
        fixAccuracy: bestAcc,
        distance: metDistance,
      );
      return;
    }

    // Location pass found nothing in-geofence.
    debugPrint('[autostart] no stage in geofence — diagnostics only');
    _setStatus('în afara geofence-ului', now: now);
  }
}

/// Sentinel that sorts after any real start time (used for null `startTime`).
final _maxDate = DateTime(9999, 12, 31, 23, 59);

/// Sort armed stages earliest `startTime` first (null sorts last), then by id
/// for a deterministic order when two stages share a start time.
int _byStartThenId(ScheduledStage a, ScheduledStage b) {
  final c = (a.stage.startTime ?? _maxDate)
      .compareTo(b.stage.startTime ?? _maxDate);
  if (c != 0) return c;
  return a.stage.id.compareTo(b.stage.id);
}

String _hm(DateTime? dt) {
  if (dt == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.hour)}:${two(dt.minute)}';
}

/// Provider for the auto-start monitor. Keep it alive by watching it from the
/// cockpit (its value carries diagnostics shown in the competition screens).
final autoStartMonitorProvider =
    NotifierProvider<AutoStartMonitor, AutoStartStatus>(AutoStartMonitor.new);

/// Persists a finished stage's captured result onto its owning planned stage,
/// and appends a [StageRunHistory] entry to the owning competition's history
/// log. Listens for [StageController]'s telemetry status flipping `inProgress →
/// completed` with a non-null `result`, then writes it via
/// [CompetitionNotifier.markResult] and appends the history entry via
/// [CompetitionNotifier.appendHistory]. The cockpit keeps this alive by
/// `ref.watch`-ing it (alongside the auto-start monitor). No-op for ad-hoc
/// stages whose config id isn't in any competition.
final stageResultPersisterProvider = Provider<void>((ref) {
  ref.listen<StageStatus>(
    stageControllerProvider.select((s) => s.telemetry.status),
    (previous, next) {
      final wasRunning = previous == StageStatus.inProgress;
      if (!wasRunning || next != StageStatus.completed) return;
      final rally = ref.read(stageControllerProvider);
      final result = rally.telemetry.result;
      final stageId = rally.config.id;
      if (result == null || stageId.isEmpty) return;
      // Fire-and-forget; persistence is best-effort and must not block the UI.
      final notifier = ref.read(competitionsProvider.notifier);
      notifier.markResult(stageId, result);

      // Build a history entry. Look up the owning competition + planned stage to
      // snapshot the competition name and the stage's planned start coords.
      final comps =
          ref.read(competitionsProvider).valueOrNull ?? const <Competition>[];
      String competitionName = '';
      double? startLatitude;
      double? startLongitude;
      for (final c in comps) {
        final match = c.stages.where((s) => s.id == stageId).firstOrNull;
        if (match != null) {
          competitionName = c.name;
          startLatitude = match.latitude;
          startLongitude = match.longitude;
          break;
        }
      }
      final entry = StageRunHistory(
        id: 'run-$stageId-${result.completedAt?.millisecondsSinceEpoch ?? 0}',
        stageId: stageId,
        stageName: rally.config.name,
        competitionName: competitionName,
        startedAt: rally.telemetry.startTime,
        completedAt: result.completedAt,
        startLatitude: startLatitude,
        startLongitude: startLongitude,
        endLatitude: rally.config.endLatitude,
        endLongitude: rally.config.endLongitude,
        targetAvgSpeed: rally.config.targetAvgSpeed,
        maxSpeedLimit: rally.config.maxSpeedLimit,
        maxSpeedKmh: result.maxSpeedKmh,
        minSpeedKmh: result.minSpeedKmh,
        avgSpeedKmh: result.avgSpeedKmh,
        totalDistanceKm: result.totalDistanceKm,
        elapsedSeconds: result.elapsedSeconds,
      );
      notifier.appendHistory(stageId, entry);
    },
  );
});