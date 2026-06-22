# Retrometer — Plan: refactor UI · Restomod day/night

> Concept aprobat: `design/concept3-refined.html` (restomod retro × modern flat, cu flash Δ pe avans/întârziere).
> Constraint hard: **behavior + 87 teste green** (80 unit + 7 integration). Niciun `find.text` string schimbat, niciun widget type redenumit/șters (păstrează `find.byType` green). Doar aditiv vizual + tokenizare.
> Stack: Riverpod 2.x **manual** (NU codegen) + freezed (codegen doar modele). Fără go_router, fără google_fonts la runtime — fonturi bundle-uite ca assets.

---

## Decizii locked

- **Tema day/night**: **Manual only**, default **noapte**. Toggle în ecran Despre. Persistat `retrometer.theme_mode` (`'night'` default / `'day'`).
- **Estetică**: **Restomod** (concept3-refined) — paletă warm, LCD segmentat, stencil race-numerals, knurled knobs, double-rule gauge bezel, tick marks, LED strip — totul flat (hairline + culoare, zero umbre/glow excesiv).
- **Accent LCD**: **amber** `#ff9b21` (match concept3). Alternativ teal = schimbare unui singur token (`--lcd`). Δ band semantics păstrate distinct: **on-time = teal-green** (`#34d399`-ish, calm), **avans = red** (flash), **întârziere = amber** (flash). LCD accent (distanță/elapsed/UI/knobs) = amber.
- **Fonturi bundle-uite** (fără DSEG — curat, modern, lizibil):
  - **Roboto Mono** — digits hero: distanță (`14.56`), elapsed (`00:42`), valoarea Δ (`+ 0.0` / `-12.4`). Fixed-width + `FontFeature.tabularFigures()`. Are `+ - . : 0-9` (rezolvă problema `+` pe care o avea DSEG7). Feel = digital-instrument modern, NU 7-seg skeuomorphic.
  - **Roboto** — body/UI text (titluri de ecran, meta, câmpuri, dialog, butoane).
  - **Saira Stencil One** — restomod signature: titluri secțiuni, label bandă Δ (`LA TIMP`/`AVANS`/`ÎNTÂRZIERE`), nume stagiu, badge-uri, status strip. Suportă Latin Extended (diacritice ro OK).
  - **Fără Oxanium, fără DSEG.** Roboto e system-default pe Android (zero cost acolo); bundle-uit pe iOS pentru consistență offline.
  - **Licențe**: Roboto + Roboto Mono = **OFL** (include `LICENSE` text); Saira Stencil One = **OFL-1.1**. Ambele ship-uite ca assets + un ecran „Licențe open-source" în Despre (`showLicensePage`).
  - **Ghost-segment effect eliminat** — era un artifact 7-seg (DSEG); cu Roboto Mono nu are sens. `LcdReadout` widget NU se mai creează.
- **Scope**: tokeni temă (light+dark via `ThemeExtension`) + materialitate (flash, knobs, ticks, double-rule, LED strip) + polish ușor de layout. **FĂRĂ** rebuild structural de widget tree.
- **Δ flash**: AVANS/ÎNTÂRZIERE = flash hard full-zone (wash saturat + bara de accent pulse) ~700ms, `steps(1,end)` (on/off dur, nu smooth). LA TIMP = calm steady. Fallback `MediaQuery.disableAnimations` / reduced-motion = tint steady fără animație. Cifrele rămân lizibile (culoare bandă + glow noapte).

---

## Principii & best practices Flutter

- `const` pe toate widget-ele posibile; `RepaintBoundary` pe zone care anim (Δ band, knob press, LED pulse).
- Riverpod `select` îngust pe rebuild-uri (deja în cockpit — păstrează).
- `ThemeExtension` pentru tokens care variază light/dark; `context.colors` / `context.text` extension pentru ergonomie.
- Token scale: spacing / radius / icon-size / duration — elimină literali.
- Behavior-preserving: strings widget identice, tipuri widget identice, API provider identic.
- Fără `setState` pentru stare complexă; flash-ul Δ folosește un `AnimationController` într-un `StatefulWidget` (DeltaIndicator e deja stateful pentru OverSpeedAlert).

