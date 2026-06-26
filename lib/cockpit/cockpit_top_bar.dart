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
/// rest of the screen.
///
/// The footer controls collapse to icon-only (`compact`) when there isn't
/// room for the labelled buttons: on narrow screens (<360 px **at the current
/// text scale**), on short top-bar zones (phone landscape, large system
/// insets), or at large accessibility text scales where the labels would
/// overflow the row. When the zone is short the card also tightens its
/// padding/gaps (`tight`) so the header/footer/body always fit.
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
    // Active competition (if the running stage belongs to one) gives context
    // in the header: event name + category.
    final competition = ref.watch(activeCompetitionProvider);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, c) {
          // Drop the control labels (icon-only `compact`) whenever the labelled
          // row would not fit: on narrow windows, on short top-bar zones (phone
          // landscape / large system insets), or once accessibility text scale
          // outgrows a phone-width window. The high-text-scale guard fires only
          // above 1.4× AND below 480 px wide — it leaves the 448 px device at its
          // real 1.15 and the 400 px integration window at 1.15 with full labels
          // (START stays findable), while keeping a phone-width bar at 1.5–2×
          // text from overflowing the labels off the right edge (a 448 px bar
          // overflows by ~3 px at 1.5×). Wider windows keep labels at any scale.
          final textScale = MediaQuery.textScalerOf(context).scale(1.0);
          final compact = c.maxWidth < 360 ||
              c.maxHeight < _kCompactHeight ||
              (textScale > 1.4 && c.maxWidth < 480);
          // A short zone also gets tighter card padding/gaps so the fixed
          // header + footer + body always fit (phone landscape, big insets).
          final tight = c.maxHeight < _kTightHeight;

          return _topBarCard(
            tight: tight,
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
            body: _CardBody(elapsed: elapsed),
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
    final paused = status == StageStatus.paused;
    // Config is editable only when idle/completed (not mid-run or paused).
    final configLocked = inProgress || paused;
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
              configLocked ? null : () => showStageConfigSheet(context, ref),
        ),
        SizedBox(width: gap),
        if (inProgress)
          ControlButton(
            icon: Icons.pause,
            label: 'PAUZĂ',
            color: context.colors.warn,
            onTap: ref.read(stageControllerProvider.notifier).pauseStage,
            compact: compact,
          )
        else if (paused)
          ControlButton(
            icon: Icons.play_arrow,
            label: 'CONTINUĂ',
            color: context.colors.startFill,
            onTap: ref.read(stageControllerProvider.notifier).resumeStage,
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
        // STOP finalizes from both in-progress and paused; hidden while idle
        // (use RESET to clear) and completed (already finalized).
        if (inProgress || paused)
          ControlButton(
            icon: Icons.stop,
            label: 'STOP',
            color: context.colors.stopFill,
            onTap: ref.read(stageControllerProvider.notifier).stopStage,
            compact: compact,
          )
        else
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

/// Top-bar zone height (after subtracting the LED strip) below which the
/// labelled control buttons wouldn't fit and we drop to icon-only + tighten
/// the card padding. Phone landscape and big system insets land here.
const double _kTightHeight = 160;
/// Zone height below which the footer must be icon-only even if labelled
/// buttons would otherwise fit vertically (the row gets too short to read).
const double _kCompactHeight = 140;

/// The rounded surface card: header on top, body centered in the remaining
/// space, footer at the bottom. When [tight] (short zone), the outer/card
/// padding and the inter-section gaps shrink so the fixed header + footer +
/// body always fit without overflow.
Widget _topBarCard({
  required Widget header,
  required Widget body,
  required Widget footer,
  bool tight = false,
}) {
  final gap = tight ? 4.0 : 8.0;
  return Padding(
    padding: tight
        ? const EdgeInsets.fromLTRB(4, 4, 4, 2)
        : const EdgeInsets.fromLTRB(8, 8, 8, 4),
    child: SurfaceCard(
      radius: RetrometerRadii.card,
      padding: tight
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          header,
          SizedBox(height: gap),
          Expanded(child: Center(child: body)),
          SizedBox(height: gap),
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

/// Body: the stage elapsed time. The locality now lives in the Δ indicator's
/// header (left zone) so this slot can give the elapsed readout the full space.
class _CardBody extends StatelessWidget {
  const _CardBody({required this.elapsed});

  final int elapsed;

  @override
  Widget build(BuildContext context) {
    // The body slot (Expanded in _topBarCard) can be short in landscape, where
    // the top bar zone is ~25% of the screen height and the body slot ends up
    // only ~36px tall. FittedBox(scaleDown) lays out the elapsed text at natural
    // size and then shrinks it to fit, so it never overflows; in portrait where
    // the slot is roomy it stays at natural size and remains prominent.
    return ShrinkToFit(
      child: Text(
        formatElapsed(elapsed),
        style: context.text.topBarElapsed,
      ),
    );
  }
}

