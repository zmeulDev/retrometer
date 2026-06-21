# Retrometer — Handoff

> **Stare:** implementat. `flutter analyze` 0 issues · `flutter test` 37/37 · `flutter build apk --debug` OK.
> Identitate: `com.zmeul.retrometer` pe toate platformele. Schimbarea de applicationId = install fresh (SharedPreferences `retrometer.*` NU se mută între pachete).

## Ce este

Trip-meter / „Rally Computer" pentru raliu de regularitate (BMW Z3). Offline, dark, blind-touch, 60fps, cu izolarea rebuild-urilor prin `select` + `RepaintBoundary`.

Funcționalități:
- **Cockpit** — indicator Δ (avans/întârziere/la timp), distanță acumulată din GPS, ajustare blind-touch (±0.01 / ±0.1 km), alertă over-speed, localitate (reverse-geocode), viteză țintă/max cu zecimale.
- **Competiții** — grupează stagii + metadate echipaj/eveniment (pilot, copilot, mașină, categorie, total echipe, contact, cost, loc general/categorie). Persistate în `retrometer.competitions`; vechiul `retrometer.schedule` plat e migrat automat într-o competiție „Importate".
- **Program de stagii** — auto-start pe geofence de start + auto-stop pe geofence de sosire; distanță totală + timp alocat introduse manual.
- **Ecran „Despre"** — versiune (`package_info_plus`), link ghid, secțiune de permisiuni cu stare live.
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

