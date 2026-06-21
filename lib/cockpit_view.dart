import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'competition_providers.dart';
import 'competition_view.dart';
import 'guide_view.dart';
import 'models.dart';
import 'state_providers.dart';

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
      backgroundColor: Colors.black,
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

          final localityStyle = TextStyle(
            color: Colors.white,
            fontSize: compact ? 15 : 18,
            fontWeight: FontWeight.bold,
          );
          final elapsedStyle = TextStyle(
            color: Colors.white,
            fontSize: compact ? 15 : 18,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          );

          Widget localityBlock = Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on,
                        color: Colors.greenAccent, size: compact ? 16 : 18),
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
                            color: Colors.greenAccent, size: 13),
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
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 13,
                            ),
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
                color: Colors.greenAccent, size: compact ? 18 : 20),
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
                color: Colors.white70, size: compact ? 18 : 20),
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
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: 2),
              child: Column(
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

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: 4),
            child: Row(
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
              color: Colors.white70, size: compact ? 18 : 20),
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
            color: Colors.red,
            onTap: ref.read(stageControllerProvider.notifier).stopStage,
            compact: compact,
          )
        else
          _ControlButton(
            icon: Icons.play_arrow,
            label: 'START',
            color: Colors.green,
            onTap: ref.read(stageControllerProvider.notifier).startStage,
            compact: compact,
          ),
        SizedBox(width: gap),
        _ControlButton(
          icon: Icons.refresh,
          label: 'RESET',
          color: Colors.white24,
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
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Compact (narrow single-row): icon-only, so the whole top bar fits without
    // overflow on a phone in a short/split-view window.
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(compact ? 6 : 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10, vertical: 6),
          child: compact
              ? Icon(icon, color: Colors.black, size: 18)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.black, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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
        bgColor = const Color(0xFF1B5E20);
        fgColor = Colors.greenAccent;
        label = 'LA TIMP';
      case DeltaBand.advance: // ahead → red
        bgColor = const Color(0xFFB71C1C);
        fgColor = Colors.redAccent;
        label = 'AVANS';
      case DeltaBand.delay: // late → yellow
        bgColor = const Color(0xFFF57F17);
        fgColor = Colors.yellowAccent;
        label = 'ÎNTÂRZIERE';
    }

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: bgColor,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  Text(
                    _formatDelta(delta),
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 180,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$name   ·   țintă ${_fmtSpeed(target)} / '
                    'viteza ${speed.toStringAsFixed(0)} km/h',
                    style: const TextStyle(color: Colors.white70, fontSize: 22),
                  ),
                ],
              ),
            ),
          ),
          if (overSpeed)
            const Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: _OverSpeedAlert(),
            ),
        ],
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
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: const Text(
          '⚠ OVER SPEED',
          style: TextStyle(
            color: Colors.red,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
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
      color: Colors.black,
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
          const Expanded(
            flex: 40,
            child: RepaintBoundary(child: _DistanceReadout()),
          ),
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
          color: const Color(0xFF1A1A1A),
          border: Border(
            left: sign == '+'
                ? const BorderSide(color: Colors.white12, width: 1)
                : BorderSide.none,
            right: sign == '−'
                ? const BorderSide(color: Colors.white12, width: 1)
                : BorderSide.none,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sign,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '10 m',
                style: TextStyle(color: Colors.white70, fontSize: 20),
              ),
              const Text(
                'lung: 100 m',
                style: TextStyle(color: Colors.white38, fontSize: 13),
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
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              distance.toStringAsFixed(2),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 120,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
                height: 1,
              ),
            ),
            const Text(
              'km',
              style: TextStyle(color: Colors.white54, fontSize: 28),
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
    backgroundColor: Colors.grey[900],
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Configurare stage',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nume',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
              ),
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