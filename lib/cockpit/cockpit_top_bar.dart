import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../about_view.dart';
import '../competition_providers.dart';
import '../competition_view.dart';
import '../location_disclosure.dart';
import '../models.dart';
import '../state_providers.dart';
import '../theme/retrometer_theme.dart';
import '../utils/formatting.dart';
import '../widgets/cards.dart';
import '../widgets/compact_icon_button.dart';
import '../widgets/shrink_to_fit.dart';
import 'cockpit_config_sheet.dart';

/// Top cockpit zone: a header / body / footer card.
///
/// - **Header**: active competition + category (left), competitions + about
///   buttons (right).
/// - **Body**: current locality and the stage elapsed time.
/// - **Footer**: the stage controls — config gear, START/STOP, RESET — sized
///   up so they read clearly at a glance.
///
/// Wrapped in a [RepaintBoundary] so frequent state changes don't repaint the
/// rest of the screen. On very narrow screens (<360 px) the footer controls
/// collapse to icon-only so the row fits.
class CockpitTopBar extends ConsumerWidget {
  const CockpitTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the auto-start monitor alive while the cockpit is mounted.
    ref.watch(autoStartMonitorProvider);
    // Keep the stage-result persister alive while the cockpit is mounted so a
    // finished stage's max/min/avg snapshot is written onto its planned stage.
    ref.watch(stageResultPersisterProvider);
    final elapsed = ref.watch(elapsedSecondsProvider);
    final status = ref.watch(
      stageControllerProvider.select((s) => s.telemetry.status),
    );
    final locAsync = ref.watch(localityProvider);
    final locality =
        locAsync.valueOrNull ?? (locAsync.isLoading ? '…' : '—');
    // Active competition (if the running stage belongs to one) gives context
    // in the header: event name + category.
    final competition = ref.watch(activeCompetitionProvider);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, c) {
          // Very narrow windows (phone split-view) drop the control labels so
          // the footer row fits; everywhere else the buttons show full labels.
          final compact = c.maxWidth < 360;

          return _topBarCard(
            header: Row(
              children: [
                Expanded(child: _CompetitionLabel(competition: competition)),
                CompactIconButton(
                  icon: Icons.event_note,
                  color: context.colors.primary,
                  tooltip: 'Competiții',
                  compact: compact,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CompetitionView(),
                    ),
                  ),
                ),
                CompactIconButton(
                  icon: Icons.info_outline,
                  color: context.colors.textSecondary,
                  tooltip: 'Despre aplicație',
                  compact: compact,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  ),
                ),
              ],
            ),
            body: _CardBody(locality: locality, elapsed: elapsed),
            footer: Center(
              child: StageControls(status: status, compact: compact),
            ),
          );
        },
      ),
    );
  }
}

/// START / STOP / RESET + the config gear, wired to the [StageController].
/// Reusable: pass the current [status] to pick STOP vs START, and [compact]
/// for the icon-only variant used on very narrow bars.
class StageControls extends ConsumerWidget {
  const StageControls({super.key, required this.status, this.compact = false});

  final StageStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inProgress = status == StageStatus.inProgress;
    final gap = compact ? 6.0 : 8.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompactIconButton(
          icon: Icons.settings,
          color: context.colors.textSecondary,
          tooltip: 'Configurare stage',
          compact: compact,
          expandedIconSize: 22,
          expandedTouchSize: 36,
          onPressed:
              inProgress ? null : () => showStageConfigSheet(context, ref),
        ),
        SizedBox(width: gap),
        if (inProgress)
          ControlButton(
            icon: Icons.stop,
            label: 'STOP',
            color: context.colors.stopFill,
            onTap: ref.read(stageControllerProvider.notifier).stopStage,
            compact: compact,
          )
        else
          ControlButton(
            icon: Icons.play_arrow,
            label: 'START',
            color: context.colors.startFill,
            onTap: () async {
              // Prominent location disclosure must precede the permission
              // request; abort the stage start if the user declines it.
              if (!await maybeShowLocationDisclosure(context)) return;
              ref.read(stageControllerProvider.notifier).startStage();
            },
            compact: compact,
          ),
        SizedBox(width: gap),
        ControlButton(
          icon: Icons.refresh,
          label: 'RESET',
          color: context.colors.resetFill,
          foreground: context.colors.textPrimary,
          onTap: ref.read(stageControllerProvider.notifier).resetStage,
          compact: compact,
        ),
      ],
    );
  }
}

/// A single filled action button (START/STOP/RESET). Compact mode renders
/// icon-only so the bar fits on a phone in a short/split-view window.
class ControlButton extends StatelessWidget {
  const ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;
  // Defaults to black (for the bright START/STOP fills); RESET passes a light
  // color since its fill is a dark surface.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? context.colors.onActionFill;
    return TappableCard(
      color: color,
      radius: compact ? RetrometerRadii.control : RetrometerRadii.card,
      border: BorderSide.none,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 13, vertical: compact ? 7 : 10),
        child: compact
            ? Icon(icon, color: fg, size: 20)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: fg, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: context.text.controlLabel
                        .copyWith(color: fg, fontSize: 15),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private pieces.
// ---------------------------------------------------------------------------

/// The rounded surface card: header on top, body centered in the remaining
/// space, footer at the bottom.
Widget _topBarCard({
  required Widget header,
  required Widget body,
  required Widget footer,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
    child: SurfaceCard(
      radius: RetrometerRadii.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          header,
          const SizedBox(height: 8),
          Expanded(child: Center(child: body)),
          const SizedBox(height: 8),
          footer,
        ],
      ),
    ),
  );
}

/// Active competition name + category, left-aligned in the header. Collapses
/// to nothing when no competition is active.
class _CompetitionLabel extends StatelessWidget {
  const _CompetitionLabel({required this.competition});

  final Competition? competition;

  @override
  Widget build(BuildContext context) {
    final hasContent = competition != null &&
        (competition!.name.isNotEmpty || competition!.category.isNotEmpty);
    if (!hasContent) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.emoji_events, color: context.colors.primary, size: 15),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            [
              if (competition!.name.isNotEmpty) competition!.name,
              if (competition!.category.isNotEmpty) competition!.category,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.competitionRow,
          ),
        ),
      ],
    );
  }
}

/// Body: the current locality line and the stage elapsed time below it.
class _CardBody extends StatelessWidget {
  const _CardBody({required this.locality, required this.elapsed});

  final String locality;
  final int elapsed;

  @override
  Widget build(BuildContext context) {
    // The body slot (Expanded in _topBarCard) can be short in landscape, where
    // the top bar zone is ~25% of the screen height and the body slot ends up
    // only ~36px tall. The Column's natural height (locality row + 6px gap +
    // 30px elapsed text ≈ 54px) would overflow that slot.
    //
    // FittedBox(scaleDown) lays out its child at natural size and then shrinks
    // it to fit, so the block never overflows; in portrait where the slot is
    // roomy it stays at natural size and the elapsed time remains prominent.
    // FittedBox passes unbounded width to its child, so we wrap the Column in a
    // SizedBox bounded to the slot width — that keeps the locality Row's
    // Flexible able to ellipsize long names instead of forcing the whole block
    // wider.
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth.isFinite ? c.maxWidth : 400.0;
        return ShrinkToFit(
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on,
                        color: context.colors.primary, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        locality,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.topBarText(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  formatElapsed(elapsed),
                  style: context.text.topBarElapsed,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

