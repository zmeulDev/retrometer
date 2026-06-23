import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:retrometer/models.dart';
import 'package:retrometer/services/competition_keys.dart';
import 'package:retrometer/services/competition_repository.dart';

Competition _competition({
  String id = 'comp-1',
  String name = 'Raliul Test',
  List<PlannedStage> stages = const [],
  List<StageRunHistory> history = const [],
}) =>
    Competition(
      id: id,
      name: name,
      location: 'Cluj',
      pilot: 'Andrei',
      copilot: 'Mihai',
      car: 'BMW Z3',
      category: 'A',
      totalTeams: 12,
      contactPerson: 'Ion',
      contactPhone: '0700',
      cost: 150.0,
      overallStanding: 3,
      categoryStanding: 2,
      startDate: DateTime(2026, 6, 21),
      endDate: DateTime(2026, 6, 23),
      stages: stages,
      history: history,
    );

PlannedStage _stage({
  String id = 's1',
  String name = 'SS1',
  StageResult? result,
  double? latitude,
  double? longitude,
}) =>
    PlannedStage(
      id: id,
      name: name,
      startTime: DateTime(2026, 6, 21, 9, 0),
      latitude: latitude,
      longitude: longitude,
      endLatitude: 46.1,
      endLongitude: 25.1,
      targetAvgSpeed: 35.0,
      maxSpeedLimit: 55.0,
      result: result,
    );

