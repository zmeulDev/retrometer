import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/retrometer_theme.dart';
import '../utils/formatting.dart';
import '../widgets/cards.dart';
import '../widgets/form_fields.dart';
import '../widgets/info_widgets.dart';
import '../widgets/speed_summary_line.dart';

// ---------------------------------------------------------------------------
// Stage run executive overview.
// ---------------------------------------------------------------------------

/// A read-only executive dashboard for a single finished stage run
/// ([StageRunHistory]). Reached by tapping a history entry in the competition
/// detail screen. Shows the prominent speed/distance/time stats, a comparison
/// against the planned targets (highlighting over-speed), and the start/finish
/// coordinate pairs when available.
///
/// Takes only [entry]: the per-run snapshot already carries everything needed
/// (stage name, competition name, planned targets, real stats, coords), so the
/// "alte rulări ale stagiului" nice-to-have is intentionally skipped to keep the
/// constructor minimal.
class StageRunOverviewScreen extends StatelessWidget {
  const StageRunOverviewScreen({super.key, required this.entry});

  final StageRunHistory entry;

  @override
  Widget build(BuildContext context) {
    final overSpeed = entry.maxSpeedLimit > 0 &&
        entry.maxSpeedKmh > entry.maxSpeedLimit;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.stageName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (entry.competitionName.isNotEmpty)
              Text(
                entry.competitionName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.meta.copyWith(color: context.colors.primary),
              ),
          ],
        ),
        actions: [
          if (overSpeed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RetrometerSpacing.s12),
              child: StatusPill(text: 'PESTE LIMITĂ', color: context.colors.danger),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          RetrometerSpacing.s16,
          RetrometerSpacing.s16,
          RetrometerSpacing.s16,
          RetrometerSpacing.s32,
        ),
        children: [
          // Interval: startedAt → completedAt.
          SurfaceCard(
            color: context.colors.surfaceElevated,
            padding: const EdgeInsets.symmetric(
              horizontal: RetrometerSpacing.s16,
              vertical: RetrometerSpacing.s12,
            ),
            child: InfoLine(
              icon: Icons.schedule,
              iconColor: context.colors.primary,
              text:
                  '${formatDateTime(entry.startedAt)} → ${formatDateTime(entry.completedAt)}',
              textStyle: context.text.metaStrong,
            ),
          ),
          const SizedBox(height: RetrometerSpacing.s12),

          // Prominent speed stats.
          _StatCard(
            label: 'Viteze',
            value: SpeedSummaryLine(
              maxSpeedKmh: entry.maxSpeedKmh,
              minSpeedKmh: entry.minSpeedKmh,
              avgSpeedKmh: entry.avgSpeedKmh,
              style: context.text.metaStrong,
            ),
          ),
          const SizedBox(height: RetrometerSpacing.s12),

          // Distance + elapsed.
          _StatRow(
            left: _StatCard(
              label: 'Distanță',
              value: Text(
                '${entry.totalDistanceKm.toStringAsFixed(2)} km',
                style: context.text.metaStrong,
              ),
            ),
            right: _StatCard(
              label: 'Timp',
              value: Text(
                formatElapsed(entry.elapsedSeconds),
                style: context.text.metaStrong,
              ),
            ),
          ),
          const SizedBox(height: RetrometerSpacing.s16),

          // Comparison: target vs real.
          Text('Comparativ țintă', style: context.text.sectionLabel),
          const SizedBox(height: RetrometerSpacing.s8),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(
              horizontal: RetrometerSpacing.s16,
              vertical: RetrometerSpacing.s12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ComparisonRow(
                  label: 'Viteză medie',
                  target: '${fmtSpeed(entry.targetAvgSpeed)} km/h',
                  real: '${fmtSpeed(entry.avgSpeedKmh)} km/h',
                ),
                const Divider(),
                _ComparisonRow(
                  label: 'Viteză maximă',
                  target: '${fmtSpeed(entry.maxSpeedLimit)} km/h',
                  real: '${fmtSpeed(entry.maxSpeedKmh)} km/h',
                  realColor: overSpeed ? context.colors.danger : null,
                ),
              ],
            ),
          ),

          // Coordinates (only when non-null).
          if (entry.startLatitude != null &&
              entry.startLongitude != null) ...[
            const SizedBox(height: RetrometerSpacing.s16),
            Text('Start', style: context.text.sectionLabel),
            const SizedBox(height: RetrometerSpacing.s8),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(
                horizontal: RetrometerSpacing.s16,
                vertical: RetrometerSpacing.s12,
              ),
              child: InfoLine(
                icon: Icons.location_on,
                text: fmtCoordPair(
                  entry.startLatitude,
                  entry.startLongitude,
                ),
              ),
            ),
          ],
          if (entry.endLatitude != null && entry.endLongitude != null) ...[
            const SizedBox(height: RetrometerSpacing.s16),
            Text('Sosire', style: context.text.sectionLabel),
            const SizedBox(height: RetrometerSpacing.s8),
            SurfaceCard(
              padding: const EdgeInsets.symmetric(
                horizontal: RetrometerSpacing.s16,
                vertical: RetrometerSpacing.s12,
              ),
              child: InfoLine(
                icon: Icons.flag,
                text: fmtCoordPair(entry.endLatitude, entry.endLongitude),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------

/// A labelled stat card: a small uppercase label above a value widget. Used
/// for the prominent dashboard tiles (speeds, distance, time).
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: RetrometerSpacing.s16,
        vertical: RetrometerSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: context.text.badge.copyWith(
            color: context.colors.textTertiary,
          )),
          const SizedBox(height: 4),
          DefaultTextStyle(
            style: context.text.metaStrong,
            child: value,
          ),
        ],
      ),
    );
  }
}

/// Two [_StatCard]s side by side, equal width.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: RetrometerSpacing.s12),
          Expanded(child: right),
        ],
      ),
    );
  }
}

/// A `label · țintă X · real Y` comparison row. [realColor] tints the real
/// value (e.g. danger red when over the limit).
class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.target,
    required this.real,
    this.realColor,
  });

  final String label;
  final String target;
  final String real;
  final Color? realColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: context.text.meta),
        ),
        Expanded(
          child: Text(
            'țintă $target',
            style: context.text.meta,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: RetrometerSpacing.s12),
        Expanded(
          child: Text(
            'real $real',
            textAlign: TextAlign.right,
            style: context.text.metaStrong.copyWith(
              color: realColor ?? context.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}