---

## Arhitectură temă (F1)

`lib/theme/retrometer_theme.dart` rescris:

- **`RetrometerColors extends ThemeExtension<RetrometerColors>`** cu `RetrometerColors.dark()` / `RetrometerColors.light()`. Câmpuri: `background, surface, surfaceElevated, surfaceHeader, sheet, primary(lcd accent), secondary, danger, onTimeFg/onTimeBg, advanceFg/advanceBg, delayFg/delayBg, textPrimary..textFaint, hint, divider, dividerStrong, fieldBorder, scrim, startFill, stopFill, resetFill, onActionFill`. Light = warm bone (`#f1ead9` surface, `#fbf6e9`), dark = charcoal warm (`#161210`/`#1d1916`). `pillDecoration(color)` devine metoda care ia `colors` curent.
- **`RetrometerTextStyles extends ThemeExtension<RetrometerTextStyles>`** build-uit din `RetrometerColors` (`.dark()/.light()`). Stilurile de cifre hero (`distanceNumber, topBarElapsed, deltaNumber, deltaNumberColored, adjustSign`) → `fontFamily: 'RobotoMono'` + `FontFeature.tabularFigures()` (deja prezent ca `_tabular` în cod — păstrat). Stilurile stencil (`deltaStageName, bandLabel, sectionLabel, sheetTitle, headerTitle, tileTitle, guideSection, badge, competitionRow`) → `'SairaStencil'`. Body/meta/field/control → `'Roboto'`. `tabularFigures()` are sens pe Roboto Mono (are GSUB/tnum) — păstrat pe toate numericile mari.
- **`RetrometerRadii`**: `pill=6, field=8, chip=10, control=12, card=16, sheet=20, tile=20, band=28, appIcon=22` (toate `const`).
- **`RetrometerSpacing`**: `s4=4, s8=8, s12=12, s16=16, s24=24, s32=32`.
- **`RetrometerIconSizes`**: `sm=15, md=18, lg=22, xl=46, empty=56`.
- **`RetrometerDurations`**: `bandTransition=200ms, deltaFlash=700ms, overSpeedPulse=500ms, ledPulse=1100ms`.
- **`retrometerTheme()`** (dark) + **`retrometerLightTheme()`** (light): ambele cu `extensions: [colors, textStyles]` + component themes (appBar, filledButton, fab, iconButton, input, bottomSheet, dialog, divider, switch, progressIndicator, textTheme, textButton) — versiuni light pentru light theme. `scaffoldBackgroundColor` din colors.
- **Context extensions** `RetrometerContextX`: `colors` → `Theme.of(context).extension<RetrometerColors>()!`, `text` → `...<RetrometerTextStyles>()!`.

---

## Font bundling (F0)

1. Roboto + Roboto Mono TTF din /Users/zml/Dev/retrometer/assets/fonts
2. Download Saira Stencil One TTF + OFL text din /Users/zml/Dev/retrometer/assets/fonts
3. Copiază în `assets/fonts/` + `assets/fonts/licenses/` 
4. `pubspec.yaml`:
   ```yaml
   flutter:
     fonts:
       - family: Roboto
         fonts:
           - {asset: assets/fonts/Roboto-Regular.ttf}
           - {asset: assets/fonts/Roboto-Medium.ttf, weight: 500}
           - {asset: assets/fonts/Roboto-Bold.ttf, weight: 700}
       - family: RobotoMono
         fonts:
           - {asset: assets/fonts/RobotoMono-Regular.ttf}
           - {asset: assets/fonts/RobotoMono-Bold.ttf, weight: 700}
       - family: SairaStencil
         fonts: [{asset: assets/fonts/SairaStencilOne-Regular.ttf}]
     assets:
       - assets/fonts/licenses/
   ```
5. Verifică: `flutter pub get` + smoke `Text('14.56', style: TextStyle(fontFamily: 'RobotoMono', fontFeatures: [FontFeature.tabularFigures()]))` randează fixed-width (nu tofu).

