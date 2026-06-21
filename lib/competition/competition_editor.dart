import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../competition_providers.dart';
import '../theme/retrometer_theme.dart';
import '../widgets/form_fields.dart';

/// Opens the competition editor sheet. On save, adds [existing] (when editing)
/// or a new competition. Existing stages are preserved across edits.
Future<void> showCompetitionEditor(
  BuildContext context,
  WidgetRef ref,
  Competition? existing,
) async {
  final result = await showModalBottomSheet<CompetitionDraft>(
    context: context,
    isScrollControlled: true,
    builder: (context) => CompetitionEditor(existing: existing),
  );
  if (result == null) return;
  final notifier = ref.read(competitionsProvider.notifier);
  final competition = Competition(
    id: existing?.id ?? 'comp-${DateTime.now().millisecondsSinceEpoch}',
    name: result.name,
    location: result.location,
    startDate: result.startDate,
    endDate: result.endDate,
    pilot: result.pilot,
    copilot: result.copilot,
    car: result.car,
    category: result.category,
    totalTeams: result.totalTeams,
    contactPerson: result.contactPerson,
    contactPhone: result.contactPhone,
    cost: result.cost,
    overallStanding: result.overallStanding,
    categoryStanding: result.categoryStanding,
    stages: existing?.stages ?? const <PlannedStage>[],
  );
  if (existing == null) {
    await notifier.addCompetition(competition);
  } else {
    await notifier.updateCompetition(competition);
  }
}

class CompetitionDraft {
  CompetitionDraft({
    required this.name,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.pilot,
    required this.copilot,
    required this.car,
    required this.category,
    required this.totalTeams,
    required this.contactPerson,
    required this.contactPhone,
    required this.cost,
    required this.overallStanding,
    required this.categoryStanding,
  });

  String name;
  String location;
  DateTime? startDate;
  DateTime? endDate;
  String pilot;
  String copilot;
  String car;
  String category;
  int totalTeams;
  String contactPerson;
  String contactPhone;
  double cost;
  int overallStanding;
  int categoryStanding;
}

class CompetitionEditor extends StatefulWidget {
  const CompetitionEditor({super.key, this.existing});

  final Competition? existing;

  @override
  State<CompetitionEditor> createState() => _CompetitionEditorState();
}

class _CompetitionEditorState extends State<CompetitionEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _pilotCtrl;
  late final TextEditingController _copilotCtrl;
  late final TextEditingController _carCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _totalTeamsCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _contactPhoneCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _overallCtrl;
  late final TextEditingController _categoryStandingCtrl;
  late CompetitionDraft _draft;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _draft = CompetitionDraft(
      name: e?.name ?? '',
      location: e?.location ?? '',
      startDate: e?.startDate,
      endDate: e?.endDate,
      pilot: e?.pilot ?? '',
      copilot: e?.copilot ?? '',
      car: e?.car ?? '',
      category: e?.category ?? '',
      totalTeams: e?.totalTeams ?? 0,
      contactPerson: e?.contactPerson ?? '',
      contactPhone: e?.contactPhone ?? '',
      cost: e?.cost ?? 0.0,
      overallStanding: e?.overallStanding ?? 0,
      categoryStanding: e?.categoryStanding ?? 0,
    );
    _nameCtrl = TextEditingController(text: _draft.name);
    _locationCtrl = TextEditingController(text: _draft.location);
    _pilotCtrl = TextEditingController(text: _draft.pilot);
    _copilotCtrl = TextEditingController(text: _draft.copilot);
    _carCtrl = TextEditingController(text: _draft.car);
    _categoryCtrl = TextEditingController(text: _draft.category);
    _totalTeamsCtrl = TextEditingController(
        text: _draft.totalTeams == 0 ? '' : _draft.totalTeams.toString());
    _contactCtrl = TextEditingController(text: _draft.contactPerson);
    _contactPhoneCtrl = TextEditingController(text: _draft.contactPhone);
    _costCtrl = TextEditingController(
        text: _draft.cost == 0.0 ? '' : _draft.cost.toStringAsFixed(2));
    _overallCtrl = TextEditingController(
        text: _draft.overallStanding == 0 ? '' : _draft.overallStanding.toString());
    _categoryStandingCtrl = TextEditingController(
        text: _draft.categoryStanding == 0
            ? ''
            : _draft.categoryStanding.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _pilotCtrl.dispose();
    _copilotCtrl.dispose();
    _carCtrl.dispose();
    _categoryCtrl.dispose();
    _totalTeamsCtrl.dispose();
    _contactCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _costCtrl.dispose();
    _overallCtrl.dispose();
    _categoryStandingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null
                  ? 'Competiție nouă'
                  : 'Editare competiție',
              style: RetrometerTextStyles.sheetTitle,
            ),
            const SizedBox(height: 16),
            LabeledTextField(controller: _nameCtrl, label: 'Nume competiție'),
            const SizedBox(height: 12),
            LabeledTextField(controller: _locationCtrl, label: 'Locație (ex. Cluj)'),
            const SizedBox(height: 12),
            DateRangeField(
              startDate: _draft.startDate,
              endDate: _draft.endDate,
              onChanged: (start, end) =>
                  setState(() {_draft.startDate = start; _draft.endDate = end;}),
            ),
            const SizedBox(height: 12),
            LabeledTextField(controller: _pilotCtrl, label: 'Pilot'),
            const SizedBox(height: 12),
            LabeledTextField(controller: _copilotCtrl, label: 'Copilot'),
            const SizedBox(height: 12),
            LabeledTextField(
                controller: _carCtrl, label: 'Mașină (ex. BMW Z3)'),
            const SizedBox(height: 12),
            LabeledTextField(controller: _categoryCtrl, label: 'Categorie'),
            const SizedBox(height: 12),
            IntField(
              controller: _totalTeamsCtrl,
              label: 'Număr total echipe',
              onChanged: (v) => _draft.totalTeams = v,
            ),
            const SizedBox(height: 12),
            LabeledTextField(
                controller: _contactCtrl, label: 'Persoană de contact'),
            const SizedBox(height: 12),
            LabeledTextField(
                controller: _contactPhoneCtrl,
                label: 'Telefon contact',
                keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            DecimalField(
              controller: _costCtrl,
              label: 'Cost competiție',
              onChanged: (v) => _draft.cost = v,
            ),
            const SizedBox(height: 16),
            const Text('Locul curent',
                style: RetrometerTextStyles.sectionLabel),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: IntField(
                    controller: _overallCtrl,
                    label: 'La general',
                    onChanged: (v) => _draft.overallStanding = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: IntField(
                    controller: _categoryStandingCtrl,
                    label: 'În categorie',
                    onChanged: (v) => _draft.categoryStanding = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
  }

  bool _save() {
    final draft = CompetitionDraft(
      name: _nameCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      startDate: _draft.startDate,
      endDate: _draft.endDate,
      pilot: _pilotCtrl.text.trim(),
      copilot: _copilotCtrl.text.trim(),
      car: _carCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      totalTeams: int.tryParse(_totalTeamsCtrl.text.trim()) ?? 0,
      contactPerson: _contactCtrl.text.trim(),
      contactPhone: _contactPhoneCtrl.text.trim(),
      cost: double.tryParse(_costCtrl.text.trim()) ?? 0.0,
      overallStanding: int.tryParse(_overallCtrl.text.trim()) ?? 0,
      categoryStanding: int.tryParse(_categoryStandingCtrl.text.trim()) ?? 0,
    );
    Navigator.of(context).pop(draft);
    return true;
  }
}