import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'competition_providers.dart';
import 'models.dart';
import 'services/gps_service.dart';
import 'state_providers.dart';

// ---------------------------------------------------------------------------
// Competitions list screen.
// ---------------------------------------------------------------------------

/// Lists all competitions. Tap a competition to open its detail (metadata +
/// stages). The auto-start monitor is kept alive from the cockpit; its
/// diagnostics bar lives on the competition detail screen.
class CompetitionsScreen extends ConsumerWidget {
  const CompetitionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(competitionsProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Competiții'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
        onPressed: () => _showCompetitionEditor(context, ref, null),
      ),
      body: SafeArea(
        child: async.when(
          data: (competitions) {
            if (competitions.isEmpty) return const _EmptyCompetitions();
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: competitions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _CompetitionTile(competition: competitions[i]),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.greenAccent),
          ),
          error: (e, _) => Center(
            child: Text('Eroare: $e',
                style: const TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _EmptyCompetitions extends StatelessWidget {
  const _EmptyCompetitions();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'Nicio competiție.\n'
              'Apasă + ca să adaugi prima competiție (nume, locație, piloți, '
              'mașină, categorie), apoi îi adaugi stagii.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompetitionTile extends StatelessWidget {
  const _CompetitionTile({required this.competition});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final hasStandings =
        competition.overallStanding > 0 || competition.categoryStanding > 0;
    return Material(
      color: const Color(0xFF141414),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CompetitionDetailScreen(id: competition.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events,
                      color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      competition.name.isEmpty
                          ? '(fără nume)'
                          : competition.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (hasStandings)
                    _StandingBadge(
                      overall: competition.overallStanding,
                      category: competition.categoryStanding,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (competition.location.isNotEmpty)
                    _MetaChip(icon: Icons.place, text: competition.location),
                  if (competition.date != null)
                    _MetaChip(
                        icon: Icons.event, text: _formatDate(competition.date!)),
                  if (competition.category.isNotEmpty)
                    _MetaChip(
                        icon: Icons.label, text: competition.category),
                  if (competition.car.isNotEmpty)
                    _MetaChip(icon: Icons.directions_car, text: competition.car),
                  _MetaChip(
                    icon: Icons.list,
                    text:
                        '${competition.stages.length} ${competition.stages.length == 1 ? 'stagiu' : 'stagii'}',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  if (competition.pilot.isNotEmpty) 'pilot ${competition.pilot}',
                  if (competition.copilot.isNotEmpty)
                    'copilot ${competition.copilot}',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandingBadge extends StatelessWidget {
  const _StandingBadge({required this.overall, required this.category});

  final int overall;
  final int category;

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    final text = overall > 0 && category > 0
        ? '${two(overall)} / ${two(category)}'
        : two(overall > 0 ? overall : category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
      ),
      child: Text(
        'loc $text',
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 15),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Competiție'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.greenAccent),
            tooltip: 'Editează competiția',
            onPressed: () async {
              final comp = async.valueOrNull
                  ?.firstWhere((c) => c.id == id, orElse: () => const Competition(id: ''));
              if (comp == null || comp.id.isEmpty) return;
              await _showCompetitionEditor(context, ref, comp);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Șterge competiția',
            onPressed: () async {
              final confirmed = await _confirm(
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
        backgroundColor: Colors.green,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
        onPressed: () => _showStageEditor(context, ref, id, null),
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
                      ? const _EmptyStages()
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
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.greenAccent),
          ),
          error: (e, _) => Center(
            child: Text('Eroare: $e',
                style: const TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _EmptyStages extends StatelessWidget {
  const _EmptyStages();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note, color: Colors.white24, size: 56),
            SizedBox(height: 14),
            Text(
              'Niciun stagiu în această competiție.\n'
              'Apasă + ca să adaugi primul stagiu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 15, height: 1.4),
            ),
          ],
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
    final rows = <_HeaderRow>[
      if (competition.pilot.isNotEmpty || competition.copilot.isNotEmpty)
        _HeaderRow(
          icon: Icons.people,
          label: 'Echipaj',
          value: [
            if (competition.pilot.isNotEmpty) 'pilot ${competition.pilot}',
            if (competition.copilot.isNotEmpty) 'copilot ${competition.copilot}',
          ].join(' · '),
        ),
      if (competition.car.isNotEmpty)
        _HeaderRow(icon: Icons.directions_car, label: 'Mașină', value: competition.car),
      if (competition.category.isNotEmpty)
        _HeaderRow(icon: Icons.label, label: 'Categorie', value: competition.category),
      _HeaderRow(
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
        _HeaderRow(icon: Icons.place, label: 'Locație', value: competition.location),
      if (competition.date != null)
        _HeaderRow(
            icon: Icons.event, label: 'Data', value: _formatDate(competition.date!)),
      if (competition.contactPerson.isNotEmpty ||
          competition.contactPhone != null)
        _HeaderRow(
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
        _HeaderRow(
          icon: Icons.payments,
          label: 'Cost',
          value: competition.cost.toStringAsFixed(2),
        ),
    ];
    if (rows.isEmpty) {
      rows.add(const _HeaderRow(
        icon: Icons.info_outline,
        label: 'Detalii',
        value: 'Apasă ✏️ ca să completezi detaliile competiției.',
      ));
    }
    return Container(
      width: double.infinity,
      color: const Color(0xFF0C1A0C),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            competition.name.isEmpty ? '(fără nume)' : competition.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? Colors.greenAccent : Colors.white70;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(color: Colors.white54, fontSize: 13)),
        Text(value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
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
      color: const Color(0xFF0C1A0C),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        parts.join('   ·   '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
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
      statusColor = Colors.greenAccent;
    } else if (stage.started) {
      statusLabel = 'PORNIT';
      statusColor = Colors.white54;
    } else {
      statusLabel = 'ÎN AȘTEPTARE';
      statusColor = Colors.amberAccent;
    }

    return Material(
      color: const Color(0xFF141414),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showStageEditor(context, ref, competitionId, stage),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            color: Colors.white54, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _formatDateTime(stage.startTime),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.white54, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${stage.latitude.toStringAsFixed(5)}, '
                            '${stage.longitude.toStringAsFixed(5)} '
                            '(±${stage.geofenceRadiusM.toStringAsFixed(0)} m)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'țintă ${stage.targetAvgSpeed.toStringAsFixed(0)} / '
                      'max ${stage.maxSpeedLimit.toStringAsFixed(0)} km/h'
                      '${stage.autoStart ? ' · auto-start' : ' · manual'}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 13),
                    ),
                    if (stage.endLatitude != null && stage.endLongitude != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.flag,
                              color: Colors.white54, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'spre ${stage.endLatitude!.toStringAsFixed(5)}, '
                              '${stage.endLongitude!.toStringAsFixed(5)} '
                              '(±${stage.endGeofenceRadiusM.toStringAsFixed(0)} m)'
                              '${stage.autoStop ? ' · auto-stop' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                          ),
                        ],
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
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 13),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!isRunning)
                    IconButton(
                      icon: const Icon(Icons.play_arrow, color: Colors.green),
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
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stage editor sheet.
// ---------------------------------------------------------------------------

Future<void> _showStageEditor(
  BuildContext context,
  WidgetRef ref,
  String competitionId,
  PlannedStage? existing,
) async {
  final result = await showModalBottomSheet<_StageDraft>(
    context: context,
    backgroundColor: Colors.grey[900],
    isScrollControlled: true,
    builder: (context) => _StageEditor(existing: existing),
  );
  if (result == null) return;
  final notifier = ref.read(competitionsProvider.notifier);
  final stage = PlannedStage(
    id: existing?.id ?? _newId(),
    name: result.name,
    startTime: result.startTime,
    targetAvgSpeed: result.targetAvgSpeed,
    maxSpeedLimit: result.maxSpeedLimit,
    latitude: result.latitude,
    longitude: result.longitude,
    geofenceRadiusM: result.geofenceRadiusM,
    autoStart: result.autoStart,
    started: existing?.started ?? false,
    endLatitude: result.endLatitude,
    endLongitude: result.endLongitude,
    endGeofenceRadiusM: result.endGeofenceRadiusM,
    autoStop: result.autoStop,
    totalDistanceKm: result.totalDistanceKm,
    allocatedTimeSeconds: result.allocatedTimeSeconds,
  );
  if (existing == null) {
    await notifier.addStage(competitionId, stage);
  } else {
    await notifier.updateStage(competitionId, stage);
  }
}

class _StageDraft {
  _StageDraft({
    required this.name,
    required this.startTime,
    required this.targetAvgSpeed,
    required this.maxSpeedLimit,
    required this.latitude,
    required this.longitude,
    required this.geofenceRadiusM,
    required this.autoStart,
    required this.endLatitude,
    required this.endLongitude,
    required this.endGeofenceRadiusM,
    required this.autoStop,
    required this.totalDistanceKm,
    required this.allocatedTimeSeconds,
  });

  String name;
  DateTime startTime;
  double targetAvgSpeed;
  double maxSpeedLimit;
  double latitude;
  double longitude;
  double geofenceRadiusM;
  bool autoStart;
  double? endLatitude;
  double? endLongitude;
  double endGeofenceRadiusM;
  bool autoStop;
  double totalDistanceKm;
  int allocatedTimeSeconds;
}

class _StageEditor extends StatefulWidget {
  const _StageEditor({this.existing});

  final PlannedStage? existing;

  @override
  State<_StageEditor> createState() => _StageEditorState();
}

class _StageEditorState extends State<_StageEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _radiusCtrl;
  late final TextEditingController _endAddressCtrl;
  late final TextEditingController _endLatCtrl;
  late final TextEditingController _endLngCtrl;
  late final TextEditingController _endRadiusCtrl;
  late final TextEditingController _distCtrl;
  late final TextEditingController _allocMinCtrl;
  late final TextEditingController _allocSecCtrl;
  late _StageDraft _draft;
  bool _geocoding = false;
  bool _endGeocoding = false;
  String? _addressError;
  String? _endAddressError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _draft = _StageDraft(
      name: e?.name ?? '',
      startTime: e?.startTime ??
          _roundToMinute(DateTime.now().add(const Duration(minutes: 30))),
      targetAvgSpeed: e?.targetAvgSpeed ?? 40.0,
      maxSpeedLimit: e?.maxSpeedLimit ?? 60.0,
      latitude: e?.latitude ?? 0.0,
      longitude: e?.longitude ?? 0.0,
      geofenceRadiusM: e?.geofenceRadiusM ?? 200.0,
      autoStart: e?.autoStart ?? true,
      endLatitude: e?.endLatitude,
      endLongitude: e?.endLongitude,
      endGeofenceRadiusM: e?.endGeofenceRadiusM ?? 200.0,
      autoStop: e?.autoStop ?? true,
      totalDistanceKm: e?.totalDistanceKm ?? 0.0,
      allocatedTimeSeconds: e?.allocatedTimeSeconds ?? 0,
    );
    _nameCtrl = TextEditingController(text: _draft.name);
    _addressCtrl = TextEditingController();
    _latCtrl = TextEditingController(text: _fmtCoord(_draft.latitude));
    _lngCtrl = TextEditingController(text: _fmtCoord(_draft.longitude));
    _radiusCtrl = TextEditingController(
        text: _draft.geofenceRadiusM.toStringAsFixed(0));
    _endAddressCtrl = TextEditingController();
    _endLatCtrl = TextEditingController(
        text: _draft.endLatitude == null ? '' : _fmtCoord(_draft.endLatitude!));
    _endLngCtrl = TextEditingController(
        text: _draft.endLongitude == null ? '' : _fmtCoord(_draft.endLongitude!));
    _endRadiusCtrl = TextEditingController(
        text: _draft.endGeofenceRadiusM.toStringAsFixed(0));
    _distCtrl = TextEditingController(
      text: _draft.totalDistanceKm == 0.0
          ? ''
          : _draft.totalDistanceKm.toStringAsFixed(2),
    );
    _allocMinCtrl = TextEditingController(
        text: (_draft.allocatedTimeSeconds ~/ 60).toString());
    _allocSecCtrl = TextEditingController(
        text: (_draft.allocatedTimeSeconds % 60).toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    _endAddressCtrl.dispose();
    _endLatCtrl.dispose();
    _endLngCtrl.dispose();
    _endRadiusCtrl.dispose();
    _distCtrl.dispose();
    _allocMinCtrl.dispose();
    _allocSecCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Stage nou' : 'Editare stage',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nume',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
              ),
              onChanged: (v) => _draft.name = v,
            ),
            const SizedBox(height: 16),
            _DateTimeField(
              value: _draft.startTime,
              onChanged: (dt) => setState(() => _draft.startTime = dt),
            ),
            const SizedBox(height: 16),
            _NumberField(
              label: 'Viteză medie țintă (km/h)',
              value: _draft.targetAvgSpeed,
              onChanged: (v) => _draft.targetAvgSpeed = v,
            ),
            const SizedBox(height: 16),
            _NumberField(
              label: 'Limită maximă (km/h)',
              value: _draft.maxSpeedLimit,
              onChanged: (v) => _draft.maxSpeedLimit = v,
            ),
            const SizedBox(height: 20),
            const Text('Locație start (geofence)',
                style: TextStyle(color: Colors.greenAccent, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Adresă (ex. Str. Mare 12, Sibiu)',
                      hintStyle: TextStyle(color: Colors.white30),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white38),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _geocoding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.greenAccent),
                        )
                      : const Icon(Icons.search, color: Colors.greenAccent),
                  tooltip: 'Caută adresă',
                  onPressed: _geocoding ? null : _geocodeAddress,
                ),
              ],
            ),
            if (_addressError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_addressError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CoordField(
                    label: 'Lat',
                    controller: _latCtrl,
                    onChanged: (v) => _draft.latitude = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CoordField(
                    label: 'Lng',
                    controller: _lngCtrl,
                    onChanged: (v) => _draft.longitude = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Rază geofence (m)',
                    value: _draft.geofenceRadiusM,
                    onChanged: (v) {
                      _draft.geofenceRadiusM = v;
                      _radiusCtrl.text = v.toStringAsFixed(0);
                    },
                    controller: _radiusCtrl,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.my_location, color: Colors.greenAccent),
                  label: const Text('Locația mea',
                      style: TextStyle(color: Colors.greenAccent)),
                  onPressed: _useCurrentLocation,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _NumberField(
              label: 'Distanță totală (km)',
              value: _draft.totalDistanceKm,
              decimals: 2,
              controller: _distCtrl,
              onChanged: (v) => _draft.totalDistanceKm = v,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Timp total alocat',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 16)),
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _allocMinCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'min',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white38),
                      ),
                    ),
                    onChanged: (s) {
                      final m = int.tryParse(s) ?? 0;
                      _draft.allocatedTimeSeconds =
                          m * 60 + (_draft.allocatedTimeSeconds % 60);
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(':',
                      style: TextStyle(color: Colors.white70, fontSize: 20)),
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _allocSecCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'sec',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white38),
                      ),
                    ),
                    onChanged: (s) {
                      final sec = int.tryParse(s) ?? 0;
                      _draft.allocatedTimeSeconds =
                          (_draft.allocatedTimeSeconds ~/ 60) * 60 + sec;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Locație finală (geofence auto-stop)',
                style: TextStyle(color: Colors.greenAccent, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _endAddressCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Adresă sosire (ex. Str. Mare 99, Sibiu)',
                      hintStyle: TextStyle(color: Colors.white30),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white38),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _endGeocoding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.greenAccent),
                        )
                      : const Icon(Icons.search, color: Colors.greenAccent),
                  tooltip: 'Caută adresă',
                  onPressed: _endGeocoding ? null : _geocodeEndAddress,
                ),
              ],
            ),
            if (_endAddressError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_endAddressError!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12)),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CoordField(
                    label: 'Lat final',
                    controller: _endLatCtrl,
                    onChanged: (v) => _draft.endLatitude = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CoordField(
                    label: 'Lng final',
                    controller: _endLngCtrl,
                    onChanged: (v) => _draft.endLongitude = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Rază sosire (m)',
                    value: _draft.endGeofenceRadiusM,
                    onChanged: (v) {
                      _draft.endGeofenceRadiusM = v;
                      _endRadiusCtrl.text = v.toStringAsFixed(0);
                    },
                    controller: _endRadiusCtrl,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.my_location, color: Colors.greenAccent),
                  label: const Text('Locația mea',
                      style: TextStyle(color: Colors.greenAccent)),
                  onPressed: _useCurrentEndLocation,
                ),
              ],
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Auto-stop la ajungere în geofence',
                  style: TextStyle(color: Colors.white)),
              value: _draft.autoStop,
              onChanged: (v) => setState(() => _draft.autoStop = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              dense: true,
              title: const Text('Auto-start la ora + locație',
                  style: TextStyle(color: Colors.white)),
              value: _draft.autoStart,
              onChanged: (v) => setState(() => _draft.autoStart = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
  }

  void _geocodeAddress() async {
    final query = _addressCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _geocoding = true;
      _addressError = null;
    });
    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        setState(() => _addressError = 'Adresa nu a fost găsită.');
      } else {
        final loc = locations.first;
        _draft.latitude = loc.latitude;
        _draft.longitude = loc.longitude;
        _latCtrl.text = _fmtCoord(_draft.latitude);
        _lngCtrl.text = _fmtCoord(_draft.longitude);
        setState(() {});
      }
    } on Exception {
      setState(() => _addressError = 'Geocodare indisponibilă (offline?).');
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  void _useCurrentLocation() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final gps = container.read(gpsServiceProvider);
    if (!await gps.isLocationServiceEnabled()) return;
    var perm = await gps.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await gps.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }
    try {
      final pos =
          await gps.positionStream().first.timeout(const Duration(seconds: 10));
      _draft.latitude = pos.latitude;
      _draft.longitude = pos.longitude;
      _latCtrl.text = _fmtCoord(_draft.latitude);
      _lngCtrl.text = _fmtCoord(_draft.longitude);
      setState(() {});
    } on Exception {
      // ignore — leave coords as-is
    }
  }

  void _geocodeEndAddress() async {
    final query = _endAddressCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _endGeocoding = true;
      _endAddressError = null;
    });
    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        setState(() => _endAddressError = 'Adresa nu a fost găsită.');
      } else {
        final loc = locations.first;
        _draft.endLatitude = loc.latitude;
        _draft.endLongitude = loc.longitude;
        _endLatCtrl.text = _fmtCoord(_draft.endLatitude!);
        _endLngCtrl.text = _fmtCoord(_draft.endLongitude!);
        setState(() {});
      }
    } on Exception {
      setState(() => _endAddressError = 'Geocodare indisponibilă (offline?).');
    } finally {
      if (mounted) setState(() => _endGeocoding = false);
    }
  }

  void _useCurrentEndLocation() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final gps = container.read(gpsServiceProvider);
    if (!await gps.isLocationServiceEnabled()) return;
    var perm = await gps.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await gps.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }
    try {
      final pos =
          await gps.positionStream().first.timeout(const Duration(seconds: 10));
      _draft.endLatitude = pos.latitude;
      _draft.endLongitude = pos.longitude;
      _endLatCtrl.text = _fmtCoord(_draft.endLatitude!);
      _endLngCtrl.text = _fmtCoord(_draft.endLongitude!);
      setState(() {});
    } on Exception {
      // ignore — leave coords as-is
    }
  }

  bool _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _addressError = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introdu un nume.')),
      );
      return false;
    }
    // Empty end-coord fields mean "no finish set" (nullable).
    final endLat = double.tryParse(_endLatCtrl.text.trim());
    final endLng = double.tryParse(_endLngCtrl.text.trim());
    final draft = _StageDraft(
      name: name,
      startTime: _draft.startTime,
      targetAvgSpeed: _draft.targetAvgSpeed,
      maxSpeedLimit: _draft.maxSpeedLimit,
      latitude: _draft.latitude,
      longitude: _draft.longitude,
      geofenceRadiusM: _draft.geofenceRadiusM,
      autoStart: _draft.autoStart,
      endLatitude: (endLat == null || endLng == null) ? null : endLat,
      endLongitude: (endLat == null || endLng == null) ? null : endLng,
      endGeofenceRadiusM: _draft.endGeofenceRadiusM,
      autoStop: _draft.autoStop,
      totalDistanceKm: _draft.totalDistanceKm,
      allocatedTimeSeconds: _draft.allocatedTimeSeconds,
    );
    Navigator.of(context).pop(draft);
    return true;
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('Start: ${_formatDateTime(value)}',
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ),
        TextButton(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Colors.greenAccent,
                  ),
                ),
                child: child!,
              ),
            );
            if (d == null) return;
            if (!context.mounted) return;
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(value),
              builder: (context, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Colors.greenAccent,
                  ),
                ),
                child: child!,
              ),
            );
            if (t == null) return;
            onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
          },
          child: const Text('Alege data/ora',
              style: TextStyle(color: Colors.greenAccent)),
        ),
      ],
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.controller,
    this.decimals = 0,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final TextEditingController? controller;
  final int decimals;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        TextEditingController(
            text: widget.value.toStringAsFixed(widget.decimals));
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = widget.decimals > 0
        ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))
        : FilteringTextInputFormatter.digitsOnly;
    return Row(
      children: [
        Expanded(
          child: Text(widget.label,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            controller: _controller,
            keyboardType: widget.decimals > 0
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20),
            inputFormatters: [formatter],
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
              ),
            ),
            onChanged: (s) {
              final v = double.tryParse(s);
              if (v != null) widget.onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

class _CoordField extends StatefulWidget {
  const _CoordField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<double> onChanged;

  @override
  State<_CoordField> createState() => _CoordFieldState();
}

class _CoordFieldState extends State<_CoordField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(color: Colors.white70),
        isDense: true,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
        ),
      ),
      onChanged: (s) {
        final v = double.tryParse(s);
        if (v != null) widget.onChanged(v);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Competition editor sheet.
// ---------------------------------------------------------------------------

Future<void> _showCompetitionEditor(
  BuildContext context,
  WidgetRef ref,
  Competition? existing,
) async {
  final result = await showModalBottomSheet<_CompetitionDraft>(
    context: context,
    backgroundColor: Colors.grey[900],
    isScrollControlled: true,
    builder: (context) => _CompetitionEditor(existing: existing),
  );
  if (result == null) return;
  final notifier = ref.read(competitionsProvider.notifier);
  final competition = Competition(
    id: existing?.id ?? 'comp-${DateTime.now().millisecondsSinceEpoch}',
    name: result.name,
    location: result.location,
    date: result.date,
    pilot: result.pilot,
    copilot: result.copilot,
    car: result.car,
    category: result.category,
    totalTeams: result.totalTeams,
    contactPerson: result.contactPerson,
    contactPhone: result.contactPhone,
    cost: result.cost,
    overallStanding: result.overallStanding,
    categoryStanding: result.categoryStanding,
    stages: existing?.stages ?? const <PlannedStage>[],
  );
  if (existing == null) {
    await notifier.addCompetition(competition);
  } else {
    await notifier.updateCompetition(competition);
  }
}

class _CompetitionDraft {
  _CompetitionDraft({
    required this.name,
    required this.location,
    required this.date,
    required this.pilot,
    required this.copilot,
    required this.car,
    required this.category,
    required this.totalTeams,
    required this.contactPerson,
    required this.contactPhone,
    required this.cost,
    required this.overallStanding,
    required this.categoryStanding,
  });

  String name;
  String location;
  DateTime? date;
  String pilot;
  String copilot;
  String car;
  String category;
  int totalTeams;
  String contactPerson;
  String contactPhone;
  double cost;
  int overallStanding;
  int categoryStanding;
}

class _CompetitionEditor extends StatefulWidget {
  const _CompetitionEditor({this.existing});

  final Competition? existing;

  @override
  State<_CompetitionEditor> createState() => _CompetitionEditorState();
}

class _CompetitionEditorState extends State<_CompetitionEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _pilotCtrl;
  late final TextEditingController _copilotCtrl;
  late final TextEditingController _carCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _totalTeamsCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _contactPhoneCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _overallCtrl;
  late final TextEditingController _categoryStandingCtrl;
  late _CompetitionDraft _draft;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _draft = _CompetitionDraft(
      name: e?.name ?? '',
      location: e?.location ?? '',
      date: e?.date,
      pilot: e?.pilot ?? '',
      copilot: e?.copilot ?? '',
      car: e?.car ?? '',
      category: e?.category ?? '',
      totalTeams: e?.totalTeams ?? 0,
      contactPerson: e?.contactPerson ?? '',
      contactPhone: e?.contactPhone ?? '',
      cost: e?.cost ?? 0.0,
      overallStanding: e?.overallStanding ?? 0,
      categoryStanding: e?.categoryStanding ?? 0,
    );
    _nameCtrl = TextEditingController(text: _draft.name);
    _locationCtrl = TextEditingController(text: _draft.location);
    _pilotCtrl = TextEditingController(text: _draft.pilot);
    _copilotCtrl = TextEditingController(text: _draft.copilot);
    _carCtrl = TextEditingController(text: _draft.car);
    _categoryCtrl = TextEditingController(text: _draft.category);
    _totalTeamsCtrl = TextEditingController(
        text: _draft.totalTeams == 0 ? '' : _draft.totalTeams.toString());
    _contactCtrl = TextEditingController(text: _draft.contactPerson);
    _contactPhoneCtrl = TextEditingController(text: _draft.contactPhone);
    _costCtrl = TextEditingController(
        text: _draft.cost == 0.0 ? '' : _draft.cost.toStringAsFixed(2));
    _overallCtrl = TextEditingController(
        text: _draft.overallStanding == 0 ? '' : _draft.overallStanding.toString());
    _categoryStandingCtrl = TextEditingController(
        text: _draft.categoryStanding == 0
            ? ''
            : _draft.categoryStanding.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _pilotCtrl.dispose();
    _copilotCtrl.dispose();
    _carCtrl.dispose();
    _categoryCtrl.dispose();
    _totalTeamsCtrl.dispose();
    _contactCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _costCtrl.dispose();
    _overallCtrl.dispose();
    _categoryStandingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null
                  ? 'Competiție nouă'
                  : 'Editare competiție',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _TextField(controller: _nameCtrl, label: 'Nume competiție'),
            const SizedBox(height: 12),
            _TextField(controller: _locationCtrl, label: 'Locație (ex. Cluj)'),
            const SizedBox(height: 12),
            _DateField(
              value: _draft.date,
              onChanged: (dt) => setState(() => _draft.date = dt),
            ),
            const SizedBox(height: 12),
            _TextField(controller: _pilotCtrl, label: 'Pilot'),
            const SizedBox(height: 12),
            _TextField(controller: _copilotCtrl, label: 'Copilot'),
            const SizedBox(height: 12),
            _TextField(
                controller: _carCtrl, label: 'Mașină (ex. BMW Z3)'),
            const SizedBox(height: 12),
            _TextField(controller: _categoryCtrl, label: 'Categorie'),
            const SizedBox(height: 12),
            _IntField(
              controller: _totalTeamsCtrl,
              label: 'Număr total echipe',
              onChanged: (v) => _draft.totalTeams = v,
            ),
            const SizedBox(height: 12),
            _TextField(
                controller: _contactCtrl, label: 'Persoană de contact'),
            const SizedBox(height: 12),
            _TextField(
              controller: _contactPhoneCtrl,
              label: 'Telefon contact',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _DecimalField(
              controller: _costCtrl,
              label: 'Cost competiție',
              onChanged: (v) => _draft.cost = v,
            ),
            const SizedBox(height: 16),
            const Text('Locul curent',
                style: TextStyle(color: Colors.greenAccent, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _IntField(
                    controller: _overallCtrl,
                    label: 'La general',
                    onChanged: (v) => _draft.overallStanding = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _IntField(
                    controller: _categoryStandingCtrl,
                    label: 'În categorie',
                    onChanged: (v) => _draft.categoryStanding = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
  }

  bool _save() {
    final draft = _CompetitionDraft(
      name: _nameCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      date: _draft.date,
      pilot: _pilotCtrl.text.trim(),
      copilot: _copilotCtrl.text.trim(),
      car: _carCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      totalTeams: int.tryParse(_totalTeamsCtrl.text.trim()) ?? 0,
      contactPerson: _contactCtrl.text.trim(),
      contactPhone: _contactPhoneCtrl.text.trim(),
      cost: double.tryParse(_costCtrl.text.trim()) ?? 0.0,
      overallStanding: int.tryParse(_overallCtrl.text.trim()) ?? 0,
      categoryStanding: int.tryParse(_categoryStandingCtrl.text.trim()) ?? 0,
    );
    Navigator.of(context).pop(draft);
    return true;
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white38),
        ),
      ),
    );
  }
}

class _IntField extends StatefulWidget {
  const _IntField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  State<_IntField> createState() => _IntFieldState();
}

class _IntFieldState extends State<_IntField> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(widget.label,
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
        ),
        SizedBox(
          width: 90,
          child: TextField(
            controller: widget.controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
              ),
            ),
            onChanged: (s) {
              final v = int.tryParse(s);
              if (v != null) widget.onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

class _DecimalField extends StatefulWidget {
  const _DecimalField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  State<_DecimalField> createState() => _DecimalFieldState();
}

class _DecimalFieldState extends State<_DecimalField> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(widget.label,
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            controller: widget.controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
            ],
            decoration: const InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
              ),
            ),
            onChanged: (s) {
              final v = double.tryParse(s);
              if (v != null) widget.onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value == null
                ? 'Data: —'
                : 'Data: ${_formatDate(value!)}',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
        TextButton(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              builder: (context, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Colors.greenAccent,
                  ),
                ),
                child: child!,
              ),
            );
            onChanged(d);
          },
          child: Text(
            value == null ? 'Alege data' : 'Schimbă',
            style: const TextStyle(color: Colors.greenAccent),
          ),
        ),
        if (value != null)
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
            tooltip: 'Șterge data',
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers + confirm dialog.
// ---------------------------------------------------------------------------

String _newId() => 'stage-${DateTime.now().millisecondsSinceEpoch}';

DateTime _roundToMinute(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);

String _fmtCoord(double v) => v.toStringAsFixed(5);

String _fmtMmSs(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(m)}:${two(s)}';
}

String _formatDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

String _formatDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Anulează'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Șterge', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  return result ?? false;
}