import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'competition_providers.dart';
import 'competition_view.dart';
import 'guide_view.dart';
import 'models.dart';
import 'state_providers.dart';
import 'theme/retrometer_theme.dart';

/// Main cockpit screen: a 3-zone column (info / Δ indicator / trip-meter +
/// blind-touch gestures). Each zone is an independent `Consumer` that watches
/// only the slice of state it needs, and the two hot zones are wrapped in
/// `RepaintBoundary` so frequent changes don't repaint the rest of the screen.
class CockpitView extends StatefulWidget {
  const CockpitView({super.key});

  @override
  State<CockpitView> createState() => _CockpitViewState();
}

class _CockpitViewState extends State<CockpitView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => maybeShowOnboarding(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(flex: 15, child: _TopInfoBar()),
            Expanded(flex: 45, child: _DeltaIndicator()),
            Expanded(flex: 40, child: _TripmeterBar()),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top zone (15%): stage name + elapsed + controls.
// ---------------------------------------------------------------------------

/// Rounded surface panel that holds the top-bar content, lifted slightly off
/// the scaffold background so the bar reads as a header card.
Widget _topBarSurface(double padH, Widget child) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: RetrometerColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RetrometerColors.divider),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH + 4, vertical: 6),
        child: child,
      ),
    ),
  );
}

