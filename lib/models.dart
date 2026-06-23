import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';

/// Lifecycle of the active stage.
enum StageStatus { idle, inProgress, paused, completed }

/// Colour band for the Δ indicator, derived from [StageTelemetry] vs the
/// ideal time. Kept as a value so the UI can `select` on it without rebuilding
/// for unrelated telemetry changes.
enum DeltaBand {
  /// |Δt| <= 1s — on schedule.
  onTime,
  /// Δt < 0 — ahead (driving faster than the imposed average).
  advance,
  /// Δt > 0 — late (driving slower than the imposed average).
  delay,
}

/// Live GPS fix quality, derived from [positionProvider] for the status LED.
enum GpsFixStatus {
  /// We have a position fix — green.
  fixed,
  /// Streaming but no fix yet (loading) — amber (searching).
  searching,
  /// Service off or permission denied (stream errored) — red.
  unavailable,
}

/// Immutable configuration for the single active stage.
///
/// Speeds are in km/h. `targetAvgSpeed` is the imposed average used to compute
/// the ideal time; `maxSpeedLimit` is the hard limit that triggers the
/// over-speed alert.
///
/// `endLatitude`/`endLongitude` (nullable) mark the stage finish; when set and
/// [autoStop] is true, the stage auto-stops once the device enters
/// [endGeofenceRadiusM] of the finish. `totalDistanceKm` and
/// `allocatedTimeSeconds` are the crew-entered plan values (0 = not set),
/// used for display/reference only — live distance/time come from telemetry.
@freezed
class StageConfig with _$StageConfig {
  const factory StageConfig({
    required String id,
    @Default('Stage 1') String name,
    @Default(40.0) double targetAvgSpeed,
    @Default(60.0) double maxSpeedLimit,
    double? endLatitude,
    double? endLongitude,
    @Default(200.0) double endGeofenceRadiusM,
    @Default(true) bool autoStop,
    @Default(0.0) double totalDistanceKm,
    @Default(0) int allocatedTimeSeconds,
  }) = _StageConfig;
}

/// Live measurements for the active stage.
///
/// `currentDistance` is in **kilometres**, accumulated from the GPS stream.
/// `currentSpeed` is in **km/h**. `startTime` is the wall-clock moment
/// [StageController.startStage] was called; null while idle. `latitude`/
/// `longitude` are the latest GPS fix (null while idle), used for reverse
/// geocoding the current locality.
///
/// `maxSpeedKmh`/`minSpeedKmh` aggregate the per-fix speeds for the stage
/// result: `max` starts at 0, `min` is `null` until the first fix (then it
/// tracks the lowest speed seen, **including 0** — stops are legit readings).
/// Reset to defaults on every [StageController.startStage].
///
/// Pause bookkeeping: `pausedSince` is the wall-clock moment the crew paused an
/// in-progress stage (null otherwise); `pauseOffsetSeconds` is the cumulative
/// paused duration subtracted from raw elapsed so the timer freezes during
/// pauses and resumes without a jump. Both reset on start/reset.
///
/// `result` is the transient snapshot set when the stage stops — picked up by
/// the result-persister provider to write it onto the owning `PlannedStage`.
/// Cleared on the next start/reset.
@freezed
class StageTelemetry with _$StageTelemetry {
  const factory StageTelemetry({
    DateTime? startTime,
    @Default(0.0) double currentDistance,
    @Default(0.0) double currentSpeed,
    @Default(StageStatus.idle) StageStatus status,
    double? latitude,
    double? longitude,
    @Default(0.0) double maxSpeedKmh,
    double? minSpeedKmh,
    DateTime? pausedSince,
    @Default(0) int pauseOffsetSeconds,
    StageResult? result,
  }) = _StageTelemetry;
}

/// Captured result of a finished stage: the real (GPS-derived) speed stats,
/// snapshot at [StageController.stopStage]. Persisted on the owning
/// [PlannedStage] as `result` so the crew can review per-stage performance.
///
/// `avgSpeedKmh` is the physical average — `totalDistanceKm / elapsedHours`
/// — not the arithmetic mean of instantaneous samples (avoids float drift and
/// weights correctly by time). `max`/`min` are the instantaneous extremes
/// from the stream. `minSpeedKmh` is `null` only when no fix was ever received.
@freezed
class StageResult with _$StageResult {
  const StageResult._();

  const factory StageResult({
    @Default(0.0) double maxSpeedKmh,
    double? minSpeedKmh,
    @Default(0.0) double avgSpeedKmh,
    @Default(0.0) double totalDistanceKm,
    @Default(0) int elapsedSeconds,
    DateTime? completedAt,
  }) = _StageResult;

