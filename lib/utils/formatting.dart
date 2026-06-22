// Shared, pure formatting helpers used across the cockpit, competition and
// misc views. Kept here so a single source of truth formats speeds, durations,
// coordinates and ids — no per-file `_fmtSpeed`/`_fmtMmSs`/`two` duplicates.

/// Zero-pad an integer to two digits: `5` → `"05"`.
String two(int n) => n.toString().padLeft(2, '0');

/// Speed display: whole numbers without a decimal (`40`), fractional with one
/// (`35.9`) — so a target average entered as 35.9 shows as 35.9, not 36.
String fmtSpeed(double v) =>
    v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// Elapsed seconds as `MM:SS` (clamped to non-negative input).
String formatElapsed(int totalSeconds) {
  final t = totalSeconds < 0 ? 0 : totalSeconds;
  return '${two(t ~/ 60)}:${two(t % 60)}';
}

/// Coordinate to a fixed-`digits` string (default 5).
String fmtCoord(double v, {int digits = 5}) => v.toStringAsFixed(digits);

/// Nullable coordinate: empty string when null (for text fields), else
/// [fmtCoord]. Use [fmtCoordPair] for display rows that want `—`.
String fmtCoordNullable(double? v, {int digits = 5}) =>
    v == null ? '' : v.toStringAsFixed(digits);

/// Display a coordinate pair as `lat, lng`, optionally with the geofence
/// radius appended as `(±r m)`. Returns `—`-ish [fallback] when either
/// coordinate is null (default `'fără locație'`).
String fmtCoordPair(
  double? lat,
  double? lng, {
  double? radiusM,
  int digits = 5,
  String fallback = 'fără locație',
}) {
  if (lat == null || lng == null) return fallback;
  final base = '${lat.toStringAsFixed(digits)}, ${lng.toStringAsFixed(digits)}';
  if (radiusM == null) return base;
  return '$base (±${radiusM.toStringAsFixed(0)} m)';
}

/// `HH:mm` for a [DateTime], or `—` when null. Used by the auto-start
/// diagnostics bar.
String formatTime(DateTime? dt) {
  if (dt == null) return '—';
  return '${two(dt.hour)}:${two(dt.minute)}';
}

/// Generates an id of the form `"<prefix>-<epoch-millis>"`.
String newId(String prefix) => '$prefix-${DateTime.now().millisecondsSinceEpoch}';

/// Rounds a [DateTime] down to the start of its minute (drops seconds/ms).
DateTime roundToMinute(DateTime dt) =>
    DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);