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