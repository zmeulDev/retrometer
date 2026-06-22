import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../competition_providers.dart';
import '../models.dart';
import '../state_providers.dart';
import '../theme/retrometer_theme.dart';
import '../utils/formatting.dart';
import '../widgets/form_fields.dart';
import '../widgets/info_widgets.dart';
import '../widgets/metadata_tile.dart';
import '../widgets/speed_summary_line.dart';
import 'competition_editor.dart';
import 'stage_editor.dart';

// ---------------------------------------------------------------------------
// Competition detail screen.
// ---------------------------------------------------------------------------

class CompetitionDetailScreen extends ConsumerWidget {
  const CompetitionDetailScreen({super.key, required this.id, required this.onBack});

  final String id;

  /// Returns to the competition list. Provided by the composition root
  /// (`CompetitionView`), which hosts list ↔ detail in a single route.
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(competitionsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: const Text('Competiție'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: RetrometerColors.primary),
            tooltip: 'Editează competiția',
            onPressed: () async {
              final comp = async.valueOrNull
                  ?.firstWhere((c) => c.id == id, orElse: () => const Competition(id: ''));
              if (comp == null || comp.id.isEmpty) return;
              await showCompetitionEditor(context, ref, comp);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: RetrometerColors.danger),
            tooltip: 'Șterge competiția',
            onPressed: () async {
              final confirmed = await confirmDialog(
                context,
                title: 'Ștergi competiția?',
                message: 'Se șterge competiția și toate stagii sale.',
              );
              if (confirmed) {
                await ref.read(competitionsProvider.notifier).removeCompetition(id);
                if (context.mounted) onBack();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => showStageEditor(context, ref, id, null),
      ),
      body: SafeArea(
        child: async.when(
          data: (competitions) {
            final i = competitions.indexWhere((c) => c.id == id);
            if (i < 0) {
              // Deleted — return to the list. Deferred to avoid calling the
              // parent's setState (via onBack) during this build.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) onBack();
              });
              return const SizedBox.shrink();
            }
            final competition = competitions[i];
            final sorted = [...competition.stages]
              ..sort((a, b) {
                final c = (a.startTime ?? DateTime(9999, 12, 31))
                    .compareTo(b.startTime ?? DateTime(9999, 12, 31));
                if (c != 0) return c;
                return a.id.compareTo(b.id); // stable tiebreaker
              });
            // History, most-recent first (nulls last). Built once per rebuild.
            final hist = [...competition.history]
              ..sort((a, b) {
                final ca = a.completedAt ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final cb = b.completedAt ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return cb.compareTo(ca);
              });
            final hasHistory = hist.isNotEmpty;
            final stageCount = sorted.length;
            final historyHeaderCount =
                hasHistory ? 1 + hist.length : 0;
            final totalCount = stageCount + historyHeaderCount;
            return Column(
              children: [
                _CompetitionHeader(competition: competition),
                const _MonitorStatusBar(),
                Expanded(
                  child: sorted.isEmpty && !hasHistory
                      ? const EmptyState(
                          icon: Icons.event_note,
                          message: 'Niciun stagiu în această competiție.\n'
                              'Apasă + ca să adaugi primul stagiu.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                          itemCount: totalCount,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            if (i < stageCount) {
                              return _StageTile(
                                competitionId: competition.id,
                                stage: sorted[i],
                              );
                            }
                            final h = i - stageCount;
                            if (h == 0) {
                              return const _HistoryHeader();
                            }
                            return _HistoryTile(entry: hist[h - 1]);
                          },
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Eroare: $e',
                style: const TextStyle(color: RetrometerColors.textPrimary)),
          ),
        ),
      ),
    );
  }
}

