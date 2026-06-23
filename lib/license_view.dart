import 'package:flutter/material.dart';

import 'services/license_registry.dart';
import 'theme/retrometer_theme.dart';
import 'widgets/cards.dart';
import 'widgets/info_widgets.dart';

/// Full-screen "Licențe open-source" — drains the licenses registered with
/// [AppLicenseRegistry] (the bundled OFL-1.1 font texts plus anything Flutter
/// itself contributes) and renders each package's text in a scrollable
/// monospace block.
///
/// Replaces the stock [showLicensePage] so the screen matches the restomod
/// dark theme (SurfaceCard + the app's typography) instead of the default
/// Material license page chrome.
class LicensesScreen extends StatefulWidget {
  const LicensesScreen({super.key});

  @override
  State<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends State<LicensesScreen> {
  late final Future<List<({String package, String text})>> _licenses =
      AppLicenseRegistry.collect();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Licențe open-source')),
      body: SafeArea(
        child: FutureBuilder<List<({String package, String text})>>(
          future: _licenses,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.colors.primary,
                ),
              );
            }
            final licenses = snapshot.data ?? const [];
            if (licenses.isEmpty) {
              return const EmptyState(
                icon: Icons.description_outlined,
                message: 'Nicio licență înregistrată.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                RetrometerSpacing.s16,
                RetrometerSpacing.s16,
                RetrometerSpacing.s16,
                RetrometerSpacing.s32,
              ),
              itemCount: licenses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final license = licenses[index];
                return _LicenseCard(
                  package: license.package,
                  text: license.text,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// A single license: the package name as a header above a scrollable
/// monospace block holding the license text. The text is constrained to a
/// bounded height so long OFL bodies don't take over the screen — the block
/// scrolls independently within its card.
class _LicenseCard extends StatelessWidget {
  const _LicenseCard({required this.package, required this.text});

  final String package;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        RetrometerSpacing.s16,
        RetrometerSpacing.s12,
        RetrometerSpacing.s16,
        RetrometerSpacing.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(package, style: context.text.tileTitle),
          const SizedBox(height: RetrometerSpacing.s8),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: context.colors.surfaceHeader,
              borderRadius: BorderRadius.circular(RetrometerRadii.field),
              border: Border.all(color: context.colors.divider),
            ),
            padding: const EdgeInsets.all(RetrometerSpacing.s12),
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 12,
                  height: 1.4,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}