- `lib/models.dart` — `StageConfig`, `StageTelemetry`, `RallyState`, `PlannedStage`, `Competition` (freezed) + `StageStatus`, `DeltaBand` + helperi JSON. `PlannedStage`/`Competition` au `toJson` manual (ISO8601) și NU declară `factory .fromJson` (ca freezed să nu shadow-uie serializarea). Câmpuri comune pe `StageConfig`/`PlannedStage`: `targetAvgSpeed`, `maxSpeedLimit`, `endLatitude`/`endLongitude` (nullable = fără finish/auto-stop), `endGeofenceRadiusM`, `autoStop`, `totalDistanceKm`, `allocatedTimeSeconds` (0 = nesetat). JSON-urile citesc cu fallback la default (payload-uri vechi/parțiale se încarcă fără eroare).
- `lib/rally_math.dart` — `idealSeconds`, `deltaSeconds`, `deltaBandFor` (pur, testabil).
- `lib/services/gps_service.dart` — wrapper injectabil peste `geolocator` (stream, `distanceBetween`, `checkPermission`/`requestPermission`/`isLocationServiceEnabled`).
- `lib/services/device_service.dart` — wrapper injectabil wakelock + haptic (pentru teste fără canale de platformă).
- `lib/state_providers.dart` — `StageController` (`startStage`/`startStageFromPlan`/`stopStage`/`resetStage`/`updateConfig`/`adjustDistance`, acumulare distanță+viteză din GPS) + providerii `clockTick`, `elapsedSeconds`, `deltaSeconds`, `deltaBand`, `isOverSpeed`, `localityProvider` (toți cu `select` îngust). Listener-ul GPS (async) face **auto-stop**: după ≥2 fix-uri, dacă `autoStop` + finish setat → `distanceBetween(pos, end) ≤ endGeofenceRadiusM` → `stopStage()` + haptic.
- `lib/competition_providers.dart` — `competitionsProvider` (`AsyncNotifier<List<Competition>>`, hidratat+persistat în `retrometer.competitions`; CRUD competiții/stagii + `markStarted`), `activeCompetitionProvider`, `ScheduledStage` = `(Competition, PlannedStage)` (flatten), `autoStartMonitorProvider` (`Notifier<AutoStartStatus>`). Detalii auto-start mai jos.
- `lib/competition_view.dart` — `CompetitionsScreen` (listă) → `CompetitionDetailScreen` (antet metadate + bara status auto-start + listă stagii). `_CompetitionEditor` (sheet). Editorul de stagii (`_StageEditor`/`_StageDraft`/`_StageTile`) primește `competitionId`. `_NumberField`/`_CoordField`/`_DateTimeField`/`_DateField` reutilizate. „Locația mea" (start/finish) cer locația, precedate de Prominent Disclosure.
- `lib/cockpit_view.dart` — 3 zone `Column` 15/45/40, `Consumer` atomici + `select` + `RepaintBoundary` pe Δ și distanță; gesture-uri blind-touch stânga/dreapta (`−10 m`/`+10 m`, tap `±0.01`, long-press `±0.1`) + haptic; alertă over-speed; bara de sus: localitate + nume+categorie competiție activă + elapsed + buton 📅 (competiții) + buton ajutor + buton ℹ (Despre) + controale stage; sheet de configurare (păstrează finish/distanță/timpul via `copyWith`); `ref.watch(autoStartMonitorProvider)` ține monitorul viu. **START** e async: `maybeShowLocationDisclosure(context)` înainte de `startStage()`. Responsive: 2 rânduri pe portrait telefon, 1 rând icon-only pe split-view, 1 rând pe lat (`LayoutBuilder`, prag 520 px); Δ/distanță scalaează prin `FittedBox`; viteze cu `_fmtSpeed` (40, 35.9).
- `lib/guide_view.dart` — ghid full-screen + `maybeShowOnboarding` (flag `retrometer.onboarded`).
- `lib/about_view.dart` — `ConsumerStatefulWidget`: antet + badge versiune (`package_info_plus`, FutureBuilder) + link ghid (→ `GuideScreen`) + secțiune „Permisiuni" (locație interogată live via `gpsServiceProvider`; vibrație + wakelock statice ca permisiuni normale). `_PermStatus`/`_StatusChip`/`_PermissionRow`.
- `lib/location_disclosure.dart` — `maybeShowLocationDisclosure(BuildContext)`: dialog `AlertDialog` (`barrierDismissible: false`) afișat o dată (flag `retrometer.location_disclosure_shown`) înainte de prima cerere de locație; explică scopul, declară prim-plan + fără partajare, notează că e **opțional**, link „Vezi Politica de confidențialitate" (`url_launcher`, `_kPrivacyPolicyUrl` **TODO: înlocuiește cu URL-ul real**); „Continuă"=`true` (flag setat) / „Refuză"=`false` (flag NU se setează → reapare). Guard `context.mounted`. Apelat din cockpit START + cele 2 „Locația mea".
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
flutter test                                               # 37/37
```

> `build_runner` poate emite `E freezed on lib/state_providers.dart:` cu mesaj gol — **non-fatal** (incompatibilitate SDK 3.10 vs analyzer; freezed nu are ce genera acolo). `models.freezed.dart` se regenerează corect; confirmat prin analyze curat + teste pass.

## Teste (`test/`)

- `rally_math_test.dart` — matematica Δ.
- `state_providers_test.dart` — controller + auto-stop (cu fake GPS/device).
- `competition_providers_test.dart` — auto-start in/out geofence, stage viitor, autoStart oprit, persistență, migrare legacy, JSON round-trip metadate.
- `widget_test.dart` — smoke landscape + portrait fără overflow + viteză țintă cu zecimale (35.9 / 40 curat).
- `about_test.dart` — versiune + link ghid + 3 rânduri permisiuni + stare whileInUse/refuzată/GPS oprit + overflow portrait (mock canal `package_info_plus` metodă `getAll` + override `gpsServiceProvider` cu `_FakeGps`).
- `location_disclosure_test.dart` — disclosure o dată → „Continuă" (flag setat) / „Refuză" (flag nesetat → reapare) + prezența link-ului Policy și a notei „opțional".

## TODO înainte de Play Store

- Înlocuiește `_kPrivacyPolicyUrl` (placeholder `https://example.com/retrometer/privacy-policy`) cu URL-ul politicii publicate.
- Completează **Data Safety form** în Play Console (declară: locație = colectare în-app, nu partajată/vândută).
- Prominent Disclosure e best-practice pentru foreground; devine **obligatoriu** dacă se adaugă `ACCESS_BACKGROUND_LOCATION` (trebuie să declare explicit că e opțional + link Policy + cerere separată de foreground).