class _TopInfoBar extends ConsumerWidget {
  const _TopInfoBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the auto-start monitor alive while the cockpit is mounted.
    ref.watch(autoStartMonitorProvider);
    final elapsed = ref.watch(elapsedSecondsProvider);
    final status = ref.watch(
      stageControllerProvider.select((s) => s.telemetry.status),
    );
    final locAsync = ref.watch(localityProvider);
    final locality = locAsync.valueOrNull ??
        (locAsync.isLoading ? '…' : '—');
    // Active competition (if the running stage belongs to one) gives context
    // in the top bar: event name + category.
    final competition = ref.watch(activeCompetitionProvider);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, c) {
          // Narrow screens (phones, split views) have less horizontal room for
          // the whole info + controls row. When there's also enough vertical
          // room (portrait phones), split into two rows so labels stay legible;
          // otherwise fall back to a compact single row (icon-only controls).
          final compact = c.maxWidth < 520;
          final twoRows = compact && c.maxHeight > 100;
          final padH = compact ? 8.0 : 12.0;

          final localityStyle =
              RetrometerTextStyles.topBarText(compact: compact);
          final elapsedStyle =
              RetrometerTextStyles.topBarText(compact: compact);

          Widget localityBlock = Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on,
                        color: RetrometerColors.primary,
                        size: compact ? 16 : 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        locality,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: localityStyle,
                      ),
                    ),
                  ],
                ),
                if (competition != null &&
                    (competition.name.isNotEmpty ||
                        competition.category.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events,
                            color: RetrometerColors.primary, size: 13),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            [
                              if (competition.name.isNotEmpty)
                                competition.name,
                              if (competition.category.isNotEmpty)
                                competition.category,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RetrometerTextStyles.competitionRow,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );

          final elapsedWidget = Text(_formatElapsed(elapsed), style: elapsedStyle);
          final competitionsBtn = IconButton(
            icon: Icon(Icons.event_note,
                color: RetrometerColors.primary, size: compact ? 18 : 20),
            tooltip: 'Competiții',
            constraints: BoxConstraints(
                minHeight: compact ? 30 : 32, minWidth: compact ? 30 : 32),
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CompetitionsScreen(),
              ),
            ),
          );
          final helpBtn = IconButton(
            icon: Icon(Icons.help_outline,
                color: RetrometerColors.textSecondary,
                size: compact ? 18 : 20),
            tooltip: 'Cum se folosește',
            constraints: BoxConstraints(
                minHeight: compact ? 30 : 32, minWidth: compact ? 30 : 32),
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const GuideScreen(),
              ),
            ),
          );

          if (twoRows) {
            return _topBarSurface(
              padH,
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      localityBlock,
                      const SizedBox(width: 8),
                      elapsedWidget,
                      const SizedBox(width: 4),
                      competitionsBtn,
                      helpBtn,
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [_StageControls(status: status, compact: false)],
                  ),
                ],
              ),
            );
          }

          return _topBarSurface(
            padH,
            Row(
              children: [
                localityBlock,
                SizedBox(width: compact ? 6 : 10),
                elapsedWidget,
                SizedBox(width: compact ? 4 : 6),
                competitionsBtn,
                helpBtn,
                SizedBox(width: compact ? 2 : 4),
                _StageControls(status: status, compact: compact),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StageControls extends ConsumerWidget {
  const _StageControls({required this.status, this.compact = false});

  final StageStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inProgress = status == StageStatus.inProgress;
    final gap = compact ? 4.0 : 6.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.settings,
              color: RetrometerColors.textSecondary,
              size: compact ? 18 : 20),
          tooltip: 'Configurare stage',
          constraints: BoxConstraints(
              minHeight: compact ? 30 : 32, minWidth: compact ? 30 : 32),
          padding: EdgeInsets.zero,
          onPressed:
              inProgress ? null : () => _showConfigSheet(context, ref),
        ),
        SizedBox(width: gap),
        if (inProgress)
          _ControlButton(
            icon: Icons.stop,
            label: 'STOP',
            color: RetrometerColors.stopFill,
            onTap: ref.read(stageControllerProvider.notifier).stopStage,
            compact: compact,
          )
        else
          _ControlButton(
            icon: Icons.play_arrow,
            label: 'START',
            color: RetrometerColors.startFill,
            onTap: ref.read(stageControllerProvider.notifier).startStage,
            compact: compact,
          ),
        SizedBox(width: gap),
        _ControlButton(
          icon: Icons.refresh,
          label: 'RESET',
          color: RetrometerColors.resetFill,
          foreground: RetrometerColors.textPrimary,
          onTap: ref.read(stageControllerProvider.notifier).resetStage,
          compact: compact,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
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
    final fg = foreground ?? RetrometerColors.onActionFill;
    // Compact (narrow single-row): icon-only, so the whole top bar fits without
    // overflow on a phone in a short/split-view window.
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(compact ? 10 : 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10, vertical: 6),
          child: compact
              ? Icon(icon, color: fg, size: 18)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: fg, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: RetrometerTextStyles.controlLabel
                          .copyWith(color: fg),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Center zone (45%): the Δ indicator with a clear AVANS / ÎNTÂRZIERE / LA TIMP
// label. Repaint-isolated.
// ---------------------------------------------------------------------------

class _DeltaIndicator extends ConsumerWidget {
  const _DeltaIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final band = ref.watch(deltaBandProvider);
    final delta = ref.watch(deltaSecondsProvider);
    final overSpeed = ref.watch(isOverSpeedProvider);
    final name = ref.watch(
      stageControllerProvider.select((s) => s.config.name),
    );
    final target = ref.watch(
      stageControllerProvider.select((s) => s.config.targetAvgSpeed),
    );
    final speed = ref.watch(
      stageControllerProvider.select((s) => s.telemetry.currentSpeed),
    );

    final Color bgColor;
    final Color fgColor;
    final String label;
    switch (band) {
      case DeltaBand.onTime:
        bgColor = RetrometerColors.onTimeBg;
        fgColor = RetrometerColors.onTimeFg;
        label = 'LA TIMP';
      case DeltaBand.advance: // ahead → red
        bgColor = RetrometerColors.advanceBg;
        fgColor = RetrometerColors.advanceFg;
        label = 'AVANS';
      case DeltaBand.delay: // late → yellow
        bgColor = RetrometerColors.delayBg;
        fgColor = RetrometerColors.delayFg;
        label = 'ÎNTÂRZIERE';
    }

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: fgColor.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: RetrometerTextStyles.bandLabel(fgColor),
                    ),
                    Text(
                      _formatDelta(delta),
                      style: RetrometerTextStyles.deltaNumberColored(fgColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$name   ·   țintă ${_fmtSpeed(target)} / '
                      'viteza ${speed.toStringAsFixed(0)} km/h',
                      style: RetrometerTextStyles.deltaSubtitle,
                    ),
                  ],
                ),
              ),
            ),
            if (overSpeed)
              const Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: _OverSpeedAlert(),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverSpeedAlert extends StatefulWidget {
  const _OverSpeedAlert();

  @override
  State<_OverSpeedAlert> createState() => _OverSpeedAlertState();
}

