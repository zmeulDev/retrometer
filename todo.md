# TODO — auto-start not firing on real device

Status: diagnosed on Nothing A059 (Android 16) on 2026-06-21. Pending real-life
road testing before applying a fix.

## Symptom

A planned stage with `autoStart=true`, a valid `startTime`, start coords, and
`geofenceRadiusM` set never auto-starts, even though the time window has arrived
and the crew is at the start location.

## Root cause (confirmed via on-device debug logs)

`AutoStartMonitor._tickInner` (`lib/competition_providers.dart`) opens a **fresh**
`Geolocator.getPositionStream(high, distanceFilter: 0)` on every 5 s tick,
listens for ≤12 s, keeps the most accurate fix, then lets the stream close.

On the A059 this fresh stream emits **zero fixes within 12 s**, every tick, for
the whole session. So `best` stays `null` → "no GPS fix collected within 12s" →
the tick aborts **before the geofence distance check is ever reached**. The time
condition, `autoStart`, `started`, permission, and grace window all pass; the
**only** failing gate is GPS fix acquisition.

Likely reason: the device is stationary (and possibly indoors). Android's
FusedLocationProvider throttles `getPositionStream` updates when the position
isn't changing, and a fresh high-accuracy subscription pays a cold-start tax
each tick. The cockpit's long-lived low-accuracy `positionProvider` keeps a
recent fix in the OS last-known cache, but the monitor ignores it and opens a
competing ephemeral stream that yields nothing.

### Evidence (from `flutter run -d A059`, `[autostart]` trace logging)

```
[autostart] tick now=2026-06-21 19:31:01 stages=1
[autostart]   stage "dgh" autoStart=true started=false startTime=19:25:00 delta=361s (past) graceOk=true lat=46.84 lng=23.76 radius=500m
[autostart] checkPermission=LocationPermission.whileInUse
[autostart] no GPS fix collected within 12s — abort tick
```

Repeats identically every tick (19:31 → 19:32, 6+ ticks, 2+ min).

## Compounding factor — grace window burns while GPS fails

`_autoStartGraceWindow = 10 min`. While the monitor fails to acquire a fix, the
clock keeps moving. Once `now - startTime > 10 min`, `graceOk` flips false and
the stage is treated as "missed" — it will **never** auto-start even if GPS
recovers. So the GPS acquisition failure silently consumes the entire grace
window. On the captured run, `dgh` (start 19:25) was ~2.7 min from being
permanently missed.

## Proposed fix

Replace the ephemeral 12 s stream-collect with a one-shot acquisition that uses
the OS last-known position first (instant, fine for a 500 m geofence), falling
back to `getPosition(timeLimit)` only if last-known is missing or stale:

```dart
Position? best = await gps.getLastKnownPosition();
if (best == null ||
    now.difference(best.timestamp) > const Duration(minutes: 5)) {
  best = await gps.getPosition(timeLimit: const Duration(seconds: 15));
}
```

Work needed:
- Add `getLastKnownPosition()` and `getPosition({timeLimit})` to `GpsService`
  (abstract) + `GeolocatorGpsService` impl (`lib/services/gps_service.dart`).
- Fake them in `_FakeGpsService` (`test/competition_providers_test.dart`).
- Rewrite the fix-collection block in `_tickInner` to use the above.
- Add a test for the grace-window "missed" case (stage > 10 min in the past does
  not fire) — currently untested.

Optional design revisit (separate from the bug):
- `_autoStartGraceWindow` (10 min) may be too tight for regularity rallying
  where small delays are normal; being inside the geofence already proves the
  crew is at the start. Consider relaxing or making it location-gated.
- `_autoStartAwakeHorizon` (24 h) holds the wakelock — and thus keeps the screen
  on — for up to 24 h before a stage. Heavy battery cost; a short horizon
  (10–15 min before `startTime`) would cover the firing window at far lower cost.

## Repro / verification on the road

The `[autostart]` trace logging is currently in `lib/competition_providers.dart`
(prints per-stage conditions, permission, fix accuracy, distance vs radius, and
the fire/abort decision each tick). To verify on the road:

```
flutter run -d A059 --debug
```

Watch the console for `[autostart]` lines. With the fix applied, expect to see
`fix lat=... lng=... accuracy=...m` followed by `due "..." distance=...m vs
radius=...m inGeofence=true` and `FIRING startStageFromPlan`.

After the fix is confirmed, revert the `[autostart]` debug logging.