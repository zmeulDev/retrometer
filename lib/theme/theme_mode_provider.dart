import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manual Riverpod (no codegen — see the project note about the broken
/// `riverpod_generator → analyzer_plugin` chain). Mirrors the
/// `CompetitionNotifier` hydration pattern.
const String _kThemeModeKey = 'retrometer.theme_mode';

/// The app's theme mode. Defaults to **night** (`ThemeMode.dark`); the user
/// toggles day/night from the About screen. The choice is persisted to
/// `SharedPreferences` so it survives restarts.
///
/// `build()` returns the dark default synchronously so the very first frame
/// is never unstyled; `main()` calls [load] before `runApp` to swap in the
/// persisted choice (if any) before the UI is shown.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  /// Hydrate the persisted choice. Called once from `main()` before the app
  /// runs; a no-op when the key is absent (fresh install stays on night).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeModeKey);
    if (stored == 'day') {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kThemeModeKey,
      mode == ThemeMode.light ? 'day' : 'night',
    );
  }

  Future<void> toggle() async =>
      setMode(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);