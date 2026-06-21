# Retrometer — Handoff

> **Stare:** implementat. `flutter analyze` 0 issues · `flutter test` 38/38 · `flutter build apk --debug` OK.
> Identitate: `com.zmeul.retrometer` pe toate platformele. Schimbarea de applicationId = install fresh (SharedPreferences `retrometer.*` NU se mută între pachete).

## Ce este

Trip-meter / „Rally Computer" pentru raliu de regularitate (BMW Z3). Offline, dark, blind-touch, 60fps, cu izolarea rebuild-urilor prin `select` + `RepaintBoundary`.

Funcționalități:
- **Cockpit** — indicator Δ (avans/întârziere/la timp), distanță acumulată din GPS, ajustare blind-touch (±0.01 / ±0.1 km), alertă over-speed, localitate (reverse-geocode), viteză țintă/max cu zecimale.
- **Competiții** — grupează stagii + metadate echipaj/eveniment (pilot, copilot, mașină, categorie, total echipe, contact, cost, loc general/categorie). Se pot desfășura pe mai multe zile (interval `startDate`/`endDate`). Persistate în `retrometer.competitions`; vechiul `retrometer.schedule` plat e migrat automat într-o competiție „Importate"; cheia legacy `date` (pre-multi-day) e migrată în `startDate`.
- **Program de stagii** — auto-start pe geofence de start + auto-stop pe geofence de sosire; distanță totală + timp alocat introduse manual.
- **Ecran „Despre"** — versiune (`package_info_plus`), link ghid, link politică de confidențialitate (browser), pagină de permisiuni cu stare live.
- **Prominent Disclosure** — dialog în-app înainte de prima cerere a permisiunii de locație (aliniat Play).
- **Orientare liberă** (portrait + landscape), layout responsive.

## Stack

- Flutter 3.38 / Dart 3.10
- **Riverpod 2.x manual** (NU codegen) + **freezed 2.x** (codegen doar pentru modele). `build_runner` merge pentru freezed; codegen-ul Riverpod e blocat de `analyzer_plugin` incompatibil cu analyzer-ul livrat de SDK — providerii sunt scriși de mână. De revenit la codegen când lanțul `riverpod_generator → analyzer_plugin` primește o versiune reparată.
- Pachete: `geolocator` 13.x, `geocoding` 4.x, `shared_preferences` 2.x, `wakelock_plus` (trage tranzitiv `package_info_plus`), `vibration`, `package_info_plus` 10.x, `url_launcher` 6.x.

## Design

Tema centralizată în `lib/theme/retrometer_theme.dart`: `RetrometerColors` + `RetrometerTextStyles` + `retrometerTheme()` (component themes). Paletă „Rally" (blue-gray + teal, întunecată pentru condus noaptea):

- Suprafețe: `background #2D2E36`, `surface #363740`, `surfaceElevated #42434D`, `surfaceHeader #1F2A26`, `sheet #3A3B44`.
- Accente: `primary #41DFB4` (teal), `secondary #FFEE58` (galben, Δ întârziere), `danger #FF5252`.
- Benzi Δ: `onTimeBg #0E4D38`/`onTimeFg #41DFB4`, `advanceBg #B71C1C`/`advanceFg #FF5252`, `delayBg #F57F17`/`delayFg #FFEE58`.
- Text pe dark: scară white-opacity (`textPrimary`→`textFaint`); `divider` white12, `fieldBorder` white38.
- Butoane: `startFill` teal, `stopFill` roșu, `resetFill` surfaceElevated, text `onActionFill` negru.
- Tipografie: `tabularFigures()` pe numericile mari. Font platform-default (fără `google_fonts`/assets).

## Harta fișierelor

