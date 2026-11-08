import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/core/widgets/zoe_snackbar.dart';
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/reminders/widgets/delete_reminder_dialog.dart';
import 'package:zoe_remind/features/reminders/screens/reminder_setup_screen.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
import 'package:zoe_remind/features/reminders/services/reminder_permissions.dart';
import 'package:zoe_remind/features/reminders/widgets/new_reminder_widgets.dart';

enum _QuickPick { today, tomorrow, weekend, custom }

/// What the form tells Home when it closes, so Home can show the right snackbar.
class ReminderFormResult {
  ReminderFormResult._();
  static const created = 'created';
  static const updated = 'updated';
  static const deleted = 'deleted';
}

/// New Reminder / Edit Reminder.
/// + button on Home → new.  Tapping a reminder on Home → edit.
/// Pops a [ReminderFormResult] value when something changed, or null on back.
class ReminderFormScreen extends StatefulWidget {
  /// null = create a new reminder
  final int? reminderId;
  const ReminderFormScreen({super.key, this.reminderId});

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  static const _maxTitle = 100;

  final _title = TextEditingController();
  final _repo = ReminderRepository();

  Reminder? _original; // set when editing
  DateTime? _date;
  TimeOfDay? _time;
  _QuickPick? _pick;
  ReminderRepeat _repeat = ReminderRepeat.none;

  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.reminderId != null;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    if (_isEdit) {
      _loading = true;
      _loadReminder();
    } else {
      // same default as the design: Tomorrow selected, time still empty
      _pick = _QuickPick.tomorrow;
      _date = _today.add(const Duration(days: 1));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadReminder() async {
    final r = await _repo.getById(widget.reminderId!);
    if (!mounted) return;
    if (r == null) {
      ZoeSnack.show(context, 'That reminder no longer exists.', error: true);
      context.pop(ReminderFormResult.deleted);
      return;
    }
    final day = ZoeDate.parseKey(r.date);
    setState(() {
      _original = r;
      _title.text = r.title;
      _date = day;
      _time = ZoeDate.parseTime(r.time);
      _repeat = r.repeat;
      _pick = _pickFor(day);
      _loading = false;
    });
  }

  // ---------- date / time ----------

  DateTime get _today => ZoeDate.dayOnly(DateTime.now());

  DateTime get _thisWeekend {
    final t = _today;
    // Sat (6) or Sun (7) → today, otherwise the coming Saturday
    return t.weekday >= DateTime.saturday
        ? t
        : t.add(Duration(days: DateTime.saturday - t.weekday));
  }

  _QuickPick _pickFor(DateTime d) {
    if (ZoeDate.sameDay(d, _today)) return _QuickPick.today;
    if (ZoeDate.sameDay(d, _today.add(const Duration(days: 1)))) return _QuickPick.tomorrow;
    return _QuickPick.custom;
  }

  void _applyQuickPick(_QuickPick pick) {
    setState(() {
      _pick = pick;
      _date = switch (pick) {
        _QuickPick.today => _today,
        _QuickPick.tomorrow => _today.add(const Duration(days: 1)),
        _QuickPick.weekend => _thisWeekend,
        _QuickPick.custom => _date,
      };
    });
  }

  ThemeData _pickerTheme(BuildContext ctx) => Theme.of(ctx).copyWith(
        colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: HomeColors.lavender,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
      );

  Future<void> _pickDate() async {
    // When editing an older reminder, still allow its original day.
    final originalDay = _original == null ? null : ZoeDate.parseKey(_original!.date);
    final first =
        (originalDay != null && originalDay.isBefore(_today)) ? originalDay : _today;
    final initial = (_date != null && !_date!.isBefore(first)) ? _date! : _today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: _today.add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _pick = _QuickPick.custom;
    });
  }

  Future<void> _pickTime() async {
    final next = DateTime.now().add(const Duration(hours: 1));
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay(hour: next.hour, minute: 0),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked != null) setState(() => _time = picked);
  }

  // ---------- repeat ----------

  String _repeatLabel(ReminderRepeat r) => switch (r) {
        ReminderRepeat.none => "Doesn't repeat",
        ReminderRepeat.daily => 'Every day',
        ReminderRepeat.weekly =>
          _date == null ? 'Every week' : 'Every week on ${ZoeDate.weekday(_date!)}',
        ReminderRepeat.monthly =>
          _date == null ? 'Every month' : 'Every month on day ${_date!.day}',
      };

  Future<void> _pickRepeat() async {
    final picked = await showModalBottomSheet<ReminderRepeat>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in ReminderRepeat.values)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                  title: Text(_repeatLabel(r), style: ReminderText.field),
                  trailing: r == _repeat
                      ? const Icon(Icons.check_rounded, color: HomeColors.lavender)
                      : null,
                  onTap: () => Navigator.pop(ctx, r),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _repeat = picked);
  }

  // ---------- validation (app code decides, never the AI) ----------

  bool get _hasWhen => _date != null && _time != null;

  String? get _dateKey => _date == null ? null : ZoeDate.key(_date!);
  String? get _timeKey => _time == null ? null : ZoeDate.timeKey(_time!);

  /// Date/time differ from what's saved (always true for a new reminder).
  bool get _whenChanged =>
      _original == null || _original!.date != _dateKey || _original!.time != _timeKey;

  /// A new time in the past isn't allowed. An old reminder can keep its old time
  /// (e.g. you only want to fix the title).
  bool get _isPast =>
      _hasWhen &&
      _whenChanged &&
      _repeat == ReminderRepeat.none &&
      !ZoeDate.combine(_date!, _time!).isAfter(DateTime.now());

  String get _cleanTitle => _title.text.trim();

  bool get _canSave =>
      _hasWhen && !_isPast && _cleanTitle.isNotEmpty && !_saving && !_loading;

  ZoeHintBanner _banner() {
    if (!_hasWhen) {
      return const ZoeHintBanner(
        tone: BannerTone.ask,
        text: "I didn't catch a date or time yet — ",
        boldText: 'kailan mo gusto i-remind kita?',
      );
    }
    if (_isPast) {
      return const ZoeHintBanner(
        tone: BannerTone.warn,
        text: 'That time already passed — ',
        boldText: 'pili ka ng mas late na oras.',
      );
    }
    if (_cleanTitle.isEmpty) {
      return const ZoeHintBanner(
        tone: BannerTone.ask,
        text: "Ano'ng ipapaalala ko sa'yo? ",
        boldText: 'Type a title first.',
      );
    }
    return ZoeHintBanner(
      tone: BannerTone.ok,
      text: _isEdit ? "Okay! I'll now remind you " : "Got it! I'll remind you ",
      boldText:
          '${ZoeDate.relative(_date!)} at ${ZoeDate.prettyTime(_time!)}'
          '${_repeat == ReminderRepeat.none ? '' : ' · ${_repeatLabel(_repeat).toLowerCase()}'}.',
    );
  }

  // ---------- save / delete ----------

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();

    try {
      final original = _original;
      if (original == null) {
        final newId = await _repo.add(Reminder(
          title: _cleanTitle,
          date: _dateKey!,
          time: _timeKey!,
          repeat: _repeat,
          createdAt: now,
          updatedAt: now,
        ));
        await ReminderAlarmService.instance.syncById(newId); // schedule alarm
      } else {
        // Moving it to a new date/time makes it "not done" again.
        final reset = _whenChanged;
        await _repo.update(original.copyWith(
          title: _cleanTitle,
          date: _dateKey,
          time: _timeKey,
          repeat: _repeat,
          updatedAt: now,
          status: reset ? 'pending' : null,
          clearLastDoneDate: reset,
          clearCompletedAt: reset,
        ));
        await ReminderAlarmService.instance.syncById(original.id!); // reschedule alarm
      }
      if (!mounted) return;
      // May kulang na permission? Ipakita muna ang Reminder Setup.
      if (await ReminderPermissions.instance.shouldPrompt() && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReminderSetupScreen()),
        );
      }
      if (!mounted) return;
      context.pop(original == null ? ReminderFormResult.created : ReminderFormResult.updated);
    } catch (e) {
      debugPrint('Saving reminder failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ZoeSnack.show(context, "Couldn't save the reminder. Please try again.", error: true);
    }
  }

  Future<void> _delete() async {
    final original = _original;
    final id = original?.id;
    if (original == null || id == null) return;

    final ok = await confirmDeleteReminder(
      context,
      original.title,
      repeats: original.repeat != ReminderRepeat.none,
    );
    if (!ok || !mounted) return;

    try {
      await _repo.delete(id);
      await ReminderAlarmService.instance.cancel(id); // cancel alarm
      if (!mounted) return;
      context.pop(ReminderFormResult.deleted);
    } catch (e) {
      debugPrint('Deleting reminder failed: $e');
      if (!mounted) return;
      ZoeSnack.show(context, "Couldn't delete the reminder.", error: true);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: HomeColors.cream,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    ReminderBackButton(onTap: () => context.pop()),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Text(_isEdit ? 'Edit Reminder' : 'New Reminder',
                          style: ReminderText.screenTitle),
                    ),
                    if (_isEdit && _original != null) _DeleteButton(onTap: _delete),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: HomeColors.lavender))
                    : _form(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: GradientButton(
                  label: _isEdit ? 'Save changes' : 'Create reminder',
                  loading: _saving,
                  onTap: _canSave ? _save : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(),
          const FieldLabel('Title'),
          _TitleField(controller: _title, maxLength: _maxTitle),
          const FieldLabel('When'),
          Row(
            children: [
              Expanded(
                child: PickerField(
                  icon: Icons.calendar_today_outlined,
                  value: _date == null ? null : ZoeDate.pretty(_date!),
                  placeholder: 'Date',
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: PickerField(
                  icon: Icons.access_time_rounded,
                  value: _time == null ? null : ZoeDate.prettyTime(_time!),
                  placeholder: 'Time',
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const FieldLabel('Quick picks'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (pick, label) in const [
                (_QuickPick.today, 'Today'),
                (_QuickPick.tomorrow, 'Tomorrow'),
                (_QuickPick.weekend, 'This weekend'),
              ])
                QuickChip(
                  label: label,
                  selected: _pick == pick,
                  onTap: () => _applyQuickPick(pick),
                ),
              QuickChip(
                label: 'Pick a date',
                selected: _pick == _QuickPick.custom,
                onTap: _pickDate,
              ),
            ],
          ),
          const FieldLabel('Repeat'),
          PickerField(
            icon: Icons.sync_alt_rounded,
            value: _repeatLabel(_repeat),
            placeholder: '',
            onTap: _pickRepeat,
            showChevron: true,
          ),
        ],
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  const _TitleField({required this.controller, required this.maxLength});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextField(
      controller: controller,
      maxLength: maxLength,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      style: ReminderText.field.copyWith(fontSize: 19),
      cursorColor: HomeColors.lavender,
      decoration: InputDecoration(
        hintText: 'e.g. Review my thesis',
        hintStyle: ReminderText.fieldHint,
        counterText: '', // hide "0/100"
        filled: true,
        fillColor: const Color(0xFFF6F4FD),
        contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        enabledBorder: border(const Color(0xFFB7ACEB), 1.5),
        focusedBorder: border(HomeColors.lavender, 2),
      ),
    );
  }
}

/// Coral trash button in the header (edit mode only) — same as Edit Task.
class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.coralLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.delete_outline_rounded, color: HomeColors.coral, size: 26),
        ),
      ),
    );
  }
}