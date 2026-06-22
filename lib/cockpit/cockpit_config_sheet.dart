import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state_providers.dart';
import '../theme/retrometer_theme.dart';
import '../widgets/editor_sheet.dart';
import '../widgets/form_fields.dart';

/// Opens the stage configuration bottom sheet (name, target average speed,
/// max speed limit). `copyWith` preserves the finish geofence / auto-stop /
/// distance / allocated-time fields the sheet doesn't edit, so opening the
/// gear no longer silently drops them.
Future<void> showStageConfigSheet(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(stageControllerProvider.notifier);
  final current = ref.read(stageControllerProvider).config;

  final nameCtrl = TextEditingController(text: current.name);
  var target = current.targetAvgSpeed;
  var maxLimit = current.maxSpeedLimit;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => EditorSheetScaffold(
        title: 'Configurare stage',
        onSave: () {
          controller.updateConfig(
            current.copyWith(
              name: nameCtrl.text.trim().isEmpty
                  ? current.name
                  : nameCtrl.text.trim(),
              targetAvgSpeed: target,
              maxSpeedLimit: maxLimit,
            ),
          );
          Navigator.of(context).pop();
        },
        children: [
          TextField(
            controller: nameCtrl,
            style: const TextStyle(color: RetrometerColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Nume'),
          ),
          const SizedBox(height: 16),
          NumberField(
            label: 'Viteză medie țintă (km/h)',
            value: target,
            decimals: 1,
            onChanged: (v) => setState(() => target = v),
          ),
          const SizedBox(height: 16),
          NumberField(
            label: 'Limită maximă (km/h)',
            value: maxLimit,
            decimals: 1,
            onChanged: (v) => setState(() => maxLimit = v),
          ),
        ],
      ),
    ),
  );
}