- `lib/models.dart` — `StageConfig`, `StageTelemetry`, `RallyState`, `PlannedStage`, `Competition` (freezed) + `StageStatus`, `DeltaBand` + helperi JSON. `PlannedStage`/`Competition` au `toJson` manual (ISO8601) și NU declară `factory .fromJson` (ca freezed să nu shadow-uie serializarea). `Competition` are `startDate`/`endDate` (DateTime?, nullable) = intervalul evenimentului (multi-day); `endDate` null sau aceeași zi cu `startDate` ⇒ o singură zi. `competitionsFromJson` migrează cheia legacy `date` în `startDate`. Câmpuri comune pe `StageConfig`/`PlannedStage`: `targetAvgSpeed`, `maxSpeedLimit`, `endLatitude`/`endLongitude` (nullable = fără finish/auto-stop), `endGeofenceRadiusM`, `autoStop`, `totalDistanceKm`, `allocatedTimeSeconds` (0 = nesetat). JSON-urile citesc cu fallback la default (payload-uri vechi/parțiale se încarcă fără eroare).
- `lib/rally_math.dart` — `idealSeconds`, `deltaSeconds`, `deltaBandFor` (pur, testabil).
- `lib/services/gps_service.dart` — wrapper injectabil peste `geolocator` (stream, `distanceBetween`, `checkPermission`/`requestPermission`/`isLocationServiceEnabled`).
- `lib/services/device_service.dart` — wrapper injectabil wakelock + haptic (pentru teste fără canale de platformă).
- `lib/state_providers.dart` — `StageController` (`startStage`/`startStageFromPlan`/`stopStage`/`resetStage`/`updateConfig`/`adjustDistance`, acumulare distanță+viteză din GPS) + providerii `clockTick`, `elapsedSeconds`, `deltaSeconds`, `deltaBand`, `isOverSpeed`, `localityProvider` (toți cu `select` îngust). Listener-ul GPS (async) face **auto-stop**: după ≥2 fix-uri, dacă `autoStop` + finish setat → `distanceBetween(pos, end) ≤ endGeofenceRadiusM` → `stopStage()` + haptic.
- `lib/competition_providers.dart` — `competitionsProvider` (`AsyncNotifier<List<Competition>>`, hidratat+persistat în `retrometer.competitions`; CRUD competiții/stagii + `markStarted`), `activeCompetitionProvider`, `ScheduledStage` = `(Competition, PlannedStage)` (flatten), `autoStartMonitorProvider` (`Notifier<AutoStartStatus>`). Detalii auto-start mai jos.
- `lib/competition_view.dart` — **barrel subțire**: re-exportă `CompetitionsScreen` + `CompetitionDetailScreen` din `lib/competition/` (păstrează valide importurile existente, ex. `cockpit_top_bar.dart`).
- `lib/competition/competition_list_view.dart` — `CompetitionsScreen` (listă) + `_CompetitionTile` (card tappabil) + `_StandingBadge`. Folosește `TappableCard`, `MetaChip`, `StatusPill`, `EmptyState`. Deschide editorul via `showCompetitionEditor`.
- `lib/competition/competition_detail_view.dart` — `CompetitionDetailScreen` (antet metadate via `_CompetitionHeader`/`HeaderRow` + bara status auto-start `_MonitorStatusBar` + listă stagii `_StageTile`) + `findStage` (file-private). `_StageTile` folosește `TappableCard` + `InfoLine` (schedule/location/flag) + `StatusPill` + butoane play/șterge. Helper-e `_fmtSpeed`/`_fmtMmSs`. Deschide editorii via `showCompetitionEditor`/`showStageEditor`.
- `lib/competition/stage_editor.dart` — `showStageEditor` (public) + `StageDraft`/`StageEditor` (file-private). Folosește `NumberField`/`CoordField`/`DateTimeField` din `form_fields.dart` și `AddressSearchField`/`MyLocationButton` din `location_field.dart`. Start/finish deduplicate: două metode mici `_setStart(lat,lng)`/`_setEnd(lat,lng)` actualizează `_draft` + controllerele de coord + `setState`; atât `AddressSearchField` cât și `MyLocationButton` (start/finish) apelează aceleași `onResolved`. Helper-e `_fmtCoord`/`_roundToMinute`/`_newId`.
- `lib/competition/competition_editor.dart` — `showCompetitionEditor` (public) + `CompetitionDraft`/`CompetitionEditor` (file-private). Folosește `LabeledTextField`/`IntField`/`DecimalField`/`DateRangeField` din `form_fields.dart`. Păstrează stagii-le existente la editare.
- `lib/widgets/cards.dart` — `TappableCard`: `Material` cu `shape: RoundedRectangleBorder(borderRadius, side)` + `InkWell(borderRadius)` pentru ripple. **Centralizează pattern-ul de card tappabil și previne bug-ul `Material` `!(shape != null && borderRadius != null)`** (ambele tile-uri îl foloseau înainte — sursa crash-ului din `_CompetitionTile`). Param: `onTap`, `child`, `color` (default `surface`), `radius` (default 14), `border` (default `divider`).
- `lib/widgets/info_widgets.dart` — widget-uri mici reutilizabile: `MetaChip` (icon+text inline), `InfoLine` (icon + `Expanded` Text cu ellipsis; param `textStyle`/`iconColor`/`iconSize`), `HeaderRow` (icon + „label: " + value, `highlight`), `StatusPill` (`pillDecoration(color)` + text badge), `EmptyState` (centrat icon + mesaj; param `iconSize`/`titleStyle`), `confirmDialog(BuildContext, {title, message, confirmLabel='Șterge', cancelLabel='Anulează'})` → `Future<bool>`.
- `lib/widgets/location_field.dart` — deps mai grele (geocoding/gps/disclosure) ținute separat de `form_fields.dart`: `AddressSearchField` (StatefulWidget; deține controller de adresă + stare loading/eroare; props `hintText` + `onResolved(lat,lng)`; geocode via `locationFromAddress`) + `MyLocationButton` (TextButton.icon; `maybeShowLocationDisclosure` + permisiune + primul fix GPS → `onResolved`; captează `ProviderScope.containerOf`+`gpsServiceProvider` înainte de await).
- `lib/cockpit_view.dart` — composition root: `CockpitView` (`StatefulWidget`, onboarding în `initState`) = `Scaffold` cu `Column` 25/40/20 care compune zonele din `lib/cockpit/`.
- `lib/cockpit/cockpit_top_bar.dart` — `CockpitTopBar` (zona de sus 25%): card cu 3 secțiuni verticale via `_topBarCard` (header / body / footer). **Header**: competiție+categorie (`_CompetitionLabel`, stânga; dispare fără competiție activă) + buton 📅 (competiții) + buton ℹ (Despre) (`_NavIconButton`, dreapta). **Body**: localitate + elapsed (MM:SS, 30px bold tabular, centrate — `_CardBody`). **Footer**: `StageControls` (gear + START/STOP + RESET) mărit și centrat. `ref.watch(autoStartMonitorProvider)` ține monitorul viu. **Butonul de ghid/ajutor a fost șters** (ghidul mai e accesibil din onboarding + Despre). Responsive: `<360 px` → controale icon-only (compact). `StageControls` (gear + START/STOP/RESET, **START** async cu `maybeShowLocationDisclosure` înainte de `startStage()`), `ControlButton` (buton fill reutilizabil, compact = icon-only; non-compact mărit — padding 16×10, icon 20, label 15, rază 14). Private: `_topBarCard`, `_CompetitionLabel`, `_CardBody`, `_NavIconButton`, `_formatElapsed`.
- `lib/cockpit/cockpit_delta_indicator.dart` — `DeltaIndicator` (zona centrală 45%, `RepaintBoundary`, `select` îngust, benzi AVANS/ÎNTÂRZIERE/LA TIMP, `FittedBox`, viteze cu `_fmtSpeed`) + `OverSpeedAlert` (puls `AnimationController`). Private: `_formatDelta`, `_fmtSpeed`.
- `lib/cockpit/cockpit_tripmeter.dart` — `TripmeterBar` (zona de jos 40%: `AdjustZone` stânga/dreapta blind-touch `−10 m`/`+10 m` tap, `±0.1` long-press + haptic, `DistanceReadout` `RepaintBoundary`+`select`).
- `lib/cockpit/cockpit_config_sheet.dart` — `showStageConfigSheet` (sheet de configurare; păstrează finish/distanță/timpul via `copyWith`). Folosește `NumberField` din `lib/widgets/form_fields.dart` (partajat cu editorul de stagii/competiții).
- `lib/widgets/form_fields.dart` — câmpuri de formular reutilizabile + utilitare: `pickerTheme` (temă dark pentru pickere dată/oră), `NumberField` (label + câmp numeric, digits/decimal, controller opțional — versiune unificată a fost-ului `_NumberField` din competition_view + `NumberField` din cockpit_config_sheet), `IntField`/`DecimalField` (compact, stil small), `LabeledTextField`, `CoordField` (lat/lng signed), `DateTimeField` (picker dată+oră), `DateRangeField` (interval start+sfârșit), `formatDateTime`/`formatDateRange` (`_formatDate` intern).
- `lib/guide_view.dart` — ghid full-screen + `maybeShowOnboarding` (flag `retrometer.onboarded`).
- `lib/about_view.dart` — `AboutScreen` (`ConsumerStatefulWidget`): antet + badge versiune (`package_info_plus`, FutureBuilder) + 3 rânduri-nav `_NavRow` (icon + label + chevron, ca `_GuideLink`): „Ghid de utilizare" (→ `GuideScreen`), „Politică de confidențialitate" (deschide `kPrivacyPolicyUrl` în browser via `url_launcher`), „Permisiuni" (→ `PermissionsScreen`). `PermissionsScreen` (`ConsumerStatefulWidget`): intro + cele 3 `_PermissionRow` (locație interogată live via `gpsServiceProvider`; vibrație + wakelock statice ca permisiuni normale). `_PermStatus`/`_StatusChip`/`_PermissionRow`/`_NavRow`.
- `lib/location_disclosure.dart` — `maybeShowLocationDisclosure(BuildContext)`: dialog `AlertDialog` (`barrierDismissible: false`) afișat o dată (flag `retrometer.location_disclosure_shown`) înainte de prima cerere de locație; explică scopul, declară prim-plan + fără partajare, notează că e **opțional**, link „Vezi Politica de confidențialitate" (`url_launcher`, `kPrivacyPolicyUrl` — constantă publică, **TODO: înlocuiește cu URL-ul real**; refolosită și pe ecranul Despre); „Continuă"=`true` (flag setat) / „Refuză"=`false` (flag NU se setează → reapare). Guard `context.mounted`. Apelat din cockpit START + cele 2 „Locația mea".
- `lib/main.dart` — `ProviderScope`, `MaterialApp` dark cu `retrometerTheme()`, `setPreferredOrientations(DeviceOrientation.values)`.
- Permisiuni: `AndroidManifest.xml` (FINE/COARSE location, VIBRATE, WAKE_LOCK), `Info.plist` (`NSLocationWhenInUseUsageDescription`). **Fără background location** (foreground-only + wakelock).

## Matematica domeniului

- `t_ideal = distance_km / target_kmh × 3600` (s)
- `Δt = t_real − t_ideal` (`t_real` = elapsed wall-clock ms)
- `Δ < 0` ⇒ avans (roșu); `Δ > 0` ⇒ întârziere (galben); `|Δ| ≤ 1s` ⇒ la timp (verde)
- Distanța se acumulează din stream-ul GPS (`distanceBetween` între fix-uri → km); `adjustDistance(±0.01)` = ±10 m pentru borne.

## Auto-start / auto-stop

- **Planificare:** crew-ul pregătește competițiile + stagii (nume, oră start, locație start cu geofence+rază, **locație finală cu geofence+rază**, viteză țintă/max, distanță totală, timp alocat MM:SS, toggle auto-start/auto-stop). Salvat în `retrometer.competitions`.
- **Auto-start:** `AutoStartMonitor` poll-ează la 5s (+ tick imediat) cât timp statusul `!= inProgress` (idle sau completed). **Flattenează** stagii din toate competițiile; un stage due = `now ≥ startTime`, `now − startTime ≤ 10 min` (grace pentru lansare târzie), `autoStart` true, `started` false. Pornește cu `startStageFromPlan` dacă `distanceBetween ≤ geofenceRadiusM`, apoi `markStarted`.
- **Auto-stop:** în `StageController._subscribeGps`, la fiecare fix (după ≥2 fix-uri, ca primul să nu declanșeze) dacă `autoStop` + finish setat → `distanceBetween(pos, end) ≤ endGeofenceRadiusM` → `stopStage()` + haptic.
- **Fix GPS robust:** colectează fix-uri 12s, păstrează cel mai precis (preferă `accuracy ≤ 50 m`) — primul fix la GPS rece poate fi cu kilometri în afara geofence-ului. Guard `_busy` interzice suprapunerea tick-urilor (5s pol vs. 12s colectare).
- **Wakelock pending:** monitorul ține ecranul aprins cât există ≥1 stage pending (până la 24h) ca OS-ul să nu suspende timer-ele (app foreground-only). Trade-off: baterie (telefon pe bord, încărcat).
- **Diagnostic:** `autoStartMonitorProvider` expune `AutoStartStatus` (mesaj, ora verificării, următorul stage, precizia fix-ului, distanță/rază) afișat într-o bară pe detaliul competiției (`așteptare` / `în afara geofence-ului` / `nu am primit fix GPS` / `permisiune refuzată` / `pornesc <numă>…`).

### Gotche-uri de implementare (verificați la refactor)

- În `_tick`/`_tickInner`, rezolvați **toate dependențele** (`competitionsProvider.notifier`, `stageControllerProvider.notifier`, `deviceServiceProvider`, `gpsServiceProvider`) la început, înainte de orice `await`. Schimbarea de status din `startStageFromPlan` reconstruiește monitorul și invalidează `ref`-ul mid-tick — altfel `markStarted` nu se mai apelează.
- Setarea `state` (diagnostic) e wrappată în `try/on StateError` (provider-ul poate fi dispus mid-tick).
- Auto-stop folosește guardul `hadPreviousFix` (capturat înainte de `last = pos`) ca primul fix să nu declanșeze geofence-ul de finish.

## Rulare / testare

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerează models.freezed.dart
flutter analyze                                            # 0 issues
flutter test                                               # 38/38
```

> `build_runner` poate emite `E freezed on lib/state_providers.dart:` cu mesaj gol — **non-fatal** (incompatibilitate SDK 3.10 vs analyzer; freezed nu are ce genera acolo). `models.freezed.dart` se regenerează corect; confirmat prin analyze curat + teste pass.

## Teste (`test/`)

- `rally_math_test.dart` — matematica Δ.
- `state_providers_test.dart` — controller + auto-stop (cu fake GPS/device).
- `competition_providers_test.dart` — auto-start in/out geofence, stage viitor, autoStart oprit, persistență, migrare legacy, JSON round-trip metadate (incl. `startDate`/`endDate`), migrare `date` legacy → `startDate`.
- `widget_test.dart` — smoke landscape + portrait fără overflow + viteză țintă cu zecimale (35.9 / 40 curat). Butonul de ghid a fost scos din aserțiuni (nu mai e în cockpit).
- `about_test.dart` — versiune + 3 link-uri nav (ghid, politică de confidențialitate, permisiuni) + pagină `PermissionsScreen` cu 3 rânduri + stare whileInUse/refuzată/GPS oprit + overflow portrait (mock canal `package_info_plus` metodă `getAll` + override `gpsServiceProvider` cu `_FakeGps`).
- `location_disclosure_test.dart` — disclosure o dată → „Continuă" (flag setat) / „Refuză" (flag nesetat → reapare) + prezența link-ului Policy și a notei „opțional".

## TODO înainte de Play Store

- Înlocuiește `kPrivacyPolicyUrl` din `lib/location_disclosure.dart` (placeholder `https://example.com/retrometer/privacy-policy`) cu URL-ul politicii publicate — e o singură sursă folosită în disclosure și pe ecranul Despre.
- Completează **Data Safety form** în Play Console (declară: locație = colectare în-app, nu partajată/vândută).
- Prominent Disclosure e best-practice pentru foreground; devine **obligatoriu** dacă se adaugă `ACCESS_BACKGROUND_LOCATION` (trebuie să declare explicit că e opțional + link Policy + cerere separată de foreground).