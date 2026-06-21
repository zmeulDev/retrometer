import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cockpit_view.dart';
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
      home: const CockpitView(),
    );
  }
}