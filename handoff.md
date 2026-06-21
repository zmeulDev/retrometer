# Retrometer — Handoff implementare

> Status: **implementat** (21 iun. 2026, actualizat 21 iun. 2026). `flutter analyze` curat (0 issues), `flutter test` 31/31 pass pe host, `flutter build apk --debug` reușește cu noul applicationId. APK-ul a fost verificat end-to-end pe device fizic **A059** (android-arm64, Android 16/API 36, serial `0014515BL000287`): build → install ca `com.zmeul.retrometer` → lansare (`MainActivity` rezolvat, a declanșat dialog de permisiune locație = install fresh), orientare liberă (portrait↔landscape) + viteze țintă cu zecimale (`țintă 35.9`). **A059 este acum curat**: ambele pachete (`com.zmeul.retrometer` și vechiul `com.example.retrometer`) au fost dezinstalate — `pm path` întoarce NOT installed pentru ambele; următoarea lansare va fi un install proaspăt (date `retrometer.*` fresh).
> Mai jos: arhitectura realizată, devierea de la specificație, cum se rulează/testează, apoi **specificația originală** păstrată integral.

## Ce a fost implementat

Aplicația „Rally Computer / trip-meter" pentru raliu de regularitate (BMW Z3, offline, dashboard, dark, blind-touch, 60fps). Codul funcțional, curat, cu izolarea rebuild-urilor cerută. Pe lângă cockpit-ul de bază, are **program de stagii cu auto-start pe geofence de start + auto-stop pe geofence de sosire**, **afișare localitate** (reverse-geocode din GPS) și, de la 21 iun. 2026, **competiții** care grupează stagii și țin metadatele echipei/evenimentului. La introducerea unui stagiu se cunosc: locație start, locație finală (cu geofence), distanță totală, viteză medie țintă/max, timp total alocat.

### Competiții (grupează stagii)

Mai multe stagii formează o **competiție**. O competiție ține: nume, locație (ex. Cluj), dată, pilot, copilot, mașină (ex. BMW Z3), categorie, număr total de echipe, persoană de contact + telefon, cost, și locul curent la general / în categorie (introduse manual pe parcurs, 0 = nesetat). Fiecare competiție are propria listă de stagii (planificate cu auto-start/auto-stop ca înainte). Toate competițiile sunt persistate (`retrometer.competitions`); la prima lansare pe un instalat pre-competiții, vechiul `retrometer.schedule` plat e migrat automat într-o competiție „Importate" (nu se pierde nimic).

UI: butonul 📅 din cockpit deschide **lista de competiții** → tap pe o competiție → **detaliu** cu antet de metadate + bara de status auto-start + lista de stagii (editor de stagiu reutilizat, cu `competitionId` thread-at prin acțiuni). Cockpit-ul arată numele + categoria competiției active (stage-ul care rulează aparține unei competiții planificate) sub localitate. Auto-start-ul a fost refacturat sășteargă stagiile din toate competițiile (flatten) și să marcheze `markStarted(competitionId, stageId)`.

### Stack realizat

- **Flutter 3.38 / Dart 3.10.**
- **Identitate aplicație: `com.zmeul.retrometer`** (applicationId Android + namespace, PRODUCT_BUNDLE_IDENTIFIER iOS/macOS, APPLICATION_ID Linux, CompanyName Windows). Pachetul Kotlin: `android/app/src/main/kotlin/com/zmeul/retrometer/MainActivity.kt`. Redenumit din `com.example.retrometer` pe 21 iun. 2026. Datele persistente (SharedPreferences `retrometer.*`) sunt per-aplicație/per-pachet, deci NU se mută între pachete — o schimbare de applicationId = install fresh (competițiile/stagiile salvate în pachetul vechi nu apar în cel nou). Ambele pachete (`com.zmeul.retrometer` + vechiul `com.example.retrometer`) sunt acum dezinstalate de pe A059.
- **State management: `flutter_riverpod` 2.x — manual, NU codegen.** (Vezi devierea mai jos.)
- **Modele imuabile: `freezed` 2.x** (codegen via `build_runner`).
- Pachete: `geolocator` 13.x (distanță/viteză/geofence), `geocoding` 4.x (reverse + forward geocode), `shared_preferences` 2.x (persistența programului), `wakelock_plus` (ecran aprins), `vibration` (haptic).

### ⚠️ Deviere importantă față de spec: Riverpod manual, nu `riverpod_annotation`

