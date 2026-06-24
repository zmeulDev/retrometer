import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'cockpit/auto_start_prompt_listener.dart';
import 'cockpit/stage_finish_prompt_listener.dart';
import 'cockpit_view.dart';
import 'navigator_key.dart';
import 'services/license_registry.dart';
import 'services/telemetry_logger.dart';
import 'theme/retrometer_theme.dart';
import 'theme/theme_mode_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLicenseRegistry.register();
  // Usable in any orientation (portrait or landscape) on phones and tablets.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  // Hydrate the persisted theme mode before the first frame so the app never
  // flashes the wrong theme. A standalone container owns the provider; the
  // same container is reused by the app so the loaded mode is visible.
  //
  // The telemetry logger writes a durable JSONL log of every GPS fix and
  // stage/auto-start/finish event next to `retrometer.db` (pull it via
  // `adb run-as com.zmeul.retrometer cat databases/retrometer_telemetry.log`
  // and summarize with `dart run tool/analyze_telemetry_log.dart`). Always-on
  // for real-track diagnostics — gate off via a flag before Play Store.
  final container = ProviderContainer(
    overrides: [
      telemetryLoggerProvider.overrideWithValue(
        FileTelemetryLogger(
          pathProvider: () async =>
              path.join(await getDatabasesPath(), 'retrometer_telemetry.log'),
        ),
      ),
    ],
  );
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
      // Host the auto-start + stage-finish prompt listeners above the root
      // navigator so their dialogs can fire from any pushed route
      // (Competitions/About/Guide), not just the cockpit. The listeners render
      // `SizedBox.shrink`, so they have zero layout impact — they only need to
      // stay mounted to keep their manual subscriptions alive.
      builder: (context, child) => Stack(
        children: [
          child!,
          const AutoStartPromptListener(),
          const StageFinishPromptListener(),
        ],
      ),
      home: const CockpitView(),
    );
  }
}