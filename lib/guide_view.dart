import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/retrometer_theme.dart';

const _kOnboardedKey = 'retrometer.onboarded';

/// On first launch only: pushes the guide screen and marks onboarding done.
Future<void> maybeShowOnboarding(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kOnboardedKey) == true) return;
  await prefs.setBool(_kOnboardedKey, true);
  if (context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const GuideScreen()),
    );
  }
}

/// Full-screen, scrollable user guide.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ghid de utilizare')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: const [
            _CockpitMockup(),
            SizedBox(height: 24),
            _SectionTitle('Cum pornești'),
            _GuideRow(
              icon: Icons.settings,
              text: 'Apasă ⚙ și setează viteza medie țintă (ex. 40 km/h) '
                  'și limita maximă (ex. 60 km/h).',
            ),
            _GuideRow(
              icon: Icons.play_arrow,
              color: RetrometerColors.primary,
              text: 'Apasă ▶ START. Se cere permisiunea de locație; '
                  'ecranul rămâne aprins cât durează treapta.',
            ),
            SizedBox(height: 20),
            _SectionTitle('Indicatorul Δ (secunde)'),
            _GuideRow(
              icon: Icons.check,
              color: RetrometerColors.primary,
              text: 'VERDE — LA TIMP: ești în ±1 s față de timpul ideal. '
                  'Țintește să stai aici.',
            ),
            _GuideRow(
              icon: Icons.arrow_upward,
              color: RetrometerColors.danger,
              text: 'ROȘU — AVANS (−): mergi prea repede. Frânează ușor până '
                  'Δ revine la 0.',
            ),
            _GuideRow(
              icon: Icons.arrow_downward,
              color: RetrometerColors.secondary,
              text: 'GALBEN — ÎNTÂRZIERE (+): mergi prea încet. Accelierează '
                  'ușor până Δ revine la 0.',
            ),
            _GuideRow(
              icon: Icons.warning_amber,
              color: RetrometerColors.danger,
              text: 'Dacă viteza depășește limita maximă, apare alerta '
                  '⚠ OVER SPEED.',
            ),
            SizedBox(height: 20),
            _SectionTitle('Calibrarea distanței la bornă'),
            _GuideRow(
              icon: Icons.remove,
              text: '−10 m (stânga jos): scade distanța cu 10 m. '
                  'Apăsare lungă = −100 m.',
            ),
            _GuideRow(
              icon: Icons.add,
              text: '+10 m (dreapta jos): crește distanța cu 10 m. '
                  'Apăsare lungă = +100 m.',
            ),
            _GuideRow(
              icon: Icons.touch_app,
              text: 'Când treci pe lângă o bornă fizică, aliniază distanța '
                  'din aplicație cu borna (ex. borna 5.00 km, app arată 4.97 → '
                  'apasă +10 m de 3 ori). Vibrația confirmă apăsarea fără să '
                  'te uiți.',
            ),
            SizedBox(height: 20),
            _SectionTitle('Competiții și stagii'),
            _GuideRow(
              icon: Icons.emoji_events,
              color: RetrometerColors.primary,
              text: 'Apasă 📅 (sus) ca să vezi competițiile. Fiecare competiție '
                  'ține detaliile (nume, locație, piloți, mașină, categorie, '
                  'contact, cost, loc la general/categorie) și lista ei de '
                  'stagii. Se salvează — pregătești dimineața, conduci mai târziu.',
            ),
            _GuideRow(
              icon: Icons.event_note,
              text: 'Într-o competiție adaugi stagii cu nume, oră de start și '
                  'locație (geofence cu rază), locație finală cu auto-stop, '
                  'distanță și timp alocat.',
            ),
            _GuideRow(
              icon: Icons.my_location,
              text: 'Pentru locație: caută o adresă, folosește „Locația mea" '
                  'din GPS, sau introdu coordonatele manual. Raza geofence '
                  'decide cât de aproape trebuie să fii ca să pornească.',
            ),
            _GuideRow(
              icon: Icons.play_arrow,
              color: RetrometerColors.primary,
              text: 'Cu auto-start pornit, treapta începe singură când ora '
                  'ajunge și ești în interiorul geofence-ului. Poți porni '
                  'și manual cu ▶ de pe fiecare stage.',
            ),
            SizedBox(height: 20),
            _SectionTitle('Altele'),
            _GuideRow(
              icon: Icons.location_on,
              color: RetrometerColors.primary,
              text: '📍 Sus apare localitatea curentă (din GPS). Se '
                  'actualizează când te muți cu ~1 km.',
            ),
            _GuideRow(
              icon: Icons.stop,
              color: RetrometerColors.danger,
              text: '■ STOP oprește treapta (păstrează distanța). '
                  '↻ RESET o reinițializează.',
            ),
            _GuideRow(
              icon: Icons.offline_bolt,
              text: 'Aplicația merge offline. GPS și ecran aprins folosesc '
                  'bateria mai intens — încarcă telefonul la raliuri lungi.',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces.
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: RetrometerTextStyles.guideSection,
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              color: color ?? RetrometerColors.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color ?? RetrometerColors.textSecondary,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini schematic of the cockpit's 3 zones.
class _CockpitMockup extends StatelessWidget {
  const _CockpitMockup();

  @override
  Widget build(BuildContext context) {
    const border =
        BorderSide(color: RetrometerColors.dividerStrong, width: 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Așezarea ecranului',
          style: TextStyle(
            color: RetrometerColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: RetrometerColors.dividerStrong),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            children: [
              _MockZone(
                height: 36,
                color: RetrometerColors.surface,
                border: border,
                label: '📍 Localitate · nume · timp · controale',
              ),
              _MockZone(
                height: 90,
                color: RetrometerColors.onTimeBg,
                border: border,
                label: 'Δ  AVANS / ÎNTÂRZIERE / LA TIMP',
                big: true,
              ),
              _MockZone(
                height: 80,
                color: RetrometerColors.background,
                border: border,
                label: '− 10 m   |   14.56 km   |   + 10 m',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MockZone extends StatelessWidget {
  const _MockZone({
    required this.height,
    required this.color,
    required this.border,
    required this.label,
    this.big = false,
  });

  final double height;
  final Color color;
  final BorderSide border;
  final String label;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        border: Border(top: border),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: big ? RetrometerColors.primary : RetrometerColors.textSecondary,
          fontSize: big ? 16 : 12,
          fontWeight: big ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}