class _OverSpeedAlertState extends State<_OverSpeedAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red, width: 1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
        alignment: Alignment.center,
        child: const Text(
          '⚠ OVER SPEED',
          style: RetrometerTextStyles.overSpeed,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom zone (40%): trip-meter + visible blind-touch adjust buttons.
// ---------------------------------------------------------------------------

class _TripmeterBar extends ConsumerWidget {
  const _TripmeterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(stageControllerProvider.notifier);
    return ColoredBox(
      color: RetrometerColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Row(
          children: [
            Expanded(
              flex: 30,
              child: _AdjustZone(
                sign: '−',
                onTap: () => controller.adjustDistance(-0.01),
                onLongPress: () => controller.adjustDistance(-0.1),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              flex: 40,
              child: RepaintBoundary(child: _DistanceReadout()),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 30,
              child: _AdjustZone(
                sign: '+',
                onTap: () => controller.adjustDistance(0.01),
                onLongPress: () => controller.adjustDistance(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustZone extends StatelessWidget {
  const _AdjustZone({
    required this.sign,
    required this.onTap,
    required this.onLongPress,
  });

  final String sign;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: RetrometerColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: RetrometerColors.divider),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sign,
                style: RetrometerTextStyles.adjustSign,
              ),
              const SizedBox(height: 2),
              const Text(
                '10 m',
                style: RetrometerTextStyles.adjustAmount,
              ),
              const Text(
                'lung: 100 m',
                style: RetrometerTextStyles.adjustLong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistanceReadout extends ConsumerWidget {
  const _DistanceReadout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distance = ref.watch(
      stageControllerProvider.select((s) => s.telemetry.currentDistance),
    );
    return Container(
      decoration: BoxDecoration(
        color: RetrometerColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RetrometerColors.primary.withValues(alpha: 0.3),
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              distance.toStringAsFixed(2),
              style: RetrometerTextStyles.distanceNumber,
            ),
            const Text(
              'km',
              style: RetrometerTextStyles.distanceUnit,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Config sheet.
// ---------------------------------------------------------------------------

Future<void> _showConfigSheet(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(stageControllerProvider.notifier);
  final current = ref.read(stageControllerProvider).config;

  final nameCtrl = TextEditingController(text: current.name);
  var target = current.targetAvgSpeed;
  var maxLimit = current.maxSpeedLimit;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Configurare stage',
              style: RetrometerTextStyles.sheetTitle,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: RetrometerColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Nume'),
            ),
            const SizedBox(height: 16),
            _NumberField(
              label: 'Viteză medie țintă (km/h)',
              value: target,
              decimals: 1,
              onChanged: (v) => setState(() => target = v),
            ),
            const SizedBox(height: 16),
            _NumberField(
              label: 'Limită maximă (km/h)',
              value: maxLimit,
              decimals: 1,
              onChanged: (v) => setState(() => maxLimit = v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                // copyWith preserves the finish geofence / auto-stop /
                // distance / allocated-time fields the sheet doesn't edit, so
                // opening the gear no longer silently drops them.
                controller.updateConfig(
                  current.copyWith(
                    name: nameCtrl.text.trim().isEmpty
                        ? current.name
                        : nameCtrl.text.trim(),
                    targetAvgSpeed: target,
                    maxSpeedLimit: maxLimit,
                  ),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.decimals = 0,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final int decimals;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.value.toStringAsFixed(widget.decimals));
  }

  @override
  void dispose() {
    _controller.dispose();
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
          child: Text(widget.label, style: RetrometerTextStyles.fieldLabel),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            controller: _controller,
            keyboardType: widget.decimals > 0
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            textAlign: TextAlign.center,
            style: RetrometerTextStyles.fieldInput,
            inputFormatters: [formatter],
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

// ---------------------------------------------------------------------------
// Formatting helpers.
// ---------------------------------------------------------------------------

String _formatElapsed(int totalSeconds) {
  final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _formatDelta(double delta) {
  final sign = delta < 0 ? '-' : '+';
  return '$sign ${delta.abs().toStringAsFixed(1)}';
}

/// Speed display: whole numbers without a decimal (40), fractional with one
/// (35.9) — so a target average entered as 35.9 shows as 35.9, not 36.
String _fmtSpeed(double v) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);