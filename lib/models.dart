import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';

/// Lifecycle of the active stage.
enum StageStatus { idle, inProgress, completed }

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
@freezed
class StageTelemetry with _$StageTelemetry {
  const factory StageTelemetry({
    DateTime? startTime,
    @Default(0.0) double currentDistance,
    @Default(0.0) double currentSpeed,
    @Default(StageStatus.idle) StageStatus status,
    double? latitude,
    double? longitude,
  }) = _StageTelemetry;
}

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
/// `startTime` is the scheduled start (wall clock). Auto-start fires when the
/// current time is at/after [startTime] (within a grace window) **and** the
/// device is within [geofenceRadiusM] metres of ([latitude], [longitude]).
/// `started` is set once auto-start (or manual start of this stage) has fired,
/// to avoid re-triggering.
@freezed
class PlannedStage with _$PlannedStage {
  const PlannedStage._();

  const factory PlannedStage({
    required String id,
    required String name,
    required DateTime startTime,
    @Default(40.0) double targetAvgSpeed,
    @Default(60.0) double maxSpeedLimit,
    required double latitude,
    required double longitude,
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
  }) = _PlannedStage;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime.toIso8601String(),
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
      };
}

/// Reconstruct a single [PlannedStage] from its JSON object, with backward-
/// compatible defaults for fields added later (so older persisted schedules
/// load without error).
PlannedStage plannedStageFromJson(Map<String, dynamic> json) => PlannedStage(
      id: json['id'] as String,
      name: json['name'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      targetAvgSpeed: (json['targetAvgSpeed'] as num).toDouble(),
      maxSpeedLimit: (json['maxSpeedLimit'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
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
    DateTime? date,
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
  }) = _Competition;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'date': date?.toIso8601String(),
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
    final dateRaw = json['date'] as String?;
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
    return Competition(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      date: dateRaw == null ? null : DateTime.tryParse(dateRaw),
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
    );
  }).toList();
}