Specificația cerea `riverpod_annotation` (codegen). **Nu se poate** cu SDK-ul curent: lanțul `riverpod_generator → riverpod_analyzer_utils 0.5.9 → custom_lint_core 0.7.1 → analyzer_plugin 0.12.0` livrează un `analyzer_plugin` cu sursă broken (folosește API-ul vechi `Element`, incompatibil cu analyzer 7.x livrat de Flutter 3.38). `build_runner` nu reușește să compileze build script-ul.

Soluția adoptată: **provideri Riverpod scriși manual** (`Notifier`/`AsyncNotifier`/`Provider`, fără `@riverpod`, fără `.g.dart` pentru provideri) + **freezed codegen doar pentru modele** (`source_gen` nu trage `analyzer_plugin`, deci `build_runner` merge). Imuabilitatea, `copyWith`, egalitatea și `select` (pentru izolarea rebuild-urilor) sunt intacte. De revenit când `analyzer_plugin`/`custom_lint_core` primesc o versiune reparată.

### Harta fișierelor

- `lib/models.dart` — `StageConfig`, `StageTelemetry`, `RallyState`, `PlannedStage`, `Competition` (freezed) + enum-urile `StageStatus`, `DeltaBand` + helperi JSON `plannedStageFromJson`/`plannedStagesToJson`/`plannedStagesFromJson`/`competitionsToJson`/`competitionsFromJson`. `PlannedStage` și `Competition` au `toJson` manual (ISO8601 pentru date) și **nu** declară `factory .fromJson` în clasă, ca freezed să nu mai genereze JSON scaffolding care i-ar shadow-ui serializarea. `Competition` grupează `List<PlannedStage>` plus metadate (pilot, copilot, name, location, date, car, category, totalTeams, contactPerson, contactPhone, cost, overallStanding, categoryStanding). Câmpuri comune pe `StageConfig` și `PlannedStage`: `targetAvgSpeed`, `maxSpeedLimit`, `endLatitude`/`endLongitude` (nullable — `null` = fără finish / fără auto-stop), `endGeofenceRadiusM`, `autoStop`, `totalDistanceKm` (0 = nesetat), `allocatedTimeSeconds` (0 = nesetat). `competitionsFromJson`/`plannedStagesFromJson` citesc câmpurile cu fallback la default, ca payload-urile vechi/partial să se încarce fără eroare.
- `lib/rally_math.dart` — matematica pură, testabilă: `idealSeconds`, `deltaSeconds`, `deltaBandFor`.
- `lib/services/gps_service.dart` — wrapper injectabil peste `geolocator` (stream high-accuracy, `distanceBetween`, `checkPermission`/`requestPermission`/`isLocationServiceEnabled`).
- `lib/services/device_service.dart` — wrapper injectabil pentru wakelock + haptic (pentru testare fără canale de platformă).
- `lib/state_providers.dart` — `StageController` (`startStage`/`startStageFromPlan`/`stopStage`/`resetStage`/`updateConfig`/`adjustDistance`, acumulare distanță+viteză din GPS) + providerii `clockTick`, `elapsedSeconds`, `deltaSeconds`, `deltaBand`, `isOverSpeed`, `localityProvider` (reverse-geocode throttled la ~1 km cell) — toți cu `select` îngust. `startStageFromPlan` copiază noile câmpuri (end coords, rază, autoStop, distanță totală, timp alocat) în `StageConfig`. Listener-ul GPS (acum `async`) face **auto-stop**: după cel puțin 2 fix-uri (ca primul fix de la start să nu declanșeze), dacă `autoStop` și finish setat → `distanceBetween(pos, end)`; la `≤ endGeofenceRadiusM` → `stopStage()` + haptic.
- `lib/competition_providers.dart` — `competitionsProvider` (`AsyncNotifier<List<Competition>>`, hidratat + persistat în `retrometer.competitions`; `addCompetition`/`updateCompetition`/`removeCompetition`/`addStage`/`updateStage`/`removeStage`/`markStarted(competitionId, stageId)`; la primul build, dacă lipsesc competițiile dar există vechiul `retrometer.schedule`, migrează stagii într-o competiție „Importate"). `activeCompetitionProvider` (găsește competiția căreia îi aparține stage-ul activ, după `config.id`). `ScheduledStage` = pereche `(Competition, PlannedStage)` pentru iterare flatten. `autoStartMonitorProvider` (`Notifier<AutoStartStatus>`, mutat aici din fostul `schedule_providers`): Timer 5s + tick imediat, doar când statusul `!= inProgress`; **flattenează** stage-urile din toate competițiile, caută cele due (`0 ≤ now − startTime ≤ 10 min`, `autoStart` true, `started` false), colectează cel mai precis fix GPS în 12s, verifică geofence-ul cu `distanceBetween ≤ geofenceRadiusM`, pornește stage-ul + `markStarted(competition.id, stage.id)`; ține wakelock cât timp e un stage pending.
- `lib/competition_view.dart` — `CompetitionsScreen` (lista de competiții: tile cu nume, locație, dată, categorie, mașină, nr. stagii, loc general/categorie, + FAB add) → `CompetitionDetailScreen` (antet cu toate metadatele echipei/evenimentului + bara de status auto-start + lista de stagii sortate + edit/șterge competiție + FAB add stage). `_CompetitionEditor` (sheet) pentru toate câmpurile competiției (nume, locație, dată, pilot, copilot, mașină, categorie, total echipe, contact+telefon, cost, loc general/categorie). Editorul de stagii (`_StageEditor`/`_StageDraft`/`_StageTile`/`_showStageEditor`) e mutat aici din fostul `schedule_view` și primește `competitionId`; `markStarted`/`removeStage` operează pe competiția corectă. `_NumberField`/`_CoordField`/`_DateTimeField`/`_DateField` reutilizate.
- `lib/cockpit_view.dart` — ecranul cockpit: 3 zone `Column` 15/45/40, `Consumer` atomici + `select` + `RepaintBoundary` pe zona Δ și pe distanță; gesture-uri blind-touch stânga/dreapta vizibile (`−10 m` / `+10 m`, tap `±0.01 km`, long-press `±0.1`) cu haptic; alertă over-speed pulsatorie; bara de sus cu localitate + **nume+categorie competiție activă** + elapsed + buton 📅 (competiții) + buton ajutor + controale stage; sheet de configurare (care acum păstrează finish/distanță/timpul prin `copyWith`, nu le mai dropează); `ref.watch(autoStartMonitorProvider)` ține monitorul viu. **Responsive:** bara de sus se rearanjează — pe ecran îngust + înalt (portrait telefon) devine 2 rânduri (info sus, controale jos, etichete păstrate); pe ecran îngust + scurt (split-view) rămâne 1 rând cu controale icon-only; pe lat rămâne 1 rând normal (`LayoutBuilder`, prag 520 px). Zonele Δ/distanță folosesc `FittedBox` deci scalaează pe orice dimensiune. Vitezele țintă/max se introduc cu zecimale (`_NumberField` cu `decimals: 1`) și se afișează cu o zecimală doar când e fracționar (`_fmtSpeed`: 40, 35.9).
- `lib/guide_view.dart` — ghidul de utilizare (full-screen, scrollabil) cu mockup schematic + secțiuni (pornire, indicator Δ, calibrare borne, program stagii, altele) + `maybeShowOnboarding` (prima rulare, flag în SharedPreferences).
- `lib/main.dart` — `ProviderScope`, `MaterialApp` dark. **Orientare liberă**: `setPreferredOrientations(DeviceOrientation.values)` — aplicabilă în portrait sau landscape, pe telefon sau tabletă (înainte forța landscape).
- Permisiuni: `android/app/src/main/AndroidManifest.xml` (FINE/COARSE location, VIBRATE, WAKE_LOCK); `ios/Runner/Info.plist` (`NSLocationWhenInUseUsageDescription`). Fără background location (conform deciziei: doar foreground + wakelock).
- `test/` — `rally_math_test.dart`, `state_providers_test.dart` (cu fake GPS/device; inclusiv auto-stop trage/nu trage), `competition_providers_test.dart` (auto-start in/out geofence, stage viitor, autoStart oprit, persistență competiții+stagii, **migrare legacy schedule**, **JSON round-trip metadate**), `widget_test.dart` (smoke landscape + **smoke portrait fără overflow** + **viteză țintă cu zecimale 35.9** + **40 curat, nu 40.0**).

### Matematica domeniului (în `lib/rally_math.dart`)

- `t_ideal = distance_km / target_kmh × 3600` (secunde).
- `Δt = t_real − t_ideal` (`t_real` = elapsed wall-clock cu rezoluție ms).
- `Δ < 0` ⇒ **avans** (roșu); `Δ > 0` ⇒ **întârziere** (galben); `|Δ| ≤ 1s` ⇒ **la timp** (verde).
- Distanța se acumulează din stream-ul GPS (1Hz, `distanceBetween` între fix-uri consecutive → km). `adjustDistance(±0.01)` = ±10 m pentru sincronizarea cu bornele.

### Competiții + stagii + auto-start + auto-stop

- **Planificare:** crew-ul pregătește dimineața competițiile și lista de stagii (nume, oră start, locație start cu geofence + rază, **locație finală cu geofence + rază**, viteză țintă/max per stage, **distanță totală**, **timp total alocat (MM:SS)**, toggle auto-start, toggle auto-stop). Se salvează în SharedPreferences (`retrometer.competitions`) — supraviețuiește restarturilor.
- **Auto-start:** `AutoStartMonitor` poll-ează la 5s (+ tick imediat) cât timp **nu rulează niciun stage** (status `idle` **sau** `completed` — după ce un stage se termină, următorul programat pornește singur). **Flattenează** stage-urile din toate competițiile; un stage due = `now ≥ startTime`, `now − startTime ≤ 10 min` (grace, ca să nu pornească stage-uri ratate pe lansare târzie), `autoStart` true, `started` false. Pornește stage-ul cu `startStageFromPlan` dacă distanța până la coordonate ≤ `geofenceRadiusM`, apoi `markStarted(competitionId, stageId)` ca să nu re-declanșeze.
- **Auto-stop:** în `StageController._subscribeGps`, listener-ul GPS verifică la fiecare fix (după cel puțin 2 fix-uri, ca primul fix de la start să nu declanșeze) dacă `autoStop` și finish setat (`endLatitude`/`endLongitude` non-null); `distanceBetween(pos, end) ≤ endGeofenceRadiusM` → `stopStage()` + haptic. Simetric cu auto-start pe geofence-ul de start.
- **Fix GPS robust:** colectează fix-uri timp de 12s și păstrează cel mai precis (preferă `accuracy ≤ 50 m`); primul fix la GPS rece poate fi cu kilometri în afara geofence-ului → verificarea cu un fix bun evită pornirile ratate silențioase. Guard `_busy` interzice suprapunerea de tick-uri (5s pol vs. 12s colectare).
- **Wakelock cât timp e pending:** monitorul ține ecranul aprins cât există cel puțin un stage pending auto-start (până la 24h în viitor), ca timer-ul să nu fie suspendat de OS (app foreground-only — fără background service, OS-ul suspendă timer-ele când ecranul se blochează). Trade-off: baterie (telefonul e pe bord, încărcat).
- **Diagnostic vizibil:** `autoStartMonitorProvider` expune `AutoStartStatus` (ultimul mesaj, ora verificării, următorul stage, precizia fix-ului, `distanță X m / rază Y m`), afișat într-o bară de status pe ecranul de detaliu al competiției — ca crew-ul să vadă **de ce** a pornit sau nu (`așteptare` / `în afara geofence-ului` / `nu am primit fix GPS` / `permisiune refuzată` / `pornesc <numă>…`).
- **Note de implementare:**
  - `_tick` rezolvă toate dependențele (`competitionsProvider.notifier`, `stageControllerProvider.notifier`, `deviceServiceProvider`, `gpsServiceProvider`) la început, înainte de orice `await`. Altfel, schimbarea de status din `startStageFromPlan` reconstruiește monitorul (îl watch-uiește) și invalidează `ref`-ul în plin async tick — bug real descoperit prin teste (markStarted nu se mai apela).
  - Setarea `state` (diagnostic) e wrappată în `try/on StateError` căci provider-ul poate fi dispus mid-tick.
  - Bug istoric: monitorul se înarma doar pe `idle`; după un START/STOP statusul rămânea `completed` → monitorul adormea → niciun stage ulterior nu mai pornea automat. Fix: armare pe `status != inProgress`.
  - Listener-ul GPS e `async` (pentru `await haptic()` în auto-stop); auto-stop folosește guardul `hadPreviousFix` (capturat înainte de `last = pos`) ca primul fix să nu declanșeze geofence-ul de finish.

### Rulare / testare

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerează models.freezed.dart
flutter analyze                                            # curat
flutter test                                               # 31/31
flutter run -d 0014515BL000287                             # pe A059 (GPS)
flutter test -d 0014515BL000287                            # 31/31 pe device fizic (opțional; rebuild-uiește harness-ul)
```

> Notă: la `build_runner` poate apărea `E freezed on lib/state_providers.dart:` cu mesaj gol — eroare non-fatală (incompatibilitate SDK 3.10 vs analyzer 3.9; freezed nu are ce genera acolo). `models.freezed.dart` se regenerează corect; confirmat prin `flutter analyze` curat + teste pass.

### Verificare manuală rămasă (pe device fizic)

- **[verificat pe A059]** Rotația telefonului portrait↔landscape rearanjează bara de sus (2 rânduri pe portrait, 1 rând pe lat) fără overflow; zonele Δ/distanță scalaează prin `FittedBox`. Viteza țintă introdusă cu zecimale (ex. 35.9) se afișează corect în cockpit; întregii rămân curați (40, nu 40.0).
- Permite permisiunea de locație; ecranul rămâne aprins (wakelock).
- Setează țintă 40 km/h, START; distanța/viteza se actualizează, Δ schimbă culoarea; localitatea apare sus.
- Tap stânga/dreapta ⇒ ±0.01 km + haptic; long-press ⇒ ±0.1.
- Viteza > limita maximă ⇒ alertă over-speed.
- Deschide 📅 → **lista competițiilor**; apasă +, completează o competiție (nume „Raliul Clujului", locație Cluj, pilot/copilot, mașină BMW Z3, categorie, total echipe, contact, cost, loc general/categorie) → salvează; tap pe ea → detaliu.
- În detaliu, adaugă un stage cu **Locația mea** (start) + ora peste ~2 min + auto-start; bara de status ar trebui să treacă prin `așteptare` → `pornesc <numă>…` când ajunge ora (dacă arată `în afara geofence-ului` / `nu am primit fix GPS` / `permisiune refuzată`, alea sunt cauzele). Stage-ul pornit ar trebui să facă și numele+categoria competiției să apară în bara de sus a cockpit-ului.
- La același stage setează **locație finală** (o destinație apropiată, rază 200 m) + **distanță totală** + **timp alocat MM:SS** + auto-stop; ▶ pornește, conduce spre finish — la intrarea în geofence-ul de sosire stagiu se oprește singur (status `completed`) + haptic. Verifică că tile-ul afișează finish/distanță/timp.
- Pe un instalat vechi (cu `retrometer.schedule` populat): prima lansare ar trebui să migreze automat stagii într-o competiție „Importate" (verifică în lista competițiilor).
- Verifică izolarea repaint-urilor cu DevTools (Repaint Rainbow).

### Decizii confirmate

Riverpod codegen + freezed · întârziere = galben · un singur stage activ configurabil din UI · doar foreground + wakelock (fără background location) · potrivire locație prin **geofence (coord + rază)** · **viteză țintă/max per stage, cu zecimale** (ex. 35.9, nu doar întregi) · programul de stagii **persistat** (plan dimineața, conduci mai târziu) · **locație finală cu geofence + auto-stop** la sosire · **distanță totală + timp total alocat** câmpuri introduse manual (independent, nu derivate) · **stagii grupate în competiții** (metadate echipaj/eveniment: pilot, copilot, nume, locație, total echipe, categorie, loc general/categorie, contact, cost, mașină) · **migrare automată** a vechiului schedule plat într-o competiție „Importate" · **orientare liberă** (portrait sau landscape) + **layout responsive** (bara de sus 2 rânduri pe portrait telefon, 1 rând pe lat; Δ/distanță scalaează prin `FittedBox`).

---

# Specificația originală (prompt, păstrat integral)

Iată promptul detaliat, formatat în Markdown, gata să fie copiat și introdus într-un alt asistent AI (sau într-o sesiune nouă de codare) pentru a genera codul aplicației. L-am structurat tehnic, ca de la dezvoltator la dezvoltator, pentru a obține un cod curat, performant și optimizat.

***Copiază textul de mai jos:***

---

# System Prompt: Dezvoltare Aplicație Flutter pentru Motorsport (Regularity Rally)

Ești un dezvoltator Senior Flutter, expert în arhitecturi reactive (Riverpod), state management și optimizarea rendering-ului la 60fps (evitarea rebuild-urilor inutile).

Trebuie să generezi codul pentru o aplicație de tip „Rally Computer” / „Digital Tripmeter” pentru un raliu de regularitate auto. Aplicația va rula offline pe un telefon montat pe bordul unei mașini sport (BMW Z3), deci necesită un UX de tip „blind-touch”, text cu contrast ridicat (Dark Mode) și o performanță perfectă a UI-ului pentru a nu consuma bateria/supraîncălzi dispozitivul.

## 1. Stack Tehnologic Obligatoriu

* **Framework:** Flutter (versiune recentă).
* **State Management:** `flutter_riverpod` (sau `riverpod_annotation`). Utilizare strictă a claselor imuabile (`freezed` sau `equatable`).
* **Pachete principale:** `geolocator` (pentru distanță și viteză), `wakelock_plus` (pentru a ține ecranul aprins), `vibration` (feedback haptic).

## 2. Logica Domeniului (Matematica Raliului)

Scopul aplicației este să calculeze în timp real avansul sau întârzierea (Indicatorul DELTA) față de un timp ideal.

* **Timpul Ideal ($t_{ideal}$):** Distanța curentă împărțită la viteza medie impusă.
* **Indicatorul Delta ($\Delta t$):** $t_{real} - t_{ideal}$.
* Dacă $\Delta t < 0$: Echipajul este în AVANS (merge prea repede). UI-ul devine **Roșu**.
* Dacă $\Delta t > 0$: Echipajul este în ÎNTÂRZIERE (merge prea încet). UI-ul devine **Galben/Albastru**.
* Dacă $\Delta t \approx 0$ (marjă de $\pm 1$ sec): Perfect. UI-ul este **Verde**.



## 3. Modele de Date Necesare

Creează următoarea structură pentru state management:

1. **StageConfig (Imuabil):** `id`, `name`, `targetAvgSpeed` (km/h), `maxSpeedLimit` (km/h).
2. **StageTelemetry:** `startTime` (DateTime), `currentDistance` (km), `currentSpeed` (km/h), `status` (Enum: idle, inProgress, completed).
3. **Logica de Business (Controller/Notifier):** Trebuie să gestioneze fluxul la 1Hz de la `Geolocator.getPositionStream()`, actualizând `currentDistance`. De asemenea, va expune metode pentru:
* `startStage()`
* `adjustDistance(double offset)` (Ex: pentru a adăuga/scădea manual 0.01 km (10m) pentru sincronizarea cu bornele fizice).



## 4. Arhitectura UI și Optimizarea Rendering-ului (CRITIC)

Aplicația trebuie să izoleze rebuild-urile. Nu accept un singur `Consumer` care să randeze tot ecranul de 60 de ori pe secundă.
Folosește **Atomic Consumers** (ex: `ref.watch(provider.select((state) => state.distance))`), layout-uri statice cu `const` și `RepaintBoundary` pentru zonele care se modifică frecvent.

### Structura Ecranului Principal (Cockpit View)

Construiește un ecran împărțit strict în 3 zone, folosind `Column` și `Expanded`:

* **Zona Superioară (15% - Info):** Widgeturi statice care afișează `name`, `targetAvgSpeed` și `elapsedTime`.
* **Zona Centrală (45% - Indicatorul DELTA):** * Protejată de `RepaintBoundary`.
* Un text uriaș, centrat, care afișează valoarea lui $\Delta t$ în secunde (ex: `- 01.4`).
* Culoarea textului/fundalului se modifică conform logicii de avans/întârziere.
* O alertă vizuală dacă `currentSpeed > maxSpeedLimit`.


* **Zona Inferioară (40% - Tripmeter & Gestures):**
* În centru: `currentDistance` afișat masiv (ex: `14.56 km`). Protejat de `RepaintBoundary`.
* Pe partea Stângă (30% lățime): Un `GestureDetector` invizibil uriaș care apelează `adjustDistance(-0.01)` și emite o vibrație.
* Pe partea Dreaptă (30% lățime): Un `GestureDetector` invizibil uriaș care apelează `adjustDistance(+0.01)` și emite o vibrație.



## Sarcina Ta

Te rog să generezi codul complet, funcțional și curat. Împarte codul generat logic (ex: `models.dart`, `state_providers.dart`, `cockpit_view.dart`). Asigură-te că matematica pentru calculul timpului ideal și al variabilei $\Delta$ manipulează corect unitățile de măsură (km/h vs secunde).

Începe direct cu implementarea claselor de model (Config, Telemetry) și controller-ului Riverpod.