---

## Sub-agent allocation (paralelizare)

Folosește sub-agenți `Explore`/`general-purpose` pentru faze cu multe fișiere independente:

- **F1 + F6 (migrare literals → tokens + `RetrometerColors.x` → `context.colors.x`)**: fan-out **4 sub-agenți paralel**, unul per grup de fișiere:
  1. `lib/cockpit/*` (top_bar, delta_indicator, tripmeter, config_sheet)
  2. `lib/competition/*` (list, detail, stage_editor, competition_editor)
  3. `lib/widgets/*` (cards, info_widgets, metadata_tile, editor_sheet, form_fields, icon_text_row, alert_dialog, location_field, speed_summary_line, compact_icon_button, shrink_to_fit)
  4. `lib/*` views (cockpit_view, about_view, guide_view, location_disclosure, main.dart)
  Fiecare sub-agent: înlocuiește literali (`Colors.red`/`Colors.black`, radii 6/8/10/12/14/22/28, paddings, alpha tints, inline `TextStyle(color:)`) cu tokeni + schimbă referințele `RetrometerColors.x` statice în `context.colors.x` (sau `Theme.of(context).extension`). **Nu** schimbă strings, **nu** redenumește widget types. Raportează fișiere + linii atinse.
- **F4 materialitate**: sequential sau 2 sub-agenți (Δ flash + knobs/ticks/LED strip separat de double-rule frame/label plates) — au widget-uri partajate (`SurfaceCard`, `RestomodFrame`), atent la conflicte.
- **F7 verify**: un sub-agent `general-purpose` rulează `flutter analyze` + `flutter test` + raportează; integrare pe device rulează agent-ul principal (NECESITĂ device conectat).

---

## Faze

### F0 — Assets & fonturi (vezi sus)
- Fișiere: `assets/fonts/*`, `assets/fonts/licenses/*`, `pubspec.yaml`.
- Sub-agent: 1 (download + plasează + pubspec).
- Test impact: none (assets).

### F1 — Arhitectură temă (ThemeExtension + tokeni + light theme)
- Fișiere: `lib/theme/retrometer_theme.dart` (rewrite), `lib/theme/retrometer_theme_light.dart` (sau în același fișier — `retrometerLightTheme()`).
- Sub-agent: 1 (fundamentele — extensions, tokeni, ambele ThemeData). **Blochează F3/F4/F6** (restul depinde de tokens).
- Test impact: `find.text` safe. Risc: dacă un widget citea `RetrometerColors.background` static și devine `context.colors.background`, trebuie context valid — toate call sites sunt în `build()`, OK. Verifică `retrometer_theme.dart` nu mai expune statici vechi folosiți în teste (teste widget instanțiază `RetrometerApp` care are tema înregistrată → extensions disponibile).

