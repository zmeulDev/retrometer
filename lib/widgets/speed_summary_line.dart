import 'package:flutter/material.dart';

import '../theme/retrometer_theme.dart';
import '../utils/formatting.dart';

/// A single-line summary of a stage run's speed stats:
/// `max {fmtSpeed(max)} / min {—|fmtSpeed(min)} / med {fmtSpeed(avg)} km/h`.
///
/// Renders as a bare [Text] in [RetrometerTextStyles.metaMuted] (overridable
/// via [style]). Extracted because the exact same string + style was built
/// inline in multiple tiles. Only the bare-text shape lives here — variants
/// that add a prefix (e.g. `rezultat: ...`) or an icon are left inline.
class SpeedSummaryLine extends StatelessWidget {
  const SpeedSummaryLine({
    super.key,
    required this.maxSpeedKmh,
    this.minSpeedKmh,
    required this.avgSpeedKmh,
    this.style = RetrometerTextStyles.metaMuted,
  });

  final double maxSpeedKmh;
  final double? minSpeedKmh;
  final double avgSpeedKmh;

  /// Defaults to [RetrometerTextStyles.metaMuted].
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      'max ${fmtSpeed(maxSpeedKmh)} / '
      'min ${minSpeedKmh == null ? '—' : fmtSpeed(minSpeedKmh!)} / '
      'med ${fmtSpeed(avgSpeedKmh)} km/h',
      style: style,
    );
  }
}