StageRunHistory _history({String id = 'run-1'}) => StageRunHistory(
      id: id,
      stageId: 's1',
      stageName: 'SS1',
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

/// Builds a repository backed by an in-process ffi SQLite at a unique temp
/// path (so tests don't share state). The temp dir is cleaned up afterwards.
SqliteCompetitionRepository _repo() {
  final dir = Directory.systemTemp.createTempSync('retrometer_repo_test_');
  addTearDown(() => dir.delete(recursive: true));
  return SqliteCompetitionRepository(
    databaseFactory: databaseFactoryFfi,
    pathProvider: () async => path.join(dir.path, 'test.db'),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('round-trip', () {
    test('saveCompetitions then loadAll preserves competitions + stage order',
        () async {
      final repo = _repo();
      await repo.saveCompetitions([
        _competition(id: 'c1', name: 'Cup A', stages: [
          _stage(id: 's1', name: 'SS1'),
          _stage(id: 's2', name: 'SS2'),
        ]),
        _competition(id: 'c2', name: 'Cup B'),
      ]);

      final loaded = await repo.loadAll();
      expect(loaded.map((c) => c.id), ['c1', 'c2']);
      expect(loaded.first.name, 'Cup A');
      // Stage order preserved via sort_order.
      expect(loaded.first.stages.map((s) => s.id), ['s1', 's2']);
      expect(loaded.first.stages.map((s) => s.name), ['SS1', 'SS2']);
      // All metadata round-trips.
      final c = loaded.first;
      expect(c.location, 'Cluj');
      expect(c.pilot, 'Andrei');
      expect(c.totalTeams, 12);
      expect(c.contactPhone, '0700');
      expect(c.cost, 150.0);
      expect(c.overallStanding, 3);
      expect(c.startDate, DateTime(2026, 6, 21));
      expect(c.endDate, DateTime(2026, 6, 23));
    });

    test('StageResult on a stage round-trips', () async {
      final result = StageResult(
        maxSpeedKmh: 72,
        minSpeedKmh: 36,
        avgSpeedKmh: 60,
        totalDistanceKm: 12.5,
        elapsedSeconds: 750,
        completedAt: DateTime.utc(2026, 6, 22, 10, 0, 0),
      );
      final repo = _repo();
      await repo.saveCompetitions([
        _competition(stages: [_stage(result: result)]),
      ]);
      final loaded = await repo.loadAll();
      final r = loaded.first.stages.single.result;
      expect(r, isNotNull);
      expect(r!.maxSpeedKmh, closeTo(72, 1e-9));
      expect(r.minSpeedKmh, closeTo(36, 1e-9));
      expect(r.avgSpeedKmh, closeTo(60, 1e-9));
      expect(r.totalDistanceKm, closeTo(12.5, 1e-9));
      expect(r.elapsedSeconds, 750);
      expect(
        r.completedAt!.toIso8601String(),
        DateTime.utc(2026, 6, 22, 10, 0, 0).toIso8601String(),
      );
    });

    test('nullable start coords + start time round-trip as null', () async {
      final repo = _repo();
      await repo.saveCompetitions([
        _competition(stages: [
          _stage(latitude: null, longitude: null)
              .copyWith(startTime: null),
        ]),
      ]);
      final s = (await repo.loadAll()).first.stages.single;
      expect(s.latitude, isNull);
      expect(s.longitude, isNull);
      expect(s.startTime, isNull);
      expect(s.result, isNull);
    });
  });

  group('history', () {
    test('appendHistory + loadAll returns entries per competition', () async {
      final repo = _repo();
      await repo.saveCompetitions([_competition(stages: [_stage()])]);
      await repo.appendHistory('comp-1', _history(id: 'run-1'));
      await repo.appendHistory('comp-1', _history(id: 'run-2'));

      final loaded = await repo.loadAll();
      expect(loaded.single.history, hasLength(2));
      final h = loaded.single.history.first;
      expect(h.stageId, 's1');
      expect(h.competitionName, 'Raliul Test');
      expect(h.maxSpeedKmh, closeTo(72, 1e-9));
      expect(h.minSpeedKmh, closeTo(36, 1e-9));
      expect(h.totalDistanceKm, closeTo(12.5, 1e-9));
      expect(h.elapsedSeconds, 750);
    });

    test('history survives a saveCompetitions rewrite of the same competition',
        () async {
      final repo = _repo();
      await repo.saveCompetitions([_competition(stages: [_stage()])]);
      await repo.appendHistory('comp-1', _history(id: 'run-1'));

      // Re-save the competition (e.g. markStarted/markResult) — history must stay.
      await repo.saveCompetitions([
        _competition(stages: [_stage().copyWith(started: true)]),
      ]);
      final loaded = await repo.loadAll();
      expect(loaded.single.history, hasLength(1));
      expect(loaded.single.stages.single.started, true);
    });
  });

  group('cascading deletes', () {
    test('removing a competition drops its stages + history', () async {
      final repo = _repo();
      await repo.saveCompetitions([_competition(stages: [_stage()])]);
      await repo.appendHistory('comp-1', _history(id: 'run-1'));

      // Save an empty list → the competition (and its stages + history) go.
      await repo.saveCompetitions([]);
      expect(await repo.loadAll(), isEmpty);
    });

    test('removing a stage drops its history rows only', () async {
      final repo = _repo();
      await repo.saveCompetitions([
        _competition(stages: [_stage(id: 's1'), _stage(id: 's2')]),
      ]);
      await repo.appendHistory('comp-1', _history(id: 'run-1')); // s1
      // Re-save without s1 → s1 + its history vanish; s2 stays.
      await repo.saveCompetitions([
        _competition(stages: [_stage(id: 's2')]),
      ]);
      final loaded = await repo.loadAll();
      expect(loaded.single.stages.map((s) => s.id), ['s2']);
      expect(loaded.single.history, isEmpty);
    });
  });

  group('legacy migration', () {
    test('imports the retrometer.competitions blob on first load of empty DB',
        () async {
      SharedPreferences.setMockInitialValues({
        kCompetitionsKey: competitionsToJson([
          _competition(stages: [_stage()]),
        ]),
      });
      final repo = _repo();
      final loaded = await repo.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.name, 'Raliul Test');
      expect(loaded.single.stages.single.name, 'SS1');
      // A second load reads from the DB (now populated), not prefs again.
      final again = await repo.loadAll();
      expect(again.single.stages.single.name, 'SS1');
    });

    test('imports the legacy flat schedule into an "Importate" competition',
        () async {
      SharedPreferences.setMockInitialValues({
        kLegacyScheduleKey: plannedStagesToJson([_stage()]),
      });
      final repo = _repo();
      final loaded = await repo.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.name, 'Importate');
      expect(loaded.single.stages.single.name, 'SS1');
    });

    test('empty prefs + empty DB loads as []', () async {
      expect(await _repo().loadAll(), isEmpty);
    });
  });
}