### F2 — Theme-mode provider + wiring + toggle + licențe
- Fișiere noi: `lib/theme/theme_mode_provider.dart`. Modificat: `lib/main.dart` (ConsumerWidget + `UncontrolledProviderScope` + `load()` pre-runApp + `theme:/darkTheme:/themeMode:` + `SystemUiOverlayStyle` follows mode), `lib/about_view.dart` (toggle row + „Licențe open-source" row).
- Pattern provider (manual Riverpod, mirror `CompetitionNotifier`):
  ```dart
  class ThemeModeNotifier extends Notifier<ThemeMode> {
    @override ThemeMode build() => ThemeMode.dark;
    Future<void> load() async { /* citește retrometer.theme_mode */ }
    Future<void> setMode(ThemeMode m) async { /* state + persist */ }
    Future<void> toggle() async => setMode(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }
  final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
  ```
- `main()`: `WidgetsFlutterBinding.ensureInitialized()` (deja există) → `await SystemChrome.setPreferredOrientations(...)` → creează `ProviderContainer`, `await container.read(themeModeProvider.notifier).load()` → `runApp(UncontrolledProviderScope(container, RetrometerApp()))`.
- Toggle: în `AboutScreen` (ConsumerStatefulWidget — `ref` disponibil) după `_VersionBadge`: `ListActionRow(icon: Icons.brightness_3_outlined, label: 'Temă: Zi/Noapte', onTap: () => ref.read(themeModeProvider.notifier).toggle())` (sau `SwitchListTile`). **String-ul label-ului NU e assert-uit în teste** (about_test assertuiește doar 'Despre aplicație','Retrometer','Versiune','Ghid de utilizare','Politică de confidențialitate','Permisiuni' — toate păstrate).
- Licențe: `showLicensePage(context, applicationName: 'Retrometer', applicationVersion: ...)` sau un row care duce la un ecran cu textele de licență (Roboto/Roboto Mono OFL + Saira OFL) din `assets/fonts/licenses/`. 
- Sub-agent: 1.
- Test impact: `about_test`/`about_permissions_test` — păstrează cele 3 row-uri existente (Ghid/Politică/Permisiuni) NEATINSE ca text+ordine; adaugă row-uri noi după ele. `pumpRetrometer` helper (`integration_test/helpers/test_app.dart`) creează propriul `ProviderScope` → `themeModeProvider` default `ThemeMode.dark` (fără `load()`) — teste rămân dark (așa cum expected). Conversia `RetrometerApp` → `ConsumerWidget` compatibilă cu toate pump sites.

### F3 — Aplicare fonturi (fără ghost/LcdReadout)
- Re-point stiluri în `RetrometerTextStyles` (F1 le definește cu `fontFamily` corect): `distanceNumber, topBarElapsed, deltaNumber, deltaNumberColored, adjustSign` → `'RobotoMono'` + `tabularFigures()`. `deltaStageName, bandLabel, sectionLabel, sheetTitle, headerTitle, tileTitle, guideSection, badge, competitionRow` → `'SairaStencil'`. Body/meta/field/control (`meta, metaStrong, metaMuted, fieldLabel, fieldInput, tileTime, guideRow, controlLabel, topBarText, emptyTitle`) → `'Roboto'`.
- Aplicare:widget-urile citează deja stilurile din `RetrometerTextStyles` → după ce F1 setează `fontFamily`-ele, fontul se propagă automat în majoritatea site-urilor. Verifică site-urile cu `TextStyle(...)` inline care ocolesc tokenii (lista din F6) ca să nu rămână pe font default.
- **Diacritice**: Roboto, Roboto Mono, Saira Stencil One toate suportă Latin Extended → `Ț/Ș/Â/Î/Ă` randează nativ. Niciun risc diacritice (spre deosebire de DSEG). Label bandă Δ `'ÎNTÂRZIERE'` rămâne cu diacritice, string widget NEATINS.
- Sub-agent: 1.
- Test impact: `find.text('LA TIMP')`, `find.text('+ 0.0')`, `find.text('0.00')`, `find.text('100.00')`, `find.text('999.99')`, `find.text('Stage 1')`, `find.textContaining('țintă 35.9')` — toate safe (string content păstrat, fontul nu afectează find.text).

### F4 — Materialitate restomod (vizual, aditiv)
1. **Δ flash** (`cockpit_delta_indicator.dart`): `AnimationController(duration: RetrometerDurations.deltaFlash)` în `DeltaIndicator` state. Când `deltaBand != onTime` → pornește flash (hard on/off via `ColorTween`/`StepTween` pe `bandBg` + `barMark` pulse); `onTime` → oprește, calm. Respect `MediaQuery.disableAnimations`. Păstrează `AnimatedContainer` existent pentru band-transition (200ms) — flash-ul e un strat adițional. `RepaintBoundary` deja present.
2. **Knurled knobs** (`cockpit_tripmeter.dart` `AdjustZone`): `SurfaceCard` cu decor restomod — concentric rings via `Border` + knurl via `BoxDecoration(gradient: SweepGradient repeating)` sau `CustomPaint`. Păstrează `find.text('10 m')`, `find.text('lung: 100 m')`, tip `AdjustZone`/`TripmeterBar` NEATINSE.
3. **Tick marks gauge** (`cockpit_delta_indicator.dart`): rând decorativ de ticks deasupra Δ (`Row` de `Container` lines sau `CustomPaint`) — aditiv, zero impact texte.
4. **Double-rule bezel** — widget nou `lib/widgets/restomod_frame.dart` (`RestomodFrame`): `Container` cu border dublu (1px `line` + 1px `lineStrong`) flat, fără umbră. Înfășoară cockpit-ul în `cockpit_view.dart` și previzualizările. **Nu** schimbă `CockpitView` type (e `StatefulWidget` — `find.byType(CockpitView)` păstrat).
5. **LED strip** (`cockpit_top_bar.dart` sau `cockpit_view.dart`): rând subțire (~20px) cu puncte `GPS · STAGE · OVER-SPD · AUTO-START` (LED-uri plate, color din `colors.signal`/`danger`/`warn`). **RISC overflow landscape** — widget_test pompează landscape și assertuiește no-overflow. Mitigare: strip fixed-height deasupra celor 3 zone `Expanded` (Column: fixed + 3×Expanded) — nu overflow. Verifică landscape 800×384 (sau ce folosește testul) după F4.
6. **Etched label plates** (`LOC`, `T`, `km`, `țintă`): `plate` style (fundal `labelPlate`, text `labelInk`, tracking lat). Aplicat pe label-uri mici din top-bar/tripmeter.
- Sub-agenți: 2 (A: Δ flash + ticks; B: knobs + LED strip + double-rule + plates) — B atinge mai multe fișiere, A e mai izolat. Atent la `cockpit_delta_indicator.dart`/`cockpit_top_bar.dart` partajați — coordonează sau sequential.
- Test impact: `find.byType(CockpitView)`, `find.byType(TripmeterBar)` păstrate (tipuri neatinsi). `find.byIcon(Icons.settings)` păstrat. No-overflow landscape de re-verificat.

### F5 — Polish layout (spacing/hierarchy)
- Aplică `RetrometerSpacing` peste padding-urile recurente (`EdgeInsets.fromLTRB(16,...)` screen padding, `symmetric(h:16,v:14)` rows). Hierarchy: titluri stencil mai mari, body Roboto mai cald. Fără schimbare structură.
- Sub-agent: 1 (sweep padding literals → `RetrometerSpacing`).
- Test impact: none (padding nu afectează find.text/byType).

### F6 — Literal sweep (Colors.red/black, inline TextStyle, radii, alpha tints)
- Vezi sub-agent allocation F1+F6 (4 sub-agenți paralel per dir). Concrete ținte (din audit):
  - `cockpit_delta_indicator.dart:144` `Colors.black.withValues(alpha:.6)` → `colors.scrim`; `:146` `Colors.red` → `colors.danger`.
  - `retrometer_theme.dart` `overSpeed` `Colors.red` → `colors.danger` (devine extension).
  - `about_view.dart:196` r22 → `RetrometerRadii.appIcon`; `:230` `primary.withValues(alpha:.12)` → token theme-aware.
  - `cockpit_tripmeter.dart:114` `primary.withValues(alpha:.3)` → token.
  - `cockpit_delta_indicator.dart:60` r28 → `RetrometerRadii.band`; `:62` `fgColor.withValues(alpha:.25)` → token.
  - `cards.dart` default radius 14 → `RetrometerRadii.card` (rezolvă inconsistența 14 vs 16).
  - `icon_text_row.dart` r10, `metadata_tile.dart` padding, `editor_sheet.dart` padding → spacing tokens.
  - Inline `TextStyle(color: RetrometerColors.textPrimary)` (~15 site-uri) → `context.text.<style>` sau `context.colors.textPrimary`.
- Sub-agenți: 4 paralel (cockpit / competition / widgets / views).
- Test impact: none (culori/padding nu afectează find).

### F7 — Verify (final, OBLIGATORIU)
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regen models.freezed.dart
flutter analyze                                            # target: 0 issues
flutter test                                               # target: 80/80
flutter test integration_test/ -d A059                     # target: 7/7 (device conectat)
flutter build apk --debug                                  # OK
```
- `flutter run -d A059 --debug`: verifică pe traseu — Δ flash avans/întârziere, day mode lizibil în soare, night mode fără glare, fonturi segmentate randează corect, knobs/ticks/LED strip vizibile, no-overflow landscape+portrait.
- Dacă `flutter test integration_test/` nu are device: `flutter devices` → folosește primul device conectat (`-d <id>`). Integrarea NU e host-headless (build APK + instalare pe device real).
- Raportează rezultatul real: analyze issues count, unit pass/total, integration pass/total, apk build OK/FAIL. Dacă ceva pică, **nu** marcați faza done — debug până la green.

---

## Ordine execuție

F0 → F1 (blochează restul) → F2 (paralel cu F3?) → F3 → F4 → F5 → F6 (paralelizabil cu F4/F5 pe dir-uri ne-suprapuse — atent) → F7.

Recomandat: F0, F1 sequential (fundamente). Apoi F2 + F3 + F6-litere paralelizate pe sub-agenți (F6 atinge fișiere pe care F2/F3 le modifică — coordonează ca F6 să ruleze DUPĂ F2/F3 pe fișierele partajate `main.dart`/`about_view.dart`/`retrometer_theme.dart`, sau partitionează F6 să evite fișierele în lucru). F4 după F3 (fonturi pe place). F5 după F4. F7 la final.

---

## RISC-uri & mitigări

- **Overflow landscape** de la LED strip / double-rule frame → verifică `widget_test` landscape după F4; reduce înălțime strip / padding frame dacă overflow.
- **Diacritice** → Roboto, Roboto Mono, Saira Stencil One toate suportă Latin Extended (`Ț/Ș/Â/Î/Ă`); `ÎNTÂRZIERE` randează nativ. Risc rezolvat prin alegerea Roboto (era problema cu DSEG).
- **`+` în Δ** → Roboto Mono are `+` nativ. Risc rezolvat (era problema cu DSEG7).
- **Roboto Mono tabular** → `FontFeature.tabularFigures()` susținut (Roboto Mono are GSUB/tnum); păstrat pe toate numericile mari.
- **ThemeExtension null** în teste care pump `MaterialApp(home: CockpitView())` direct (widget_test L181/L207 pump `ProviderScope(child: MaterialApp(home: CockpitView()))` FĂRĂ tema noastră) → `context.colors` aruncă null. **Mitigare**: `context.colors` getter returnează `Theme.of(context).extension<RetrometerColors>() ?? RetrometerColors.dark()` — zero crash, teste green fără modificare. Notați ca decisie în F1. (Tipărițile `deltaStageName` etc. cu `fontFamily:'SairaStencil'` nu crash-uiesc dacă fontul nu e înregistrat — Flutter fallback la platform default, doar estetic diferit în test.)
- **`UncontrolledProviderScope` vs `ProviderScope` în integration helper** → helper-ul creează propriul `ProviderScope` (L67), `themeModeProvider` default dark, OK. Dacă un test inspectează `themeModeProvider` direct → niciunul nu o face.
- **Cifre la dimensiuni mari** (`distanceNumber` 120px, `deltaNumber` 180px) → verifică că `ShrinkToFit`/`FittedBox` încă scalează fără overflow (moștenit din layout existent, neatins). Roboto Mono e mai compact decât DSEG → mai puțin risc overflow la valori mari (`100.00`, `999.99`).

---

## Done definition

- `flutter analyze` 0 issues.
- `flutter test` 80/80.
- `flutter test integration_test/ -d A059` 7/7.
- `flutter build apk --debug` OK.
- Mockup `concept3-refined.html` materializat în app: paletă warm, Roboto Mono LCD digits, stencil, knobs, ticks, double-rule, LED strip, Δ flash pe avans/întârziere, day/night toggle funcțional (default noapte, persistat).
- Licențe OFL (Roboto, Roboto Mono) + OFL (Saira Stencil One) ship-uite + expuse în Despre.