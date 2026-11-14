import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/reminders/widgets/new_reminder_widgets.dart';

enum _QuickPick { today, tomorrow, weekend, custom }

/// New Reminder (write flow). Returns `true` via context.pop when saved,
/// so Home knows to reload.
class NewReminderScreen extends StatefulWidget {
  const NewReminderScreen({super.key});

  @override
  State<NewReminderScreen> createState() => _NewReminderScreenState();
}

class _NewReminderScreenState extends State<NewReminderScreen> {
  static const _maxTitle = 100;

  final _title = TextEditingController();
  final _repo = ReminderRepository();

  DateTime? _date;
  TimeOfDay? _time;
  _QuickPick? _pick;
  ReminderRepeat _repeat = ReminderRepeat.none;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // same default as the design: Tomorrow selected, time still empty
    _pick = _QuickPick.tomorrow;
    _date = _today.add(const Duration(days: 1));
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
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
              surface: HomeColors.card,
              onSurface: HomeColors.ink,
            ),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? _today,
      firstDate: _today,
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
      backgroundColor: HomeColors.card,
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
                      ? Icon(Icons.check_rounded, color: HomeColors.lavender)
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

  bool get _isPast =>
      _hasWhen &&
      _repeat == ReminderRepeat.none &&
      !ZoeDate.combine(_date!, _time!).isAfter(DateTime.now());

  String get _cleanTitle => _title.text.trim();

  bool get _canSave => _hasWhen && !_isPast && _cleanTitle.isNotEmpty && !_saving;

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
      text: "Got it! I'll remind you ",
      boldText:
          '${ZoeDate.relative(_date!)} at ${ZoeDate.prettyTime(_time!)}'
          '${_repeat == ReminderRepeat.none ? '' : ' · ${_repeatLabel(_repeat).toLowerCase()}'}.',
    );
  }

  // ---------- save ----------

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final now = DateTime.now().toIso8601String();
    try {
      await _repo.add(Reminder(
        title: _cleanTitle,
        date: ZoeDate.key(_date!),
        time: ZoeDate.timeKey(_time!),
        repeat: _repeat,
        createdAt: now,
        updatedAt: now,
      ));
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      debugPrint('Saving reminder failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save the reminder. Please try again.")),
      );
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (ZoeTheme.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: HomeColors.cream,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    ReminderBackButton(onTap: () => context.pop(false)),
                    const SizedBox(width: 22),
                    Text('New Reminder', style: ReminderText.screenTitle),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
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
                          QuickChip(
                            label: 'Today',
                            selected: _pick == _QuickPick.today,
                            onTap: () => _applyQuickPick(_QuickPick.today),
                          ),
                          QuickChip(
                            label: 'Tomorrow',
                            selected: _pick == _QuickPick.tomorrow,
                            onTap: () => _applyQuickPick(_QuickPick.tomorrow),
                          ),
                          QuickChip(
                            label: 'This weekend',
                            selected: _pick == _QuickPick.weekend,
                            onTap: () => _applyQuickPick(_QuickPick.weekend),
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: GradientButton(
                  label: 'Create reminder',
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
        fillColor: HomeColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        enabledBorder: border(const Color(0xFFB7ACEB), 1.5),
        focusedBorder: border(HomeColors.lavender, 2),
      ),
    );
  }
}