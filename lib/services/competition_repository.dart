import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models.dart';
import 'competition_keys.dart';

/// SQLite schema version. Bump + add an `onUpgrade` step for future migrations.
const _kDbVersion = 1;

/// Persistence layer for competitions, their planned stages, and the
/// per-competition history log. Backed by SQLite (replaces the previous
/// single-`SharedPreferences` JSON blob).
///
/// Two write shapes keep things simple and order-preserving without per-row
/// sort tracking:
/// - [saveCompetitions]: a coarse, transactional rewrite of the `competitions`
///   and `stages` tables from a full [List<Competition>]. Removed competitions
///   and stages (and their orphaned history rows) are deleted; kept rows are
///   upserted. The crew's data set is small and mutated rarely, so a full
///   rewrite per mutation is negligible and avoids ordering bugs.
/// - [appendHistory]: a single insert into the append-only `stage_history`
///   table (history is never rewritten, only grown).
///
/// On the very first load (empty DB) a one-way migration imports the legacy
/// `retrometer.competitions` JSON blob — or, for pre-competition installs, the
/// legacy flat `retrometer.schedule` — so no planned data is lost when the app
/// upgrades. The legacy keys are left in place (downgrade-safe, same convention
/// as nullable `startTime`/coords), just not re-read once the DB has data.
abstract class CompetitionRepository {
  Future<List<Competition>> loadAll();

  Future<void> saveCompetitions(List<Competition> competitions);

  Future<void> appendHistory(String competitionId, StageRunHistory entry);
}

class SqliteCompetitionRepository implements CompetitionRepository {
  SqliteCompetitionRepository({
    required DatabaseFactory databaseFactory,
    required Future<String> Function() pathProvider,
  })  : _factory = databaseFactory,
        _pathProvider = pathProvider;

  final DatabaseFactory _factory;
  final Future<String> Function() _pathProvider;

  Database? _db;
  bool _migrated = false;

  /// All writes are chained onto this future so they run strictly one-at-a-time
  /// over the single SQLite connection (a `rawUpdate` dispatched while a
  /// `transaction` is mid-flight interleaves statements on the ffi isolate's
  /// message queue and corrupts the rollback journal — SQLITE_READONLY_ROLLBACK,
  /// code 1032). Chaining serializes them defensively regardless of caller, and
  /// gives tests a [flush] handle to await before tearing the temp dir down.
  Future<void> _lastWrite = Future<void>.value();
  bool _closed = false;

  Future<void> _chain(Future<void> Function() op) {
    final next = _lastWrite.then((_) => op());
    // Keep the chain alive even if this op throws (otherwise a failed write
    // would block every subsequent one forever).
    _lastWrite = next.catchError((Object error) {});
    return next;
  }

  /// Await all writes that have been dispatched so far. Used by tests to drain
  /// pending persistence before deleting the backing temp directory (otherwise
  /// an in-flight transaction loses its journal mid-write → readonly_rollback).
  Future<void> flush() => _lastWrite;

