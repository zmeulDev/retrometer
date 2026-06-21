# TODO — auto-start not firing on real device

Status: diagnosed on Nothing A059 (Android 16) on 2026-06-21. **Fix applied**
(last-known-first acquisition + mid-tick `ref.read` gotcha repaired) on
2026-06-21; `flutter analyze` 0 issues, `competition_providers_test.dart`
11/11 (incl. 3 new tests). Pending real-life road verification on the A059
before reverting the `[autostart]` debug logging.

## Done 2026-06-21 — auto-start: timp SAU locație, cu dialog de confirmare

Auto-start now triggers when **either** condition is met — time **or**
location — and either piece can be missing (time-only, location-only, both,
or neither). Instead of silently starting, it surfaces a confirmation dialog
("Doriți să porniți X?"); "Nu" snoozes 5 min, "Da" confirms (after the
location disclosure). When both are set, each triggers independently (time OR
location). `flutter analyze` 0 issues; `competition_providers_test.dart`
20/20 (incl. OR + snooze tests); `flutter test` 48 pass / 3 pre-existing
`widget_test.dart` failures (identical on clean `main`). Pending road
verification on the A059.

Files: `lib/models.dart` (nullable `startTime`/`latitude`/`longitude` on
`PlannedStage` — one-way migration, don't downgrade), `lib/widgets/
form_fields.dart` (`formatDateTime`/`DateTimeField` nullable + clear button),
`lib/competition/stage_editor.dart` (nullable draft + soft warning),
`lib/competition_providers.dart` (`AutoStartStatus.pendingPrompt`,
`AutoStartMonitor` 2-pass tick — time pass needs no GPS, location pass does;
`snooze` map + `now` clock thunk; `confirmPending`/`dismissPending`),
`lib/cockpit/auto_start_prompt_listener.dart` (new, dialog via
`ref.listenManual`), `lib/cockpit_view.dart` (Stack overlay,
`StackFit.expand`), `lib/competition/competition_detail_view.dart`
(null-safe sort + display), `test/competition_providers_test.dart`.

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
  → DONE. Named `getCurrentPosition` (matches the geolocator 13.x API; the
  `getPosition` name in the sketch above doesn't exist in 13.x).
- Fake them in `_FakeGpsService` (`test/competition_providers_test.dart`).
  → DONE.
- Rewrite the fix-collection block in `_tickInner` to use the above. → DONE.
- Add a test for the grace-window "missed" case (stage > 10 min in the past does
  not fire) — previously untested. → DONE, plus two more: getCurrentPosition
  fallback fires, and no-fix-abort reports the "nu am primit fix GPS" diagnostic.

While rewriting the fix block, a **pre-existing** bug surfaced: `_tickInner` did
`ref.read(stageControllerProvider)` *after* `startStageFromPlan` flipped the
stage status — the monitor watches that status, so its `ref` is invalidated
mid-tick and Riverpod's `!_didChangeDependency` assertion fired (the gotcha
documented in handoff.md line 81, but the original fix was incomplete — the
two post-acquisition `ref.read`s were never converted). This made the existing
"fires when due" test fail on a clean `main`. Fixed by reading the status via
`stageController.telemetry` (the notifier's own `state` getter, captured up
front at the top of `_tickInner`) instead of `ref.read` at both mid-loop sites.
No `ref` involved → no assertion.

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

## TODO — telemetrie viteză per stagiu (afisare + captură max/min/avg)

Status: neînceput (2026-06-22). Două părți: (A) afișare live în cockpit a
vitezei medii țintă vs vitezei medii reale pe stagiu; (B) la finalul
stagiu-lui, salvare cu detalii care captează viteza maximă, minimă și medie
(reală). Persistate în `retrometer.competitions` ca parte a `PlannedStage`
(câmp nou `StageResult?` sau câmpuri plate).

### Context (unde trăiesc lucrurile azi)

- `StageConfig`/`PlannedStage` au deja `targetAvgSpeed` (km/h) — ținta
  imposă ideal-time. `PlannedStage.maxSpeedLimit` e limita hard (over-speed
  alert). NU există viteză reală medie, max sau min capturate.
- `StageTelemetry` (`lib/models.dart`, freezed) = live: `startTime`,
  `currentDistance` (km), `currentSpeed` (km/h), `status`, `lat`/`lng`.
  **Doar instant, nicio agregare** (max/min/avg).
- Acumularea distanței/vitezei se face în `StageController._subscribeGps`
  (`lib/state_providers.dart:93`) — la fiecare fix GPS: `addedMetres` (din
  `distanceBetween`), `speedKmh` (din `pos.speed*3.6` sau `addedMetres/dt`).
  Aici e locul natural pentru a actualiza max/min/sumă(viteze)/count pentru
  medie.
- `elapsedSecondsProvider` (`state_providers.dart:207`) = elapsed wall-clock
  din `startTime`. Viteza medie reală = `currentDistance_km / elapsed_h`.
- `StageController.stopStage` / `resetStage` — unde se finalizează stagiu-l;
  aici s-ar persista rezultatul în `PlannedStage`.

### (A) Afișare: viteză medie țintă vs viteză medie reală

- Pe stagiu (cockpit, probabil în `DeltaIndicator` sau o linie sub el):
  afișează `țintă {targetAvgSpeed}` (deja există ca „țintă X" în
  `DeltaIndicator` per handoff) + `reală {avgReal}` unde
  `avgReal = currentDistance / max(elapsed_h, eps)`.
- Provider nou `actualAvgSpeedProvider` în `state_providers.dart` (combinație
  `select` pe `currentDistance` + `elapsedSeconds`), pe lângă cei existenți
  (`isOverSpeed`, `deltaBand`, etc.).
- Cazuri de margine: `elapsed == 0` → `—` (împărțire la zero); `distance == 0`
  → `—` sau `0.0`; afișare consistentă cu `_fmtSpeed` existent.
- Atenție la `select` îngust ca să nu refolosească rebuild-uri (pattern-ul
  existent cu `RepaintBoundary`).

### (B) Captură + salvare: max / min / avg viteză per stagiu

1. **Model** (`lib/models.dart`):
   - Adaugă pe `StageTelemetry` (sau un `StageSpeedStats` separat, păstrat în
     `telemetry`): `maxSpeedKmh`, `minSpeedKmh` (null până la primul fix),
     `_speedSumKmh`, `_speedFixCount` (pentru medie; sau recompute din
     `currentDistance`/`elapsed` la final — mai simplu și fără float drift).
   - Adaugă `StageResult` (freezed): `maxSpeedKmh`, `minSpeedKmh`,
     `avgSpeedKmh`, `totalDistanceKm` (din telemetrie), `elapsedSeconds`,
     `completedAt`. Nullable pe `PlannedStage` (`StageResult? result`) — null
     cât stagiu-l nu s-a terminat.
   - `toJson` manual pe `PlannedStage` + `plannedStageFromJson` cu fallback la
     null (one-way migration, la fel ca `startTime`/coords — NU downgrada după
     salvare; reader-ul nou face `as num?`).
   - Regenerează `models.freezed.dart` (`dart run build_runner build
     --delete-conflicting-outputs`).
2. **Agregare live** (`state_providers.dart` `_subscribeGps`): la fiecare fix,
   după `speedKmh` calculat, actualizează `maxSpeedKmh = max(cur, speedKmh)`,
   `minSpeedKmh = min(cur ?? +inf, speedKmh)`. Ignoră `speedKmh == 0` pentru
   min dacă vrem min real în mișcare (sau nu — decide cu crew-ul; 0 la start
   e legitim). `select` îngust dacă se afișează live (altfel doar la final).
3. **Salvare la final** (`StageController.stopStage`): construiește
   `StageResult` din `telemetry` (`maxSpeedKmh`, `minSpeedKmh`,
   `avgSpeedKmh = currentDistance / elapsed_h`, `totalDistanceKm =
   currentDistance`, `elapsedSeconds`, `completedAt = now`) și persistă-l pe
   `PlannedStage` via `competitionsProvider` (CRUD nou `markResult(compId,
   stageId, result)` sau extinde `markStarted`). Atenție la gotcha-ul
   `!_didChangeDependency` de la auto-start: rezolvă deps up-front înainte
   de await (competitionsProvider.notifier), nu `ref.read` mid-await.
4. **UI**: pe detaliul competiției (`competition_detail_view.dart` `_StageTile`),
   dacă `stage.result != null` afișează un `InfoLine` „rezultat: max X / min Y
   / med Z km/h" (sau un card de rezultat). Pe cockpit, după stop, un
   summary scurt (opțional).
5. **Teste** (`competition_providers_test.dart` / `state_providers_test.dart`):
   - `stopStage` populează `result` cu max/min/avg din telemetria fake
     (_FakeGpsService feed cu viteze cunoscute).
   - Round-trip JSON `StageResult` (salvare + reload păstrează valorile;
     payload fără `result` (vechi) se încarcă cu `result=null`).
   - Caz `elapsed == 0` (stop imediat) → `avgSpeedKmh = 0` sau null (decide).

### Note

- Viteza medie reală = distanță totală / timp total (nu media aritmetică a
  vitezelor instant — asta e corect fizic și evită drift float). max/min rămân
  instantanee din stream.
- Dacă crew-ul ajustează distanța blind-touch (`adjustDistance`), asta
  schimbă `currentDistance` → influențează `avgSpeedKmh`. Decide dacă
  ajustarea contă sau nu pentru rezultat (probabil da — e distanța
  „oficială" a stagiu-lui).
- `pos.speed` poate fi NaN/-1 (fallback la `addedMetres/dt`) — deja handlat
  în `_subscribeGps`; max/min folosește `speedKmh` deja rezolvat.