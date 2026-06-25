# DeltaIndicator UI refactor — stage name la footer, rând viteze dedesubt

Mockup aprobat: `design/delta-indicator.html`. Layout nou (top→bottom în zona Δ):
band label → Δ number (hero) → spacer → **stage name (footer)** → **speed row** (ȚINTĂ | REALĂ | ACUM) dedesubt.

## Plan

- [x] **1. Refactor `lib/cockpit/cockpit_delta_indicator.dart`**
  - Reordează `Column`-ul central: `bandLabel` → `Δ number` → `Expanded` spacer → footer block (`stageName` + `_SpeedIconRow` dedesubt).
  - Split scaling: hero (band label + Δ) în `ShrinkToFit` propriu (scale-down în landscape); footer (stage name + speed row) la dimensiuni fixe lizibile, `ShrinkToFit` separat doar dacă overflow.
  - Mută stage name în footer (jos), speed row pe rând propriu sub el — ca în mockup.
  - `_SpeedIconRow`: mărit (valori ~30pt mono, captione stencil, iconițe, separatoare, `km/h` comun), păstrează `fmtSpeed(target)` pentru `35.9`/`40` și `—` pe null avgReal / NaN now. Opțional: tint ACUM roșu când `now > maxSpeedLimit` (select îngust nou) dacă nu se bate cu `OverSpeedAlert`.
  - Păstrează rolul overlay-elor `Stack`/`Positioned`: locality (top-left), `_TickPainter` (top), accent bar (top-center), flash wash (clip-to-band), `OverSpeedAlert`. Doar conținutul `Column` se reordonează.
- [x] **2. Păstrează invarianți**
  - Flash + status-freeze gate: `flashOn = status==inProgress && band!=onTime && !reduced`; `_flash.repeat/stop/reset` + wash doar când `band!=onTime`. NU atinge `state_providers.dart`.
  - `RepaintBoundary` root; `select` îngust (`config.name`, `config.targetAvgSpeed`, `telemetry.currentSpeed`, `telemetry.status`, `actualAvgSpeedProvider`, `localityProvider`, `positionProvider`).
  - `ShrinkToFit` (fără overflow în landscape); `—` pe null/NaN; culori via `context.colors`/`context.text` (mode-aware, fără literali dark).
  - String-uri test (`test/widget_test.dart`): `LA TIMP`, `+ 0.0` (`_formatDelta` păstrat), `Stage 1`, `35.9`/`40` (`fmtSpeed(target)` ca `Text` propriu).
- [x] **3. Verifică**
  - [x] `flutter analyze` → 0 issues.
  - [x] `flutter test` → tot green (102/102; widget_test: `LA TIMP`, `+ 0.0`, `Stage 1`, `35.9`, `40` găsite; `40.0` findsNothing).
  - [ ] `flutter run -d A059` portrait+landscape: START → Δ hero sus, stage name footer, speed row sub el, fără overflow; PAUZĂ → Δ înghețat, fără flash; STOP → înghețat, fără flash, OVER-SPD gone; RESET → idle curat. _(pas manual, pe device)_
  - [x] `flutter build apk --debug` → OK.

---

# Issue-uri din testul pe traseu A059 (24–25 iunie)

Sursa: log de telemetrie pull-abil (`retrometer_telemetry.log`, 171 recorduri, 126 fix-uri GPS, 7 stagii). Analiză via `tool/analyze_telemetry_log.dart`. Confirmări pe hardware + bug-uri noi.

## Confirmări (funcționează corect, nu se ating)

- **Bug A059 `position.speed==0` în mișcare — confirmat.** Doar 2/126 fix-uri au `rawSpeedMps > 0`. Derivarea distanță/timp (`state_providers.dart:205`) e necesară.
- **Auto-start OR-logic cu GPS real — OK.** 4 prompt-uri „în geofence" (11–94m), 3 confirmate, 1 declinat.
- **Pause/resume — OK.** Singurul pause→resume (stg6) cu `pauseOffsetSeconds` corect.
- **Finish-location prompt — OK când NU e precedat de finish-time dismiss** (stg6: `finish_entered`→`finish_location`+18ms→`finish_confirm`).
- **Telemetria durabilă și-a făcut treaba** — bug-urile de mai jos ar fi fost invizibile fără ea.

## Bug-uri noi de rezolvat

