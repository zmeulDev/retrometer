import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cockpit/auto_start_prompt_listener.dart';
import 'cockpit_view.dart';
import 'navigator_key.dart';
import 'theme/retrometer_theme.dart';
import 'theme/theme_mode_provider.dart';

/// Registers the bundled font OFL-1.1 license texts with Flutter's license
/// registry so they appear in the system `LicensePage` reachable from
/// About → "Licențe open-source".
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Roboto'],
      await rootBundle.loadString('assets/fonts/licenses/Roboto-OFL.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['RobotoMono'],
      await rootBundle.loadString('assets/fonts/licenses/RobotoMono-OFL.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const ['SairaStencil'],
      await rootBundle.loadString('assets/fonts/licenses/SairaStencil-OFL.txt'),
    );
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  // Usable in any orientation (portrait or landscape) on phones and tablets.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  // Hydrate the persisted theme mode before the first frame so the app never
  // flashes the wrong theme. A standalone container owns the provider; the
  // same container is reused by the app so the loaded mode is visible.
  final container = ProviderContainer();
  await container.read(themeModeProvider.notifier).load();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RetrometerApp(),
    ),
  );
}

class RetrometerApp extends ConsumerWidget {
  const RetrometerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    // Keep the system bar legible against whichever background is active.
    SystemChrome.setSystemUIOverlayStyle(
      mode == ThemeMode.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
    );
    return MaterialApp(
      title: 'Retrometer',
      debugShowCheckedModeBanner: false,
      theme: retrometerLightTheme(),
      darkTheme: retrometerTheme(),
      themeMode: mode,
      // Key for the root navigator so the auto-start prompt listener (hosted
      // in `builder` as a sibling of the navigator, outside its subtree) can
      // push its dialog without a Navigator ancestor in its own context.
      navigatorKey: rootNavigatorKey,
      // Host the auto-start prompt listener above the root navigator so its
      // dialog can fire from any pushed route (Competitions/About/Guide), not
      // just the cockpit. The listener renders `SizedBox.shrink`, so it has
      // zero layout impact — it only needs to stay mounted to keep its manual
      // subscription alive.
      builder: (context, child) => Stack(
        children: [child!, const AutoStartPromptListener()],
      ),
      home: const CockpitView(),
    );
  }
}