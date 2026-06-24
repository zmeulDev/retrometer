import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:retrometer/competition/stage_editor.dart';
import 'package:retrometer/competition_providers.dart';
import 'package:retrometer/models.dart';
import 'package:retrometer/services/competition_repository.dart';

/// In-memory repository: no SQLite, no platform channels. Just round-trips
/// the competition list so the editor's `updateStage` persistence is exercised.
class _MemRepo implements CompetitionRepository {
  _MemRepo(this._comps);

  List<Competition> _comps;

  @override
  Future<List<Competition>> loadAll() async => List.of(_comps);

  @override
  Future<void> saveCompetitions(List<Competition> competitions) async {
    _comps = List.of(competitions);
  }

  @override
  Future<void> appendHistory(String competitionId, StageRunHistory entry) async {
    // Not exercised by this test.
  }
}

void main() {
  testWidgets('editing a stage preserves its saved result', (tester) async {
    final result = StageResult(
      maxSpeedKmh: 88,
      minSpeedKmh: 0,
      avgSpeedKmh: 60,
      totalDistanceKm: 5.2,
      elapsedSeconds: 312,
      completedAt: DateTime(2026, 6, 24, 19, 58),
    );
    final stage = PlannedStage(
      id: 's1',
      name: 'stg1',
      targetAvgSpeed: 40,
      maxSpeedLimit: 60,
      autoStart: true,
      started: true,
      result: result,
    );
    final competition = Competition(
      id: 'c1',
      name: 'Cup',
      stages: [stage],
    );
    final repo = _MemRepo([competition]);
    final container = ProviderContainer(
      overrides: [competitionRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // Hydrate the provider from the in-memory repo.
    await container.read(competitionsProvider.future);

    BuildContext? navContext;
    WidgetRef? capturedRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (ctx, ref, _) {
              navContext = ctx;
              capturedRef = ref;
              return const Scaffold(body: Center(child: Text('host')));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Open the stage editor for the existing (already-run) stage. Fire
    // unawaited: it awaits the route pop, so we must interact with the editor
    // while it's still on screen.
    unawaited(showStageEditor(navContext!, capturedRef!, 'c1', stage));
    await tester.pumpAndSettle();

    // Save without changing anything.
    await tester.tap(find.widgetWithText(FilledButton, 'Salvează'));
    await tester.pumpAndSettle();

    final saved = container.read(competitionsProvider).requireValue;
    expect(saved.single.stages.single.result, isNotNull);
    expect(saved.single.stages.single.result!.maxSpeedKmh, closeTo(88, 1e-9));
    expect(saved.single.stages.single.result!.avgSpeedKmh, closeTo(60, 1e-9));
  });
}