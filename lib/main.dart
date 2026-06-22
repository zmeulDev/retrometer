import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cockpit/auto_start_prompt_listener.dart';
import 'cockpit_view.dart';
import 'navigator_key.dart';
import 'theme/retrometer_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Usable in any orientation (portrait or landscape) on phones and tablets;
  // keep the bar dark for high contrast on a dashboard mount.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const ProviderScope(child: RetrometerApp()));
}

class RetrometerApp extends StatelessWidget {
  const RetrometerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retrometer',
      debugShowCheckedModeBanner: false,
      theme: retrometerTheme(),
      // Key for the root navigator so the auto-start prompt listener (hosted in
      // `builder` as a sibling of the navigator, outside its subtree) can push
      // its dialog without a Navigator ancestor in its own context.
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