import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper around Flutter's [LicenseRegistry] — a `final` class that
/// cannot be subclassed, so this consumes it (re-exposes its stream) rather
/// than replacing it.
///
/// Centralizing font-license registration here keeps `main.dart` free of
/// `rootBundle`/`LicenseEntry` plumbing, and gives the licenses screen a
/// single typed entry point to drain the registered licenses for display.
class AppLicenseRegistry {
  const AppLicenseRegistry._();

  /// Registers the bundled font OFL-1.1 license texts (Roboto, RobotoMono,
  /// SairaStencil) with Flutter's [LicenseRegistry] so they appear in the
  /// licenses stream consumed by [LicensesScreen].
  ///
  /// Mirrors the registration previously inlined in `main.dart`'s
  /// `_registerFontLicenses()`; the font names and asset paths are unchanged.
  static Future<void> register() async {
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

  /// The live stream of registered license entries, as exposed by Flutter's
  /// [LicenseRegistry]. Consumers (e.g. [collect]) drain this stream.
  static Stream<LicenseEntry> get licenses => LicenseRegistry.licenses;

  /// Drains the [licenses] stream and groups the entries by package name,
  /// producing one record per package with its concatenated license text.
  ///
  /// A single [LicenseEntry] may declare multiple packages, and the same
  /// package may recur across entries (e.g. several font families shipping
  /// under the same license); such recurrences are merged into a single
  /// record. The returned list preserves package insertion order. Robust to
  /// the stream completing (finite or empty) — always resolves with a list.
  static Future<List<({String package, String text})>> collect() async {
    final byPackage = <String, List<String>>{};
    final order = <String>[];
    await for (final entry in licenses) {
      final text = entry.paragraphs.map((p) => p.text).join('\n\n');
      for (final pkg in entry.packages) {
        if (!byPackage.containsKey(pkg)) {
          order.add(pkg);
          byPackage[pkg] = <String>[];
        }
        if (text.isNotEmpty) {
          byPackage[pkg]!.add(text);
        }
      }
    }
    return [
      for (final pkg in order) (package: pkg, text: byPackage[pkg]!.join('\n\n')),
    ];
  }
}