- [~] **A. CRITIC: jitter GPS → viteze derivate absurde + odometru umflat** — **A1 făcut (clamp + gate accuracy + logging); A2 (odometer-cap) pending date noi de pe device.**
  - **Simptom:** `maxSpeedKmh` 521–567 km/h scris în `StageResult` → SQLite `stage_history` → overview ar arăta „PESTE LIMITĂ 567 km/h". `addedM` de 1029m / 1444m într-un singur fix.
  - **Root cause:** distribuție accuracy: 23 fix <25m, 31 în 25–50m, **47 în 50–100m, 6 în 100–200m, 19 ≥200m (până la 600m)**. Pragul de mișcare `_kMovingThresholdMetres = 5.0` (`state_providers.dart:20`) e sub jitter-ul tipic pentru accuracy slab → orice fix care sare >5m primește `addedMetres/dt` = viteze imposibile.
  - **A1 (făcut):** gate pe accuracy pe calea derivată (`_kPoorAccuracyMetres = 50.0` — fix-urile cu accuracy >50m țin viteza anterioară, nu injectează junk; `accuracy==0` trece), clamp backstop `_kMaxDerivedSpeedKmh = 200.0`, event `fix_speed_held` în log. Distanța se acumulează în continuare (A1 nu sub-numără). 2 teste (`poor-accuracy fix does not inflate maxSpeedKmh`, `derived speed is clamped to the backstop ceiling`).
  - [ ] **A2 (pending):** odometru — plafează `addedM` per fix pe baza count-ului `fix_speed_held` + distribuției accuracy din noul log post-fix (necesită date pe device). Fereastră mobilă (median pe ultimele N fix-uri bune) în loc de `addedMetres/dt` pe un singur interval — opțional, dacă A1 + E nu suficient.
  - **Validare A1:** refă test pe A059/device nou, verifică în log `speedKmh` ≤ 200, `maxKmh` rezonabil, `fix_speed_held` events pentru accuracy >50m.

- [x] **B. UX: dismiss la finish-time suprimă finish-location pe toată durata stagiului** — **făcut (guard per-reason).**
  - **Simptom:** stg7 — `finish_time` la 45s (11:37:35) → `finish_dismiss` (11:37:42). 16 min mai târziu `finish_entered` la 11:53:02 (90m) și 11:53:13 (94m), ambele ≤200m, dar **niciun `finish_location`, niciun dialog** → stagiu terminat doar prin STOP manual (995s).
  - **Root cause:** guardul once-per-stage `_promptedThisStage` era pe stagiu, nu pe motiv — un time-finish fals-alarmă îl trip-a și sufoca semnalul real de sosire.
  - **Fix (făcut):** `Set<StageFinishReason> _promptedReasons` în loc de `bool`; `_maybeTimeFinish`/`requestLocationFinish`/`_setPending` guard-ează per-reason; re-arm `clear()` pe idle/completed. Time și location promptează independent. Test regresie `time-finish dismiss does not suppress the location-finish prompt (per-reason guard)`.

- [x] **C. `allocatedTimeSeconds=45` alarme false + `planKm=0` lipsă** — **făcut (dialog de confirmare la salvare).**
  - **Simptom:** 4/7 stagii cu `allocatedTimeSeconds=45`, toate au declanșat `finish_time` în primul minut, toate dismiss-uite. `totalDistanceKm=0.0` pe toate. Efect în cascadă: prompt de timp = zgomot → echipaj învață să-l dismiss → declanșează bug-ul B.
  - **Fix (făcut):** `_confirmWarningsThenPop` în `stage_editor.dart` — dialog `confirmDialog` (Salvează/Modifică) la salvare dacă: (1) `0 < allocatedTimeSeconds < 60` (câmpul e MM:SS, sub un minut = aproape sigur confuzie min↔sec); (2) `allocatedTimeSeconds > 0 && totalDistanceKm == 0` (timp fără distanță = timpul devine singurul semnal de finish, Δ fără referință — exact cascada A059). Non-blocant. Stagii default (alloc=0, dist=0, ex. `competitions_crud_test` creează SS1) nu declanșează dialogul.
  - **Maybe (încă deschis):** reconsiderează dacă `finish_time` pe `allocatedTimeSeconds` atins e comportament dorit când `totalDistanceKm` lipsește (timp-only fără distanță = semnal slab). Acum e doar avertizat, nu blocat.

