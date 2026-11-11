import 'package:flutter/material.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/reminders/models/alarm_sound.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
import 'package:zoe_remind/features/settings/widgets/settings_styles.dart';

const _f = 'Poppins';

/// Palitan ang pangalan. Returns ang bagong pangalan, o null kung cancel.
Future<String?> showEditNameDialog(
    BuildContext context, String current, SettingsPalette p) {
  return showDialog<String>(
    context: context,
    builder: (_) => _EditNameDialog(current: current, palette: p),
  );
}

class _EditNameDialog extends StatefulWidget {
  final String current;
  final SettingsPalette palette;
  const _EditNameDialog({required this.current, required this.palette});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _ctrl = TextEditingController(text: widget.current);
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return AlertDialog(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('What should Zoe call you?',
          style: TextStyle(fontFamily: _f, fontWeight: FontWeight.w700, color: p.ink)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: SettingsRepository.maxName,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        cursorColor: p.accent,
        style: TextStyle(fontFamily: _f, fontSize: 17, color: p.ink),
        decoration: InputDecoration(
          hintText: 'Your name',
          errorText: _error,
          filled: true,
          fillColor: p.pillBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(fontFamily: _f, fontWeight: FontWeight.w700, color: p.inkSoft)),
        ),
        TextButton(
          onPressed: _save,
          child: Text('Save',
              style: TextStyle(fontFamily: _f, fontWeight: FontWeight.w700, color: p.accent)),
        ),
      ],
    );
  }
}

/// Generic "Sigurado ka ba?" dialog. Returns true kapag kinumpirma.
Future<bool> confirmAction(
  BuildContext context, {
  required SettingsPalette palette,
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = true,
}) async {
  final p = palette;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(title,
          style: TextStyle(fontFamily: _f, fontWeight: FontWeight.w700, color: p.ink)),
      content: Text(message,
          style: TextStyle(fontFamily: _f, fontSize: 15, color: p.inkSoft, height: 1.45)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel',
              style: TextStyle(fontFamily: _f, fontWeight: FontWeight.w700, color: p.inkSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel,
              style: TextStyle(
                  fontFamily: _f,
                  fontWeight: FontWeight.w700,
                  color: danger ? p.coral : p.accent)),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Bottom sheet na may listahan ng pagpipilian (✓ sa naka-select).
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required SettingsPalette palette,
  required String title,
  String? subtitle,
  required List<T> values,
  required T selected,
  required String Function(T) label,
}) {
  final p = palette;
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    backgroundColor: p.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text(title,
                  style: TextStyle(
                      fontFamily: _f, fontSize: 20, fontWeight: FontWeight.w700, color: p.ink)),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(subtitle, style: SettingsText.body(p)),
              ),
            for (final v in values)
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(label(v),
                    style: TextStyle(
                        fontFamily: _f,
                        fontSize: 17,
                        fontWeight: v == selected ? FontWeight.w700 : FontWeight.w500,
                        color: v == selected ? p.accent : p.ink)),
                trailing: v == selected
                    ? Icon(Icons.check_circle_rounded, color: p.accent)
                    : null,
                onTap: () => Navigator.pop(ctx, v),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<int?> showSnoozePicker(BuildContext context, SettingsPalette p, int current) =>
    showChoiceSheet<int>(
      context,
      palette: p,
      title: 'Default snooze',
      subtitle: 'Naka-highlight ito sa ringing screen.',
      values: ReminderAlarmService.snoozeOptions,
      selected: current,
      label: (m) => '$m minutes',
    );

Future<AlarmSound?> showSoundPicker(BuildContext context, SettingsPalette p, AlarmSound current) =>
    showChoiceSheet<AlarmSound>(
      context,
      palette: p,
      title: 'Alarm sound',
      subtitle: 'Gagamitin sa lahat ng reminders, pati sa naka-schedule na.',
      values: AlarmSound.values,
      selected: current,
      label: (s) => s.label,
    );