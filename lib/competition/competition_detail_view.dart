import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../competition_providers.dart';
import '../models.dart';
import '../state_providers.dart';
import '../theme/retrometer_theme.dart';
import '../widgets/form_fields.dart';
import '../widgets/info_widgets.dart';
import '../widgets/cards.dart';
import 'competition_editor.dart';
import 'stage_editor.dart';

// ---------------------------------------------------------------------------
// Competition detail screen.
// ---------------------------------------------------------------------------

class CompetitionDetailScreen extends ConsumerWidget {
  const CompetitionDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(competitionsProvider);
    return Scaffold(
      appBar: AppBar(
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
                if (context.mounted) Navigator.of(context).pop();
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
              // Deleted — pop back to the list.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) Navigator.of(context).pop();
              });
              return const SizedBox.shrink();
            }
            final competition = competitions[i];
            final sorted = [...competition.stages]
              ..sort((a, b) => a.startTime.compareTo(b.startTime));
            return Column(
              children: [
                _CompetitionHeader(competition: competition),
                const _MonitorStatusBar(),
                Expanded(
                  child: sorted.isEmpty
                      ? const EmptyState(
                          icon: Icons.event_note,
                          message: 'Niciun stagiu în această competiție.\n'
                              'Apasă + ca să adaugi primul stagiu.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                          itemCount: sorted.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => _StageTile(
                            competitionId: competition.id,
                            stage: sorted[i],
                          ),
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
    String two(int n) => n.toString().padLeft(2, '0');
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

    return TappableCard(
      onTap: () => showStageEditor(context, ref, competitionId, stage),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
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
                    text: '${stage.latitude.toStringAsFixed(5)}, '
                        '${stage.longitude.toStringAsFixed(5)} '
                        '(±${stage.geofenceRadiusM.toStringAsFixed(0)} m)',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'țintă ${_fmtSpeed(stage.targetAvgSpeed)} / '
                    'max ${_fmtSpeed(stage.maxSpeedLimit)} km/h'
                    '${stage.autoStart ? ' · auto-start' : ' · manual'}',
                    style: RetrometerTextStyles.metaMuted,
                  ),
                  if (stage.endLatitude != null && stage.endLongitude != null) ...[
                    const SizedBox(height: 4),
                    InfoLine(
                      icon: Icons.flag,
                      text: 'spre ${stage.endLatitude!.toStringAsFixed(5)}, '
                          '${stage.endLongitude!.toStringAsFixed(5)} '
                          '(±${stage.endGeofenceRadiusM.toStringAsFixed(0)} m)'
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
                          'timp ${_fmtMmSs(stage.allocatedTimeSeconds)}',
                      ].join(' · '),
                      style: RetrometerTextStyles.metaMuted,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
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
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------

/// Speed display: whole numbers without a decimal (40), fractional with one
/// (35.9) — so a target average entered as 35.9 shows as 35.9, not 36.
String _fmtSpeed(double v) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _fmtMmSs(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(m)}:${two(s)}';
}