  /// Closes the database, if open. Idempotent. Pending writes are awaited first
  /// (via [flush]) so the close doesn't rip a transaction out from under itself.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await flush();
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final path = await _pathProvider();
    _db = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _kDbVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int _) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE competitions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        location TEXT NOT NULL DEFAULT '',
        start_date TEXT,
        end_date TEXT,
        pilot TEXT NOT NULL DEFAULT '',
        copilot TEXT NOT NULL DEFAULT '',
        car TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT '',
        total_teams INTEGER NOT NULL DEFAULT 0,
        contact_person TEXT NOT NULL DEFAULT '',
        contact_phone TEXT,
        cost REAL NOT NULL DEFAULT 0,
        overall_standing INTEGER NOT NULL DEFAULT 0,
        category_standing INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute('''
      CREATE TABLE stages (
        id TEXT PRIMARY KEY,
        competition_id TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        name TEXT NOT NULL,
        start_time TEXT,
        target_avg_speed REAL NOT NULL DEFAULT 40,
        max_speed_limit REAL NOT NULL DEFAULT 60,
        latitude REAL,
        longitude REAL,
        geofence_radius_m REAL NOT NULL DEFAULT 200,
        auto_start INTEGER NOT NULL DEFAULT 1,
        started INTEGER NOT NULL DEFAULT 0,
        end_latitude REAL,
        end_longitude REAL,
        end_geofence_radius_m REAL NOT NULL DEFAULT 200,
        auto_stop INTEGER NOT NULL DEFAULT 1,
        total_distance_km REAL NOT NULL DEFAULT 0,
        allocated_time_seconds INTEGER NOT NULL DEFAULT 0,
        result TEXT,
        FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('''
      CREATE TABLE stage_history (
        id TEXT PRIMARY KEY,
        stage_id TEXT NOT NULL,
        competition_id TEXT NOT NULL,
        stage_name TEXT NOT NULL,
        competition_name TEXT NOT NULL DEFAULT '',
        started_at TEXT,
        completed_at TEXT,
        start_latitude REAL,
        start_longitude REAL,
        end_latitude REAL,
        end_longitude REAL,
        target_avg_speed REAL NOT NULL DEFAULT 0,
        max_speed_limit REAL NOT NULL DEFAULT 0,
        max_speed_kmh REAL NOT NULL DEFAULT 0,
        min_speed_kmh REAL,
        avg_speed_kmh REAL NOT NULL DEFAULT 0,
        total_distance_km REAL NOT NULL DEFAULT 0,
        elapsed_seconds INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (stage_id) REFERENCES stages(id) ON DELETE CASCADE,
        FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE
      )
    ''');
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here. None yet (still v1).
  }

  @override
  Future<List<Competition>> loadAll() async {
    final db = await _database();
    final compsRows = await db.query(
      'competitions',
      orderBy: 'sort_order ASC',
    );
    if (compsRows.isEmpty) {
      // First load on an empty DB: import the legacy persisted payload once.
      if (!_migrated) {
        _migrated = true;
        final migrated = await _migrateLegacy(db);
        if (migrated != null) return migrated;
      }
      return const [];
    }
    final stagesRows = await db.query('stages', orderBy: 'sort_order ASC');
    final historyRows = await db.query('stage_history');
    return _assemble(compsRows, stagesRows, historyRows);
  }

  /// One-way migration from the legacy `SharedPreferences` payloads. Returns the
  /// imported competitions (already inserted) or `null` when there was nothing
  /// to import. The legacy keys are left in place (downgrade-safe).
  Future<List<Competition>?> _migrateLegacy(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    final blob = prefs.getString(kCompetitionsKey);
    if (blob != null && blob.trim().isNotEmpty) {
      final comps = competitionsFromJson(blob);
      if (comps.isNotEmpty) {
        await _writeAll(db, comps);
        return comps;
      }
    }
    final legacy = prefs.getString(kLegacyScheduleKey);
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
        await _writeAll(db, migrated);
        return migrated;
      }
    }
    return null;
  }

  @override
  Future<void> saveCompetitions(List<Competition> competitions) =>
      _chain(() async {
        final db = await _database();
        await db.transaction((txn) async {
      final existingComps = (await txn.query('competitions', columns: ['id']))
          .map((r) => r['id'] as String)
          .toSet();
      final nextCompIds = competitions.map((c) => c.id).toSet();
      final removedComps = existingComps.difference(nextCompIds).toList();

      // Existing stages grouped by competition (for removed-stage detection).
      final existingStageIds = <String>{};
      final stagesByComp = <String, List<String>>{};
      for (final row in await txn.query('stages', columns: ['id', 'competition_id'])) {
        final id = row['id'] as String;
        final compId = row['competition_id'] as String;
        existingStageIds.add(id);
        (stagesByComp[compId] ??= <String>[]).add(id);
      }
      final nextStageIds = <String>{};
      for (final c in competitions) {
        for (final s in c.stages) {
          nextStageIds.add(s.id);
        }
      }

      // Remove competitions (and, via cascade, their stages + history).
      for (final id in removedComps) {
        // Cascade only fires if FK is enforced; clean explicitly to be safe.
        await txn.delete('stage_history', where: 'competition_id = ?', whereArgs: [id]);
        await txn.delete('stages', where: 'competition_id = ?', whereArgs: [id]);
        await txn.delete('competitions', where: 'id = ?', whereArgs: [id]);
      }

      // Remove stages deleted from still-existing competitions (clean their
      // history explicitly; cascade handles the rest on platforms that enforce FK).
      final removedStages = existingStageIds.difference(nextStageIds).toList();
      for (final id in removedStages) {
        await txn.delete('stage_history', where: 'stage_id = ?', whereArgs: [id]);
        await txn.delete('stages', where: 'id = ?', whereArgs: [id]);
      }

      // Upsert competitions + stages (preserve order via sort_order). Use a true
      // upsert (ON CONFLICT DO UPDATE) rather than `INSERT OR REPLACE`: the
      // latter is DELETE+INSERT, which fires the FK ON DELETE CASCADE and would
      // wipe the kept competition's stages + history on every save. An in-place
      // update leaves child rows untouched.
      for (var i = 0; i < competitions.length; i++) {
        final c = competitions[i];
        await txn.rawUpdate(
          _upsertSql('competitions', _competitionCols),
          _values(_competitionRow(c, i), _competitionCols),
        );
        for (var j = 0; j < c.stages.length; j++) {
          await txn.rawUpdate(
            _upsertSql('stages', _stageCols),
            _values(_stageRow(c.id, c.stages[j], j), _stageCols),
          );
        }
      }
    });
      });

  @override
  Future<void> appendHistory(String competitionId, StageRunHistory entry) =>
      _chain(() async {
        final db = await _database();
        await db.rawUpdate(
          _upsertSql('stage_history', _historyCols),
          _values(_historyRow(competitionId, entry), _historyCols),
        );
      });

  /// Bulk write used by the legacy migration (no diffing — DB is empty). Uses
  /// the same in-place upserts so the migration path matches normal writes.
  Future<void> _writeAll(Database db, List<Competition> comps) async {
    await db.transaction((txn) async {
      for (var i = 0; i < comps.length; i++) {
        final c = comps[i];
        await txn.rawUpdate(
          _upsertSql('competitions', _competitionCols),
          _values(_competitionRow(c, i), _competitionCols),
        );
        for (var j = 0; j < c.stages.length; j++) {
          await txn.rawUpdate(
            _upsertSql('stages', _stageCols),
            _values(_stageRow(c.id, c.stages[j], j), _stageCols),
          );
        }
        for (final h in c.history) {
          await txn.rawUpdate(
            _upsertSql('stage_history', _historyCols),
            _values(_historyRow(c.id, h), _historyCols),
          );
        }
      }
    });
  }

  List<Competition> _assemble(
    List<Map<String, Object?>> compsRows,
    List<Map<String, Object?>> stagesRows,
    List<Map<String, Object?>> historyRows,
  ) {
    final stagesByComp = <String, List<PlannedStage>>{};
    for (final row in stagesRows) {
      final compId = row['competition_id'] as String;
      (stagesByComp[compId] ??= <PlannedStage>[]).add(_stageFromRow(row));
    }
    final historyByComp = <String, List<StageRunHistory>>{};
    for (final row in historyRows) {
      final compId = row['competition_id'] as String;
      (historyByComp[compId] ??= <StageRunHistory>[]).add(_historyFromRow(row));
    }
    return [
      for (final row in compsRows)
        _competitionFromRow(row)
            .copyWith(
              stages: stagesByComp[row['id'] as String] ?? const <PlannedStage>[],
              history: historyByComp[row['id'] as String] ?? const <StageRunHistory>[],
            ),
    ];
  }
}

// --- row mappers ------------------------------------------------------------

/// Column lists in the exact order the row mappers emit them. Used to build
/// the upsert SQL + bind values positionally.
const _competitionCols = <String>[
  'id', 'name', 'location', 'start_date', 'end_date', 'pilot', 'copilot', 'car',
  'category', 'total_teams', 'contact_person', 'contact_phone', 'cost',
  'overall_standing', 'category_standing', 'sort_order',
];

const _stageCols = <String>[
  'id', 'competition_id', 'sort_order', 'name', 'start_time', 'target_avg_speed',
  'max_speed_limit', 'latitude', 'longitude', 'geofence_radius_m', 'auto_start',
  'started', 'end_latitude', 'end_longitude', 'end_geofence_radius_m',
  'auto_stop', 'total_distance_km', 'allocated_time_seconds', 'result',
];

const _historyCols = <String>[
  'id', 'stage_id', 'competition_id', 'stage_name', 'competition_name',
  'started_at', 'completed_at', 'start_latitude', 'start_longitude',
  'end_latitude', 'end_longitude', 'target_avg_speed', 'max_speed_limit',
  'max_speed_kmh', 'min_speed_kmh', 'avg_speed_kmh', 'total_distance_km',
  'elapsed_seconds',
];

/// Builds an `INSERT … ON CONFLICT(pk) DO UPDATE SET …` (a true in-place upsert
/// that never deletes, so FK cascades don't fire on re-saves of kept rows).
String _upsertSql(String table, List<String> cols, {String pk = 'id'}) {
  final placeholders = List.filled(cols.length, '?').join(', ');
  final setClause = cols
      .where((c) => c != pk)
      .map((c) => '$c = excluded.$c')
      .join(', ');
  return 'INSERT INTO $table (${cols.join(', ')}) VALUES ($placeholders) '
      'ON CONFLICT($pk) DO UPDATE SET $setClause';
}

/// Binds [row]'s values in [cols] order for the positional `?` placeholders.
List<Object?> _values(Map<String, Object?> row, List<String> cols) =>
    [for (final c in cols) row[c]];

Map<String, Object?> _competitionRow(Competition c, int sortOrder) => {
      'id': c.id,
      'name': c.name,
      'location': c.location,
      'start_date': c.startDate?.toIso8601String(),
      'end_date': c.endDate?.toIso8601String(),
      'pilot': c.pilot,
      'copilot': c.copilot,
      'car': c.car,
      'category': c.category,
      'total_teams': c.totalTeams,
      'contact_person': c.contactPerson,
      'contact_phone': c.contactPhone,
      'cost': c.cost,
      'overall_standing': c.overallStanding,
      'category_standing': c.categoryStanding,
      'sort_order': sortOrder,
    };

Map<String, Object?> _stageRow(String competitionId, PlannedStage s, int sortOrder) => {
      'id': s.id,
      'competition_id': competitionId,
      'sort_order': sortOrder,
      'name': s.name,
      'start_time': s.startTime?.toIso8601String(),
      'target_avg_speed': s.targetAvgSpeed,
      'max_speed_limit': s.maxSpeedLimit,
      'latitude': s.latitude,
      'longitude': s.longitude,
      'geofence_radius_m': s.geofenceRadiusM,
      'auto_start': s.autoStart ? 1 : 0,
      'started': s.started ? 1 : 0,
      'end_latitude': s.endLatitude,
      'end_longitude': s.endLongitude,
      'end_geofence_radius_m': s.endGeofenceRadiusM,
      'auto_stop': s.autoStop ? 1 : 0,
      'total_distance_km': s.totalDistanceKm,
      'allocated_time_seconds': s.allocatedTimeSeconds,
      'result': s.result == null ? null : jsonEncode(s.result!.toJson()),
    };

Map<String, Object?> _historyRow(String competitionId, StageRunHistory h) => {
      'id': h.id,
      'stage_id': h.stageId,
      'competition_id': competitionId,
      'stage_name': h.stageName,
      'competition_name': h.competitionName,
      'started_at': h.startedAt?.toIso8601String(),
      'completed_at': h.completedAt?.toIso8601String(),
      'start_latitude': h.startLatitude,
      'start_longitude': h.startLongitude,
      'end_latitude': h.endLatitude,
      'end_longitude': h.endLongitude,
      'target_avg_speed': h.targetAvgSpeed,
      'max_speed_limit': h.maxSpeedLimit,
      'max_speed_kmh': h.maxSpeedKmh,
      'min_speed_kmh': h.minSpeedKmh,
      'avg_speed_kmh': h.avgSpeedKmh,
      'total_distance_km': h.totalDistanceKm,
      'elapsed_seconds': h.elapsedSeconds,
    };

Competition _competitionFromRow(Map<String, Object?> r) => Competition(
      id: r['id'] as String,
      name: (r['name'] as String?) ?? '',
      location: (r['location'] as String?) ?? '',
      startDate: DateTime.tryParse((r['start_date'] as String?) ?? ''),
      endDate: DateTime.tryParse((r['end_date'] as String?) ?? ''),
      pilot: (r['pilot'] as String?) ?? '',
      copilot: (r['copilot'] as String?) ?? '',
      car: (r['car'] as String?) ?? '',
      category: (r['category'] as String?) ?? '',
      totalTeams: (r['total_teams'] as int?) ?? 0,
      contactPerson: (r['contact_person'] as String?) ?? '',
      contactPhone: r['contact_phone'] as String?,
      cost: (r['cost'] as num?)?.toDouble() ?? 0.0,
      overallStanding: (r['overall_standing'] as int?) ?? 0,
      categoryStanding: (r['category_standing'] as int?) ?? 0,
    );

PlannedStage _stageFromRow(Map<String, Object?> r) {
  final resultJson = r['result'] as String?;
  return PlannedStage(
    id: r['id'] as String,
    name: r['name'] as String,
    startTime: DateTime.tryParse((r['start_time'] as String?) ?? ''),
    targetAvgSpeed: (r['target_avg_speed'] as num?)?.toDouble() ?? 40.0,
    maxSpeedLimit: (r['max_speed_limit'] as num?)?.toDouble() ?? 60.0,
    latitude: (r['latitude'] as num?)?.toDouble(),
    longitude: (r['longitude'] as num?)?.toDouble(),
    geofenceRadiusM: (r['geofence_radius_m'] as num?)?.toDouble() ?? 200.0,
    autoStart: (r['auto_start'] as int?) == 1,
    started: (r['started'] as int?) == 1,
    endLatitude: (r['end_latitude'] as num?)?.toDouble(),
    endLongitude: (r['end_longitude'] as num?)?.toDouble(),
    endGeofenceRadiusM: (r['end_geofence_radius_m'] as num?)?.toDouble() ?? 200.0,
    autoStop: (r['auto_stop'] as int?) == 1,
    totalDistanceKm: (r['total_distance_km'] as num?)?.toDouble() ?? 0.0,
    allocatedTimeSeconds: (r['allocated_time_seconds'] as int?) ?? 0,
    result: resultJson == null
        ? null
        : stageResultFromJson(jsonDecode(resultJson) as Map<String, dynamic>),
  );
}

StageRunHistory _historyFromRow(Map<String, Object?> r) => StageRunHistory(
      id: r['id'] as String,
      stageId: r['stage_id'] as String,
      stageName: r['stage_name'] as String,
      competitionName: (r['competition_name'] as String?) ?? '',
      startedAt: DateTime.tryParse((r['started_at'] as String?) ?? ''),
      completedAt: DateTime.tryParse((r['completed_at'] as String?) ?? ''),
      startLatitude: (r['start_latitude'] as num?)?.toDouble(),
      startLongitude: (r['start_longitude'] as num?)?.toDouble(),
      endLatitude: (r['end_latitude'] as num?)?.toDouble(),
      endLongitude: (r['end_longitude'] as num?)?.toDouble(),
      targetAvgSpeed: (r['target_avg_speed'] as num?)?.toDouble() ?? 0.0,
      maxSpeedLimit: (r['max_speed_limit'] as num?)?.toDouble() ?? 0.0,
      maxSpeedKmh: (r['max_speed_kmh'] as num?)?.toDouble() ?? 0.0,
      minSpeedKmh: (r['min_speed_kmh'] as num?)?.toDouble(),
      avgSpeedKmh: (r['avg_speed_kmh'] as num?)?.toDouble() ?? 0.0,
      totalDistanceKm: (r['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      elapsedSeconds: (r['elapsed_seconds'] as int?) ?? 0,
    );

/// Production repository provider. Override `databaseFactory` + path in tests
/// with an ffi-backed factory + a temp path (host `flutter test` has no
/// platform channels for sqflite). On a real device (integration tests / app),
/// the default factory + `getDatabasesPath()` work natively.
final competitionRepositoryProvider = Provider<CompetitionRepository>((ref) {
  return SqliteCompetitionRepository(
    databaseFactory: databaseFactory,
    pathProvider: () async => path.join(await getDatabasesPath(), 'retrometer.db'),
  );
});