  Map<String, dynamic> toJson() => {
        'maxSpeedKmh': maxSpeedKmh,
        'minSpeedKmh': minSpeedKmh,
        'avgSpeedKmh': avgSpeedKmh,
        'totalDistanceKm': totalDistanceKm,
        'elapsedSeconds': elapsedSeconds,
        'completedAt': completedAt?.toIso8601String(),
      };
}

/// Reconstruct a [StageResult] from its JSON object, or `null` when the
/// payload is absent/empty (one-way migration: older persisted stages predate
/// the result field and load with `result: null`). An older app version that
/// doesn't know `result` simply ignores the key, so saving a result and then
/// downgrading drops it harmlessly — but don't downgrade after saving, per the
/// same convention as `startTime`/coords.
StageResult? stageResultFromJson(Map<String, dynamic>? json) {
  if (json == null) return null;
  return StageResult(
    maxSpeedKmh: (json['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0,
    minSpeedKmh: (json['minSpeedKmh'] as num?)?.toDouble(),
    avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0,
    totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
    elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
    completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
  );
}

/// A finished stage run, logged on the owning [Competition]'s `history` list.
///
/// Whereas [StageResult] (stored on [PlannedStage.result]) only keeps the latest
/// run's speed/distance/time stats, [StageRunHistory] is an append-only log of
/// every completed run for a stage — so the crew can review how a stage evolved
/// across repetitions. The owning competition's name and the stage's planned
/// start coords are snapshotted at completion time, so a later edit to the
/// competition/stage doesn't rewrite history.
@freezed
class StageRunHistory with _$StageRunHistory {
  const StageRunHistory._();

  const factory StageRunHistory({
    required String id,
    required String stageId,
    required String stageName,
    @Default('') String competitionName,
    DateTime? startedAt,
    DateTime? completedAt,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    @Default(0.0) double targetAvgSpeed,
    @Default(0.0) double maxSpeedLimit,
    @Default(0.0) double maxSpeedKmh,
    double? minSpeedKmh,
    @Default(0.0) double avgSpeedKmh,
    @Default(0.0) double totalDistanceKm,
    @Default(0) int elapsedSeconds,
  }) = _StageRunHistory;

  Map<String, dynamic> toJson() => {
        'id': id,
        'stageId': stageId,
        'stageName': stageName,
        'competitionName': competitionName,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'startLatitude': startLatitude,
        'startLongitude': startLongitude,
        'endLatitude': endLatitude,
        'endLongitude': endLongitude,
        'targetAvgSpeed': targetAvgSpeed,
        'maxSpeedLimit': maxSpeedLimit,
        'maxSpeedKmh': maxSpeedKmh,
        'minSpeedKmh': minSpeedKmh,
        'avgSpeedKmh': avgSpeedKmh,
        'totalDistanceKm': totalDistanceKm,
        'elapsedSeconds': elapsedSeconds,
      };
}

/// Reconstruct a [StageRunHistory] from its JSON object, with backward-
/// compatible defaults for fields added later (so older or partial payloads
/// load without error). One-way migration: older app versions that don't know
/// `history` simply ignore the key.
StageRunHistory stageRunHistoryFromJson(Map<String, dynamic> json) =>
    StageRunHistory(
      id: json['id'] as String,
      stageId: json['stageId'] as String,
      stageName: json['stageName'] as String,
      competitionName: json['competitionName'] as String? ?? '',
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      startLatitude: (json['startLatitude'] as num?)?.toDouble(),
      startLongitude: (json['startLongitude'] as num?)?.toDouble(),
      endLatitude: (json['endLatitude'] as num?)?.toDouble(),
      endLongitude: (json['endLongitude'] as num?)?.toDouble(),
      targetAvgSpeed: (json['targetAvgSpeed'] as num?)?.toDouble() ?? 0.0,
      maxSpeedLimit: (json['maxSpeedLimit'] as num?)?.toDouble() ?? 0.0,
      maxSpeedKmh: (json['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      minSpeedKmh: (json['minSpeedKmh'] as num?)?.toDouble(),
      avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
      elapsedSeconds: json['elapsedSeconds'] as int? ??
          (json['elapsedSeconds'] as num?)?.toInt() ??
          0,
    );

/// Aggregate state owned by [StageController]: the stage configuration plus its
/// live telemetry. Splitting config/telemetry lets widgets `select` narrowly.
@freezed
class RallyState with _$RallyState {
  const factory RallyState({
    @Default(StageConfig(id: 'stage-1')) StageConfig config,
    @Default(StageTelemetry()) StageTelemetry telemetry,
  }) = _RallyState;
}

/// A planned stage in the day's schedule. Persisted across restarts so the
/// crew can plan the morning and drive later.
///
/// Auto-start triggers (after a confirmation prompt) when **either** condition
/// is met — time or location — and either can be missing:
/// - [startTime] is the scheduled start (wall clock). `null` = no time trigger.
/// - ([latitude], [longitude]) + [geofenceRadiusM] is the start geofence. Coords
///   `null` = no location trigger.
/// So a stage may be time-only, location-only, both, or (if `autoStart` is on
/// but neither is set) unable to auto-start at all. `started` is set once
/// auto-start (or manual start of this stage) has fired, to avoid re-triggering.
@freezed
class PlannedStage with _$PlannedStage {
  const PlannedStage._();

  const factory PlannedStage({
    required String id,
    required String name,
    /// Scheduled start (wall clock). `null` = no time trigger (location-only).
    DateTime? startTime,
    @Default(40.0) double targetAvgSpeed,
    @Default(60.0) double maxSpeedLimit,
    /// Start geofence centre. `null` = no location trigger (time-only).
    double? latitude,
    double? longitude,
    @Default(200.0) double geofenceRadiusM,
    @Default(true) bool autoStart,
    @Default(false) bool started,
    /// Finish location. Null when the crew didn't set one (no auto-stop).
    double? endLatitude,
    double? endLongitude,
    @Default(200.0) double endGeofenceRadiusM,
    @Default(true) bool autoStop,
    /// Crew-entered total stage length (km). 0 = not set.
    @Default(0.0) double totalDistanceKm,
    /// Crew-entered total allocated time (seconds). 0 = not set.
    @Default(0) int allocatedTimeSeconds,
    /// Captured result once the stage has finished (max/min/avg real speed,
    /// distance, elapsed, completion time). `null` while the stage hasn't
    /// been stopped yet. One-way migration: older payloads omit this and load
    /// as `null`.
    StageResult? result,
  }) = _PlannedStage;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime?.toIso8601String(),
        'targetAvgSpeed': targetAvgSpeed,
        'maxSpeedLimit': maxSpeedLimit,
        'latitude': latitude,
        'longitude': longitude,
        'geofenceRadiusM': geofenceRadiusM,
        'autoStart': autoStart,
        'started': started,
        'endLatitude': endLatitude,
        'endLongitude': endLongitude,
        'endGeofenceRadiusM': endGeofenceRadiusM,
        'autoStop': autoStop,
        'totalDistanceKm': totalDistanceKm,
        'allocatedTimeSeconds': allocatedTimeSeconds,
        'result': result?.toJson(),
      };
}

/// Reconstruct a single [PlannedStage] from its JSON object, with backward-
/// compatible defaults for fields added later (so older persisted schedules
/// load without error).
///
/// `startTime`/`latitude`/`longitude` are nullable: older payloads (and the
/// new time-only/location-only stages) may omit them. This is a one-way
/// migration — an older app version that still does `DateTime.parse(... as
/// String)` will throw on a null/missing `startTime`, so don't downgrade after
/// saving a time-only or location-only stage.
PlannedStage plannedStageFromJson(Map<String, dynamic> json) => PlannedStage(
      id: json['id'] as String,
      name: json['name'] as String,
      startTime: DateTime.tryParse(json['startTime'] as String? ?? ''),
      targetAvgSpeed: (json['targetAvgSpeed'] as num).toDouble(),
      maxSpeedLimit: (json['maxSpeedLimit'] as num).toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geofenceRadiusM: (json['geofenceRadiusM'] as num).toDouble(),
      autoStart: json['autoStart'] as bool? ?? true,
      started: json['started'] as bool? ?? false,
      endLatitude: (json['endLatitude'] as num?)?.toDouble(),
      endLongitude: (json['endLongitude'] as num?)?.toDouble(),
      endGeofenceRadiusM:
          (json['endGeofenceRadiusM'] as num?)?.toDouble() ?? 200.0,
      autoStop: json['autoStop'] as bool? ?? true,
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
      allocatedTimeSeconds: json['allocatedTimeSeconds'] as int? ??
          (json['allocatedTimeSeconds'] as num?)?.toInt() ?? 0,
      result: stageResultFromJson(json['result'] as Map<String, dynamic>?),
    );

/// Convenience: serialize a list of [PlannedStage] to/from JSON for storage.
String plannedStagesToJson(List<PlannedStage> stages) =>
    jsonEncode(stages.map((s) => s.toJson()).toList());

List<PlannedStage> plannedStagesFromJson(String encoded) {
  if (encoded.trim().isEmpty) return const [];
  final list = jsonDecode(encoded) as List<dynamic>;
  return list
      .map((e) => plannedStageFromJson(e as Map<String, dynamic>))
      .toList();
}

/// A competition: a named event (e.g. "Raliul Clujului") grouping one or more
/// [PlannedStage]s, plus the crew/event metadata the crew wants to keep handy
/// (pilot, copilot, car, category, standings, contact, cost).
///
/// Standings ([overallStanding], [categoryStanding]) are crew-entered as the
/// event progresses; `0` means "not set". [cost] is in the crew's local
/// currency. [stages] is the ordered list of planned stages for this event.
///
/// Serialization is hand-rolled (like [PlannedStage]) so the wire format stays
/// explicit and backward compatible — `stages` is embedded as a JSON array of
/// stage objects via [plannedStageFromJson].
@freezed
class Competition with _$Competition {
  const Competition._();

  const factory Competition({
    required String id,
    @Default('') String name,
    @Default('') String location,
    /// First day of the event (optional). `null` = not set.
    DateTime? startDate,
    /// Last day of the event (optional). `null` or equal to [startDate] means a
    /// single-day event. When set, must be on/after [startDate].
    DateTime? endDate,
    @Default('') String pilot,
    @Default('') String copilot,
    @Default('') String car,
    @Default('') String category,
    @Default(0) int totalTeams,
    @Default('') String contactPerson,
    String? contactPhone,
    @Default(0.0) double cost,
    @Default(0) int overallStanding,
    @Default(0) int categoryStanding,
    @Default(<PlannedStage>[]) List<PlannedStage> stages,
    /// Append-only log of finished stage runs for this competition, newest at
    /// the end (the UI sorts descending by [StageRunHistory.completedAt]).
    /// One-way migration: older payloads omit `history` and load as `[]`.
    @Default(<StageRunHistory>[]) List<StageRunHistory> history,
  }) = _Competition;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'pilot': pilot,
        'copilot': copilot,
        'car': car,
        'category': category,
        'totalTeams': totalTeams,
        'contactPerson': contactPerson,
        'contactPhone': contactPhone,
        'cost': cost,
        'overallStanding': overallStanding,
        'categoryStanding': categoryStanding,
        'stages': stages.map((s) => s.toJson()).toList(),
        'history': history.map((h) => h.toJson()).toList(),
      };
}

/// Serialize a list of [Competition]s to JSON for storage.
String competitionsToJson(List<Competition> competitions) =>
    jsonEncode(competitions.map((c) => c.toJson()).toList());

/// Reconstruct a list of [Competition]s from JSON, with backward-compatible
/// defaults for every field (so older or partial payloads load cleanly).
List<Competition> competitionsFromJson(String encoded) {
  if (encoded.trim().isEmpty) return const [];
  final list = jsonDecode(encoded) as List<dynamic>;
  return list.map((e) {
    final json = e as Map<String, dynamic>;
    // Backward compat: pre-multi-day versions stored a single `date`. Migrate
    // it into `startDate` when the new `startDate` key is absent.
    final startDateRaw = json['startDate'] as String?;
    final legacyDateRaw = json['date'] as String?;
    final startParsed = startDateRaw == null
        ? (legacyDateRaw == null ? null : DateTime.tryParse(legacyDateRaw))
        : DateTime.tryParse(startDateRaw);
    final endDateRaw = json['endDate'] as String?;
    final endParsed =
        endDateRaw == null ? null : DateTime.tryParse(endDateRaw);
    final stagesRaw = json['stages'];
    final List<PlannedStage> stages;
    if (stagesRaw is String) {
      // Legacy nested-as-string shape (defensive).
      stages = plannedStagesFromJson(stagesRaw);
    } else if (stagesRaw is List) {
      stages = stagesRaw
          .map((s) => plannedStageFromJson(s as Map<String, dynamic>))
          .toList();
    } else {
      stages = const [];
    }
    // One-way migration: older payloads have no `history` key → load as [].
    final historyRaw = json['history'];
    final List<StageRunHistory> history;
    if (historyRaw is List) {
      history = historyRaw
          .map((h) => stageRunHistoryFromJson(h as Map<String, dynamic>))
          .toList();
    } else {
      history = const [];
    }
    return Competition(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      startDate: startParsed,
      endDate: endParsed,
      pilot: json['pilot'] as String? ?? '',
      copilot: json['copilot'] as String? ?? '',
      car: json['car'] as String? ?? '',
      category: json['category'] as String? ?? '',
      totalTeams: (json['totalTeams'] as num?)?.toInt() ?? 0,
      contactPerson: json['contactPerson'] as String? ?? '',
      contactPhone: json['contactPhone'] as String?,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      overallStanding: (json['overallStanding'] as num?)?.toInt() ?? 0,
      categoryStanding: (json['categoryStanding'] as num?)?.toInt() ?? 0,
      stages: stages,
      history: history,
    );
  }).toList();
}