- [x] **D. Minor: snooze de 3h la `autostart_decline`** — **investigat + rezolvat (era inconsistență TZ în log, nu bug de calcul).**
  - **Investigare:** `autostart_decline` 20:56:17Z cu `snoozeUntil=2026-06-25T00:01:17` (+3h5m aparent). Root cause: `ts` (envelopă) se loghează UTC (`...Z`), dar `snoozeUntil` se serializa ca timp **local** (fără Z) — Romania e EEST (UTC+3), deci 20:56Z + 5min = 00:01 local. Snooze-ul era corect 5min tot timpul; doar părea 3h.
  - **Fix (făcut):** `snoozeUntil` (`competition_providers.dart:484`) + `startTime` în `autostart_prompt` data (`:418`) serializate ca UTC (`toUtc().toIso8601String()`) ca să match-eze `ts`. `_telemetryJson` (`startTime`/`pausedSince`) rămâne **local** intenționat — înregistrările lifecycle (`stop`/`start`) carie și `result.completedAt`/`startedAt`/`completedAt` (model toJson, local); păstrarea lor locală ține fiecare înregistrare lifecycle intern-consistentă (altfel `startTime` UTC vs `completedAt` local ar părea 3h în aceeași înregistrare). Câmpurile standalone comparate direct cu `ts` sunt UTC; payload-urile lifecycle sunt local — regulă curată pe context.
  - **Out of scope (latent):** model `toJson` DateTimes (`StageResult.completedAt`, `StageRunHistory.startedAt`/`completedAt`, `Competition.startDate`/`endDate`, `PlannedStage.startTime`) sunt încă local-no-Z în SQLite + log. UTC-izarea lor ar necesita audit `.toLocal()` în formaterii UI (`formatTime` din `utils/formatting.dart` face `dt.hour` direct — ar afișa 3h dezloc pe DateTimes UTC). Risc user-visible → amânat. Reader-ele (`DateTime.tryParse`) sunt robuste la ambele formate, deci o eventuală migrare e soft (one-way).

## Geolocator: adoptă `AndroidSettings` (nu schimba pachetul)

- [~] **E. `AndroidSettings` în `GeolocatorGpsService`** (`lib/services/gps_service.dart`) — **implementat flagged (default off); validare pe device pending.**
  - **De ce:** foloseam `LocationSettings` generic → FusedLocationProvider pe defaults → exact comportamentul A059 (speed=0, accuracy 600m, fix-uri la 13s cu jitter). geolocator expune `AndroidSettings` (via `geolocator_android` tranzițiv, re-exportat din `package:geolocator/geolocator.dart`) cu knob-uri direct relevante.
  - **Făcut:** helper `_locationSettings` — pe `Platform.isAndroid` construiește `AndroidSettings(forceLocationManager: kForceAndroidLocationManager, intervalDuration: ..., timeLimit: ...)`; altfel `LocationSettings` generic. `positionStream` folosește `intervalDuration: 1s` (fix-uri regulate 1Hz); `getCurrentPosition` one-shot (fără intervalDuration). `positionProvider` (feed localitate/LED, `LocationAccuracy.low`) **neatins** — nu-i trebuie fix-uri dense. `AndroidSettings` re-exportat din `geolocator` (fără import nou); câmpuri confirmate în `geolocator_android-5.0.3`.
  - [ ] **`forceLocationManager`** — în spatele `const kForceAndroidLocationManager = false` (top of `gps_service.dart`). OFF by default — verifică pe device real înainte de flip (unele Android-uri au LocationManager GPS lent/blocat).
  - [x] **`intervalDuration: 1s`** — live pe Android pentru stream-ul de stagiu (dt mic+constant → viteza derivată nu mai e amplificată de jitter + odometru lin). Comportament schimbat pe Android (înainte: default FusedLocationProvider, fix-uri la ~13s); pe celelalte platforme zero impact.
  - **Validare (pe device, în afara suitei automate):** pornește un stagiu, verifică în log `dtMs` ~1000ms constant. După flip `kForceAndroidLocationManager = true`: `rawSpeedMps > 0` la fix-urile cu accuracy bună. Confirmă pe A059 sau device nou înainte de permanentizare.
  - **NU rezolvă:** `position.speed` passthrough (derivarea distanță/timp rămâne necesară oricum) + filtrarea accuracy (responsabilitatea noastră — vezi bug A). `AndroidSettings` + gating accuracy sunt complementare.