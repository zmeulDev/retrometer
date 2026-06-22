import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../competition_providers.dart';
import '../models.dart';
import '../theme/retrometer_theme.dart';
import '../utils/formatting.dart';
import '../widgets/form_fields.dart';
import '../widgets/info_widgets.dart';
import '../widgets/metadata_tile.dart';
import 'competition_editor.dart';

// ---------------------------------------------------------------------------
// Competitions list screen.
// ---------------------------------------------------------------------------

/// Lists all competitions. Tap a competition to open its detail (metadata +
/// stages). The auto-start monitor is kept alive from the cockpit; its
/// diagnostics bar lives on the competition detail screen.
class CompetitionsScreen extends ConsumerWidget {
  const CompetitionsScreen({super.key, required this.onOpen});

  /// Called when the crew taps a competition; the composition root switches to
  /// that competition's detail in place.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(competitionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Competiții')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => showCompetitionEditor(context, ref, null),
      ),
      body: SafeArea(
        child: async.when(
          data: (competitions) {
            if (competitions.isEmpty) {
              return const EmptyState(
                icon: Icons.emoji_events,
                iconSize: 64,
                message: 'Nicio competiție.\n'
                    'Apasă + ca să adaugi prima competiție (nume, locație, piloți, '
                    'mașină, categorie), apoi îi adaugi stagii.',
                titleStyle: RetrometerTextStyles.emptyTitle,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: competitions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _CompetitionTile(
                competition: competitions[i],
                onOpen: onOpen,
              ),
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

class _CompetitionTile extends StatelessWidget {
  const _CompetitionTile({required this.competition, required this.onOpen});

  final Competition competition;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final hasStandings =
        competition.overallStanding > 0 || competition.categoryStanding > 0;
    return MetadataTile(
      onTap: () => onOpen(competition.id),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events,
                  color: RetrometerColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  competition.name.isEmpty
                      ? '(fără nume)'
                      : competition.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RetrometerTextStyles.tileTitle,
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
                MetaChip(icon: Icons.place, text: competition.location),
              if (competition.startDate != null)
                MetaChip(
                  icon: Icons.event,
                  text: formatDateRange(
                      competition.startDate, competition.endDate)),
              if (competition.category.isNotEmpty)
                MetaChip(icon: Icons.label, text: competition.category),
              if (competition.car.isNotEmpty)
                MetaChip(icon: Icons.directions_car, text: competition.car),
              MetaChip(
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
            style: RetrometerTextStyles.meta,
          ),
        ],
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
    final text = overall > 0 && category > 0
        ? '${two(overall)} / ${two(category)}'
        : two(overall > 0 ? overall : category);
    return StatusPill(text: 'loc $text', color: RetrometerColors.primary);
  }
}