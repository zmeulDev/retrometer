import 'models.dart';

/// Ideal elapsed time for [distanceKm] at [targetKmh], in **seconds**.
///
/// `t_ideal = distance / speed` yields hours; × 3600 → seconds. Returns 0
/// when the target speed is non-positive (avoids division by zero).
double idealSeconds({required double distanceKm, required double targetKmh}) {
  if (targetKmh <= 0) return 0.0;
  return (distanceKm / targetKmh) * 3600.0;
}

/// The Δ indicator in **seconds**: `t_real - t_ideal`, where `t_real` is the
/// wall-clock elapsed time since [start] (millisecond resolution).
double deltaSeconds({
  required DateTime start,
  required DateTime now,
  required double distanceKm,
  required double targetKmh,
}) {
  final tReal = now.difference(start).inMilliseconds / 1000.0;
  return tReal - idealSeconds(distanceKm: distanceKm, targetKmh: targetKmh);
}

/// Colour band for a given Δ (±1 s tolerance around zero).
DeltaBand deltaBandFor(double delta) {
  if (delta.abs() <= 1.0) return DeltaBand.onTime;
  return delta < 0 ? DeltaBand.advance : DeltaBand.delay;
}