class _CompetitionHeader extends StatelessWidget {
  const _CompetitionHeader({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final rows = <HeaderRow>[
      if (competition.pilot.isNotEmpty || competition.copilot.isNotEmpty)
        HeaderRow(
          icon: Icons.people,
          label: 'Echipaj',
          value: [
            if (competition.pilot.isNotEmpty) 'pilot ${competition.pilot}',
            if (competition.copilot.isNotEmpty) 'copilot ${competition.copilot}',
          ].join(' · '),
        ),
      if (competition.car.isNotEmpty)
        HeaderRow(icon: Icons.directions_car, label: 'Mașină', value: competition.car),
      if (competition.category.isNotEmpty)
        HeaderRow(icon: Icons.label, label: 'Categorie', value: competition.category),
      HeaderRow(
        icon: competition.overallStanding > 0
            ? Icons.emoji_events
            : Icons.emoji_events_outlined,
        label: 'Loc',
        value: [
          if (competition.overallStanding > 0)
            'la general ${competition.overallStanding}',
          if (competition.categoryStanding > 0)
            'în categorie ${competition.categoryStanding}',
          if (competition.totalTeams > 0)
            'din ${competition.totalTeams} echipe',
        ].join(' · '),
        highlight: competition.overallStanding > 0 ||
            competition.categoryStanding > 0,
      ),
      if (competition.location.isNotEmpty)
        HeaderRow(icon: Icons.place, label: 'Locație', value: competition.location),
      if (competition.startDate != null)
        HeaderRow(
            icon: Icons.event,
            label: 'Data',
            value: formatDateRange(
                competition.startDate, competition.endDate)),
      if (competition.contactPerson.isNotEmpty ||
          competition.contactPhone != null)
        HeaderRow(
          icon: Icons.contact_phone,
          label: 'Contact',
          value: [
            competition.contactPerson,
            if (competition.contactPhone != null &&
                competition.contactPhone!.isNotEmpty)
              competition.contactPhone,
          ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
        ),
      if (competition.cost > 0)
        HeaderRow(
          icon: Icons.payments,
          label: 'Cost',
          value: competition.cost.toStringAsFixed(2),
        ),
    ];
    if (rows.isEmpty) {
      rows.add(const HeaderRow(
        icon: Icons.info_outline,
        label: 'Detalii',
        value: 'Apasă ✏️ ca să completezi detaliile competiției.',
      ));
    }
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: RetrometerColors.surfaceHeader,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            competition.name.isEmpty ? '(fără nume)' : competition.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RetrometerTextStyles.headerTitle,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: rows,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auto-start monitor status bar (diagnostics).
// ---------------------------------------------------------------------------

/// One-line auto-start monitor status, so the crew can see it's alive and
/// *why* a stage did/didn't fire (last check, next due, fix accuracy, distance
/// vs geofence).
class _MonitorStatusBar extends ConsumerWidget {
  const _MonitorStatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(autoStartMonitorProvider);
    final tick = s.lastTick;
    final tickStr = tick == null
        ? '—'
        : '${two(tick.hour)}:${two(tick.minute)}:${two(tick.second)}';
    final parts = <String>['auto-start: ${s.message}', 'verificat $tickStr'];
    if (s.nextDueName != null) parts.add('următorul: ${s.nextDueName}');
    if (s.lastFixAccuracyM != null) {
      parts.add('fix ${s.lastFixAccuracyM!.toStringAsFixed(0)} m');
    }
    if (s.lastDistanceM != null && s.lastStageId != null) {
      // Find the stage's radius for context.
      final comps =
          ref.watch(competitionsProvider).valueOrNull ?? const <Competition>[];
      final stage = _findStage(comps, s.lastStageId!);
      if (stage != null) {
        parts.add(
          'distanță ${s.lastDistanceM!.toStringAsFixed(0)} m / rază '
          '${stage.geofenceRadiusM.toStringAsFixed(0)} m',
        );
      }
    }
    return Container(
      width: double.infinity,
      color: RetrometerColors.surfaceHeader,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        parts.join('   ·   '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: RetrometerColors.primary, fontSize: 13),
      ),
    );
  }
}

PlannedStage? _findStage(List<Competition> comps, String id) {
  for (final c in comps) {
    for (final s in c.stages) {
      if (s.id == id) return s;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Stage tile.
// ---------------------------------------------------------------------------

class _StageTile extends ConsumerWidget {
  const _StageTile({required this.competitionId, required this.stage});

  final String competitionId;
  final PlannedStage stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runningId = ref.watch(
      stageControllerProvider.select(
        (s) => s.telemetry.status == StageStatus.inProgress &&
                s.config.id == stage.id
            ? s.config.id
            : null,
      ),
    );
    final isRunning = runningId == stage.id;

    final String statusLabel;
    final Color statusColor;
    if (isRunning) {
      statusLabel = 'ÎN CURS';
      statusColor = RetrometerColors.running;
    } else if (stage.started) {
      statusLabel = 'PORNIT';
      statusColor = RetrometerColors.started;
    } else {
      statusLabel = 'ÎN AȘTEPTARE';
      statusColor = RetrometerColors.waiting;
    }

    return MetadataTile(
      onTap: () => showStageEditor(context, ref, competitionId, stage),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusPill(text: statusLabel, color: statusColor),
          const SizedBox(height: 8),
          if (!isRunning)
            IconButton(
              icon: const Icon(Icons.play_arrow,
                  color: RetrometerColors.startFill),
              tooltip: 'Pornește acum',
              constraints: const BoxConstraints(
                  minHeight: 32, minWidth: 32),
              padding: EdgeInsets.zero,
              onPressed: () => ref
                  .read(stageControllerProvider.notifier)
                  .startStageFromPlan(stage)
                  .then((_) => ref
                      .read(competitionsProvider.notifier)
                      .markStarted(competitionId, stage.id)),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: RetrometerColors.danger),
            tooltip: 'Șterge',
            constraints:
                const BoxConstraints(minHeight: 32, minWidth: 32),
            padding: EdgeInsets.zero,
            onPressed: () => ref
                .read(competitionsProvider.notifier)
                .removeStage(competitionId, stage.id),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stage.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RetrometerTextStyles.tileTitle,
          ),
          const SizedBox(height: 6),
          InfoLine(
            icon: Icons.schedule,
            text: formatDateTime(stage.startTime),
            textStyle: RetrometerTextStyles.tileTime,
          ),
          const SizedBox(height: 4),
          InfoLine(
            icon: Icons.location_on,
            text: fmtCoordPair(stage.latitude, stage.longitude,
                radiusM: stage.geofenceRadiusM),
          ),
          const SizedBox(height: 4),
          Text(
            'țintă ${fmtSpeed(stage.targetAvgSpeed)} / '
            'max ${fmtSpeed(stage.maxSpeedLimit)} km/h'
            '${stage.autoStart ? ' · auto-start' : ' · manual'}',
            style: RetrometerTextStyles.metaMuted,
          ),
          if (stage.result != null) ...[
            const SizedBox(height: 4),
            InfoLine(
              icon: Icons.leaderboard,
              text: 'rezultat: max ${fmtSpeed(stage.result!.maxSpeedKmh)} / '
                  'min ${stage.result!.minSpeedKmh == null ? '—' : fmtSpeed(stage.result!.minSpeedKmh!)} / '
                  'med ${fmtSpeed(stage.result!.avgSpeedKmh)} km/h',
              iconColor: RetrometerColors.primary,
            ),
          ],
          if (stage.endLatitude != null && stage.endLongitude != null) ...[
            const SizedBox(height: 4),
            InfoLine(
              icon: Icons.flag,
              text:
                  'spre ${fmtCoordPair(stage.endLatitude, stage.endLongitude, radiusM: stage.endGeofenceRadiusM)}'
                  '${stage.autoStop ? ' · auto-stop' : ''}',
            ),
          ],
          if (stage.totalDistanceKm > 0 ||
              stage.allocatedTimeSeconds > 0) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (stage.totalDistanceKm > 0)
                  '${stage.totalDistanceKm.toStringAsFixed(2)} km',
                if (stage.allocatedTimeSeconds > 0)
                  'timp ${formatElapsed(stage.allocatedTimeSeconds)}',
              ].join(' · '),
              style: RetrometerTextStyles.metaMuted,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History section (per-competition stage run log).
// ---------------------------------------------------------------------------

/// Section header for the per-competition history log. Read-only.
class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
      child: Text('Istoric etape', style: RetrometerTextStyles.headerTitle),
    );
  }
}

/// A single finished stage run, shown read-only in the competition detail's
/// history section. Mirrors [_StageTile]'s visual structure but without
/// actions (no edit/delete/start).
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final StageRunHistory entry;

  @override
  Widget build(BuildContext context) {
    return MetadataTile(
      onTap: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.stageName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RetrometerTextStyles.tileTitle,
          ),
          if (entry.competitionName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.competitionName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RetrometerTextStyles.metaMuted,
            ),
          ],
          const SizedBox(height: 6),
          InfoLine(
            icon: Icons.schedule,
            text:
                '${formatDateTime(entry.startedAt)} → ${formatDateTime(entry.completedAt)}',
          ),
          if (entry.startLatitude != null &&
              entry.startLongitude != null) ...[
            const SizedBox(height: 4),
            InfoLine(
              icon: Icons.location_on,
              text: fmtCoordPair(
                  entry.startLatitude, entry.startLongitude),
            ),
          ],
          if (entry.endLatitude != null && entry.endLongitude != null) ...[
            const SizedBox(height: 4),
            InfoLine(
              icon: Icons.flag,
              text: fmtCoordPair(entry.endLatitude, entry.endLongitude),
            ),
          ],
          const SizedBox(height: 4),
          SpeedSummaryLine(
            maxSpeedKmh: entry.maxSpeedKmh,
            minSpeedKmh: entry.minSpeedKmh,
            avgSpeedKmh: entry.avgSpeedKmh,
          ),
          const SizedBox(height: 4),
          Text(
            [
              'țintă ${fmtSpeed(entry.targetAvgSpeed)} / '
                  'max ${fmtSpeed(entry.maxSpeedLimit)} km/h',
              '${entry.totalDistanceKm.toStringAsFixed(2)} km',
              'timp ${formatElapsed(entry.elapsedSeconds)}',
            ].join(' · '),
            style: RetrometerTextStyles.metaMuted,
          ),
        ],
      ),
    );
  }
}