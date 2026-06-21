import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'guide_view.dart';
import 'location_disclosure.dart';
import 'services/gps_service.dart';
import 'theme/retrometer_theme.dart';

/// Full-screen "Despre aplicație" — app name, version (from package_info_plus),
/// and links to the user guide, the privacy policy, and the permissions page.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  // Resolved once; the builder shows a fallback while it loads.
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Despre aplicație')),
      body: SafeArea(
        child: FutureBuilder<PackageInfo>(
          future: _info,
          builder: (context, snapshot) {
            final info = snapshot.data;
            final loading = snapshot.connectionState != ConnectionState.done;
            final version = (info?.version.isNotEmpty ?? false) ? info!.version : '—';
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
              children: [
                _AppHeader(loading: loading),
                const SizedBox(height: 28),
                _VersionBadge(version: version),
                const SizedBox(height: 28),
                _NavRow(
                  icon: Icons.menu_book,
                  label: 'Ghid de utilizare',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GuideScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _NavRow(
                  icon: Icons.privacy_tip,
                  label: 'Politică de confidențialitate',
                  onTap: () => launchUrl(Uri.parse(kPrivacyPolicyUrl)),
                ),
                const SizedBox(height: 12),
                _NavRow(
                  icon: Icons.lock_outline,
                  label: 'Permisiuni',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PermissionsScreen(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Full-screen list of the permissions the app uses with their current state.
///
/// The location permission is queried live through the injectable [GpsService]
/// (so tests can override it); vibration and wakelock are normal permissions
/// granted at install time, so they are shown as always granted.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  late final Future<_PermStatus> _locationStatus;

  @override
  void initState() {
    super.initState();
    _locationStatus = _resolveLocationStatus();
  }

  Future<_PermStatus> _resolveLocationStatus() async {
    final gps = ref.read(gpsServiceProvider);
    final service = await gps.isLocationServiceEnabled();
    if (!service) {
      return const _PermStatus('GPS oprit', RetrometerColors.secondary);
    }
    final perm = await gps.checkPermission();
    switch (perm) {
      case LocationPermission.denied:
        return const _PermStatus('Refuzată', RetrometerColors.danger);
      case LocationPermission.deniedForever:
        return const _PermStatus('Refuzată permanent', RetrometerColors.danger);
      case LocationPermission.whileInUse:
        return const _PermStatus('Acordată · în folosire', RetrometerColors.primary);
      case LocationPermission.always:
        return const _PermStatus('Acordată · întotdeauna', RetrometerColors.primary);
      case LocationPermission.unableToDetermine:
        return const _PermStatus('Necunoscută', RetrometerColors.textMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permisiuni')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'Retrometer folosește următoarele permisiuni. Locația este '
              'verificată în timp real; vibrația și ecranul aprins sunt '
              'permisiuni normale, acordate automat la instalare.',
              style: TextStyle(
                color: RetrometerColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<_PermStatus>(
              future: _locationStatus,
              builder: (context, snap) {
                final status = snap.data ??
                    const _PermStatus('Se verifică…', RetrometerColors.textMuted);
                return _PermissionRow(
                  icon: Icons.location_on,
                  name: 'Locație (GPS)',
                  purpose: 'Distanță, viteză și geofence pentru stagii.',
                  status: status,
                );
              },
            ),
            const _PermissionRow(
              icon: Icons.vibration,
              name: 'Vibrație',
              purpose: 'Feedback haptic la ajustări și auto-start/stop.',
              status: _PermStatus('Acordată', RetrometerColors.primary),
              note: 'Permisiune normală — acordată la instalare.',
            ),
            const _PermissionRow(
              icon: Icons.lightbulb_outline,
              name: 'Ecran aprins',
              purpose: 'Ține ecranul activ cât durează un stage.',
              status: _PermStatus('Acordată', RetrometerColors.primary),
              note: 'Permisiune normală — acordată la instalare.',
            ),
          ],
        ),
      ),
    );
  }
}

/// A permission status: a short label + the color it should render in.
class _PermStatus {
  const _PermStatus(this.label, this.color);

  final String label;
  final Color color;
}

/// A tappable nav row (icon + label + chevron) styled like the guide link.
class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RetrometerColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: RetrometerColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: RetrometerTextStyles.meta),
              ),
              Icon(Icons.chevron_right,
                  color: RetrometerColors.textSecondary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: RetrometerColors.surfaceElevated,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: RetrometerColors.divider, width: 1),
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: RetrometerColors.primary,
                  ),
                )
              : Icon(Icons.directions_car_filled,
                  color: RetrometerColors.primary, size: 46),
        ),
        const SizedBox(height: 14),
        Text('Retrometer', style: RetrometerTextStyles.headerTitle),
        const SizedBox(height: 4),
        Text('Rally Computer · trip-meter',
            style: RetrometerTextStyles.metaMuted),
      ],
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: RetrometerColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RetrometerColors.primary, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified, color: RetrometerColors.primary, size: 18),
          const SizedBox(width: 8),
          Text('Versiune $version', style: RetrometerTextStyles.metaStrong),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.name,
    required this.purpose,
    required this.status,
    this.note,
  });

  final IconData icon;
  final String name;
  final String purpose;
  final _PermStatus status;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: RetrometerColors.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name, style: RetrometerTextStyles.metaStrong),
                    ),
                    _StatusChip(status: status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(purpose,
                    style: TextStyle(
                      color: RetrometerColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    )),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!,
                      style: TextStyle(
                        color: RetrometerColors.textMuted,
                        fontSize: 12,
                        height: 1.3,
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _PermStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: status.color.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}