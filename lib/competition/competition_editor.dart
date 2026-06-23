import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../competition_providers.dart';
import '../utils/formatting.dart';
import '../widgets/editor_sheet.dart';
import '../widgets/form_fields.dart';

/// Opens the competition editor as a full-screen page. On save, adds
/// [existing] (when editing) or a new competition. Existing stages are
/// preserved across edits.
Future<void> showCompetitionEditor(
  BuildContext context,
  WidgetRef ref,
  Competition? existing,
) async {
  final result = await Navigator.of(context).push<CompetitionDraft>(
    MaterialPageRoute(
      builder: (context) => CompetitionEditor(existing: existing),
    ),
  );
  if (result == null) return;
  final notifier = ref.read(competitionsProvider.notifier);
  final competition = Competition(
    id: existing?.id ?? newId('comp'),
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
  String? _nameError;

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
    return EditorPageScaffold(
      title:
          widget.existing == null ? 'Competiție nouă' : 'Editare competiție',
      onSave: _save,
      children: [
        EditorSectionCard(
          title: 'Identitate',
          children: [
            LabeledTextField(
              controller: _nameCtrl,
              label: 'Nume competiție',
              errorText: _nameError,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            LabeledTextField(
                controller: _locationCtrl, label: 'Locație (ex. Cluj)'),
            DateRangeField(
              startDate: _draft.startDate,
              endDate: _draft.endDate,
              onChanged: (start, end) => setState(() {
                _draft.startDate = start;
                _draft.endDate = end;
              }),
            ),
          ],
        ),
        EditorSectionCard(
          title: 'Echipaj',
          children: [
            LabeledTextField(controller: _pilotCtrl, label: 'Pilot'),
            LabeledTextField(controller: _copilotCtrl, label: 'Copilot'),
            LabeledTextField(
                controller: _carCtrl, label: 'Mașină (ex. BMW Z3)'),
            LabeledTextField(controller: _categoryCtrl, label: 'Categorie'),
            IntField(
              controller: _totalTeamsCtrl,
              label: 'Număr total echipe',
              onChanged: (v) => _draft.totalTeams = v,
            ),
          ],
        ),
        EditorSectionCard(
          title: 'Contact',
          children: [
            LabeledTextField(
                controller: _contactCtrl, label: 'Persoană de contact'),
            LabeledTextField(
              controller: _contactPhoneCtrl,
              label: 'Telefon contact',
              keyboardType: TextInputType.phone,
            ),
            DecimalField(
              controller: _costCtrl,
              label: 'Cost competiție',
              onChanged: (v) => _draft.cost = v,
            ),
          ],
        ),
        EditorSectionCard(
          title: 'Locul curent',
          children: [
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
          ],
        ),
      ],
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Introdu un nume.');
      return;
    }
    final draft = CompetitionDraft(
      name: name,
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
  }
}