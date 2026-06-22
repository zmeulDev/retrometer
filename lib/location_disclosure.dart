import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme/retrometer_theme.dart';
import 'widgets/icon_text_row.dart';
import 'widgets/retrometer_alert_dialog.dart';

const _kDisclosureShownKey = 'retrometer.location_disclosure_shown';

/// Privacy policy URL shown in the disclosure dialog and on the About screen.
/// **TODO:** replace with your published policy URL before submitting to
/// Google Play.
const kPrivacyPolicyUrl = 'https://example.com/retrometer/privacy-policy';

/// Google Play–style Prominent Disclosure for location access.
///
/// Shown **once** (gated by a [SharedPreferences] flag) before the app first
/// asks for the location permission, at the UI entry points that have a
/// [BuildContext] (the cockpit START control and the "my location" buttons in
/// the stage editor). Returns `true` if the user acknowledged the disclosure —
/// either just now or on a previous run — in which case the caller may proceed
/// to request the permission. Returns `false` if the user declined, in which
/// case the caller must abort the location-dependent action.
///
/// The app is foreground-only (no background location), so the disclosure
/// covers the while-in-use access it actually requests.
Future<bool> maybeShowLocationDisclosure(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kDisclosureShownKey) == true) return true;
  if (!context.mounted) return false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _LocationDisclosureDialog(),
  );
  if (accepted == true) {
    await prefs.setBool(_kDisclosureShownKey, true);
  }
  return accepted == true;
}

class _LocationDisclosureDialog extends StatelessWidget {
  const _LocationDisclosureDialog();

  @override
  Widget build(BuildContext context) {
    return RetrometerAlertDialog(
      icon: Icon(Icons.location_on, color: RetrometerColors.primary, size: 32),
      title: 'Acces la locație',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Retrometer folosește datele de locație (GPS) pentru a calcula '
              'distanța parcursă, viteza și indicatorul Δ în timpul raliului de '
              'regularitate:',
              style: TextStyle(
                  color: RetrometerColors.textSecondary, height: 1.4),
            ),
            SizedBox(height: 12),
            _Bullet(Icons.straighten, 'Distanța și viteza curentă a stage-ului.'),
            _Bullet(Icons.my_location, 'Geofence de start / sosire pentru '
                'pornirea și oprirea automată a stagii­lor.'),
            _Bullet(Icons.place, 'Afișarea localității curente pe bord.'),
            SizedBox(height: 12),
            Text(
              'Locația este folosită doar cât timp aplicația este deschisă '
              '(prim-plan) și NU este colectată, transmisă sau vândută către '
              'terți.',
              style: TextStyle(
                  color: RetrometerColors.textSecondary, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'Accesul la locație este opțional: îl poți refuza, dar atunci '
              'funcțiile de raliu (distanță, viteză, indicator Δ, auto-start/stop) '
              'nu sunt disponibile. Restul aplicației rămâne funcțională.',
              style: TextStyle(
                  color: RetrometerColors.textSecondary, height: 1.4),
            ),
            SizedBox(height: 12),
            _PrivacyPolicyLink(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Refuză'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continuă'),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return IconTextRow(
      icon: icon,
      text: text,
      iconColor: RetrometerColors.primary,
      iconSize: 18,
      gap: 10,
      style: const TextStyle(
        color: RetrometerColors.textSecondary,
        height: 1.35,
      ),
      verticalPadding: 4,
      crossAxisAlignment: CrossAxisAlignment.start,
    );
  }
}

/// Tappable "Privacy Policy" link inside the disclosure dialog. Opens the
/// policy URL in the system browser.
class _PrivacyPolicyLink extends StatelessWidget {
  const _PrivacyPolicyLink();

  Future<void> _open() async {
    await launchUrl(Uri.parse(kPrivacyPolicyUrl));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new,
                color: RetrometerColors.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              'Vezi Politica de confidențialitate',
              style: TextStyle(
                color: RetrometerColors.primary,
                decoration: TextDecoration.underline,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}