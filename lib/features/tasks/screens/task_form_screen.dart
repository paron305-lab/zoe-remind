import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/task.dart';
import 'package:zoe_remind/database/repositories/task_repository.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/reminders/widgets/new_reminder_widgets.dart';
import 'package:zoe_remind/features/tasks/widgets/delete_task_dialog.dart';
import 'package:zoe_remind/features/tasks/widgets/task_styles.dart';

enum _QuickPick { today, tomorrow, weekend, noDate, custom }

/// New Task / Edit Task. Opened from the + button (new) or by tapping a
/// task (edit). Pops `true` when something was saved or deleted so the
/// Tasks screen knows to reload.
class TaskFormScreen extends StatefulWidget {
  /// null = create a new task
  final int? taskId;
  const TaskFormScreen({super.key, this.taskId});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  static const _maxTitle = 120;
  static const _maxNotes = 1000;

  final _repo = TaskRepository();
  final _title = TextEditingController();
  final _notes = TextEditingController();

  Task? _original; // set when editing
  DateTime? _date;
  TimeOfDay? _time;
  _QuickPick? _pick;
  TaskCategory _category = TaskCategory.other;
  TaskPriority _priority = TaskPriority.medium;

  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.taskId != null;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    if (_isEdit) {
      _loading = true;
      _loadTask();
    } else {
      _pick = _QuickPick.today;
      _date = _today;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    final task = await _repo.getById(widget.taskId!);
    if (!mounted) return;
    if (task == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('That task no longer exists.')));
      context.pop(true);
      return;
    }
    setState(() {
      _original = task;
      _title.text = task.title;
      _notes.text = task.description ?? '';
      _date = task.day;
      _time = task.timeOfDay;
      _category = task.category;
      _priority = task.priority;
      _pick = _pickFor(_date);
      _loading = false;
    });
  }

  // ---------- date / time ----------

  DateTime get _today => ZoeDate.dayOnly(DateTime.now());

  DateTime get _thisWeekend {
    final t = _today;
    return t.weekday >= DateTime.saturday
        ? t
        : t.add(Duration(days: DateTime.saturday - t.weekday));
  }

  _QuickPick _pickFor(DateTime? d) {
    if (d == null) return _QuickPick.noDate;
    if (ZoeDate.sameDay(d, _today)) return _QuickPick.today;
    if (ZoeDate.sameDay(d, _today.add(const Duration(days: 1)))) return _QuickPick.tomorrow;
    return _QuickPick.custom;
  }

  void _applyQuickPick(_QuickPick pick) {
    setState(() {
      _pick = pick;
      switch (pick) {
        case _QuickPick.today:
          _date = _today;
        case _QuickPick.tomorrow:
          _date = _today.add(const Duration(days: 1));
        case _QuickPick.weekend:
          _date = _thisWeekend;
        case _QuickPick.noDate:
          _date = null;
          _time = null; // a time without a day doesn't mean anything
        case _QuickPick.custom:
          break;
      }
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
    // When editing an overdue task, still allow its old date.
    final originalDay = _original?.day;
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
    if (picked == null) return;
    setState(() {
      _time = picked;
      // picking a time with "No date" → assume today
      if (_date == null) {
        _date = _today;
        _pick = _QuickPick.today;
      }
    });
  }

  // ---------- validation (app code decides, never the AI) ----------

  String get _cleanTitle => _title.text.trim();

  /// A new date in the past isn't allowed. An overdue task can keep its old date.
  bool get _isPastDate {
    if (_date == null || !_date!.isBefore(_today)) return false;
    final originalDay = _original?.day;
    return originalDay == null || !ZoeDate.sameDay(originalDay, _date!);
  }

  bool get _canSave => _cleanTitle.isNotEmpty && !_isPastDate && !_saving && !_loading;

  ZoeHintBanner _banner() {
    if (_cleanTitle.isEmpty) {
      return const ZoeHintBanner(
        tone: BannerTone.ask,
        text: "Ano'ng gagawin mo? ",
        boldText: 'Type a title first.',
      );
    }
    if (_isPastDate) {
      return const ZoeHintBanner(
        tone: BannerTone.warn,
        text: 'That day already passed — ',
        boldText: 'pili ka ng ibang date.',
      );
    }
    if (_date == null) {
      return const ZoeHintBanner(
        tone: BannerTone.ok,
        text: "Got it! I'll keep this under ",
        boldText: 'Someday.',
      );
    }
    final when = _time == null
        ? ZoeDate.relative(_date!)
        : '${ZoeDate.relative(_date!)} at ${ZoeDate.prettyTime(_time!)}';
    return ZoeHintBanner(
      tone: BannerTone.ok,
      text: 'Got it! Task for ',
      boldText: '$when · ${_category.label}.',
    );
  }

  // ---------- save / delete ----------

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    final notes = _notes.text.trim();
    try {
      final original = _original;
      if (original == null) {
        await _repo.add(Task(
          title: _cleanTitle,
          description: notes.isEmpty ? null : notes,
          date: _date == null ? null : ZoeDate.key(_date!),
          time: _time == null ? null : ZoeDate.timeKey(_time!),
          category: _category,
          priority: _priority,
          createdAt: DateTime.now().toIso8601String(),
        ));
      } else {
        await _repo.update(original.copyWith(
          title: _cleanTitle,
          description: notes.isEmpty ? null : notes,
          clearDescription: notes.isEmpty,
          date: _date == null ? null : ZoeDate.key(_date!),
          clearDate: _date == null,
          time: _time == null ? null : ZoeDate.timeKey(_time!),
          clearTime: _time == null,
          category: _category,
          priority: _priority,
        ));
      }
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      debugPrint('Saving task failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save the task. Please try again.")),
      );
    }
  }

  Future<void> _delete() async {
    final original = _original;
    if (original?.id == null) return;
    final ok = await confirmDeleteTask(context, original!.title);
    if (!ok || !mounted) return;
    try {
      await _repo.delete(original.id!);
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      debugPrint('Deleting task failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't delete the task.")),
      );
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
                    ReminderBackButton(onTap: () => context.pop(false)),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Text(_isEdit ? 'Edit Task' : 'New Task',
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
                  label: _isEdit ? 'Save changes' : 'Create task',
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
          _InputBox(
            controller: _title,
            hint: 'e.g. Review Chapter 3',
            maxLength: _maxTitle,
            big: true,
          ),
          const FieldLabel('Notes (optional)'),
          _InputBox(
            controller: _notes,
            hint: 'Details, links, reminders to self…',
            maxLength: _maxNotes,
            minLines: 3,
            maxLines: 6,
          ),
          const FieldLabel('When'),
          Row(
            children: [
              Expanded(
                child: PickerField(
                  icon: Icons.calendar_today_outlined,
                  value: _date == null ? null : ZoeDate.pretty(_date!),
                  placeholder: 'No date',
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: PickerField(
                  icon: Icons.access_time_rounded,
                  value: _time == null ? null : ZoeDate.prettyTime(_time!),
                  placeholder: 'Any time',
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          if (_time != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _time = null),
                child: const Text('Clear time',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        color: HomeColors.lavender)),
              ),
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
                (_QuickPick.noDate, 'No date'),
              ])
                QuickChip(
                  label: label,
                  selected: _pick == pick,
                  onTap: () => _applyQuickPick(pick),
                ),
            ],
          ),
          const FieldLabel('Category'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in TaskCategory.values)
                _CategoryChip(
                  category: c,
                  selected: c == _category,
                  onTap: () => setState(() => _category = c),
                ),
            ],
          ),
          const FieldLabel('Priority'),
          Row(
            children: [
              for (final p in TaskPriority.values) ...[
                Expanded(
                  child: _PriorityButton(
                    priority: p,
                    selected: p == _priority,
                    onTap: () => setState(() => _priority = p),
                  ),
                ),
                if (p != TaskPriority.values.last) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final bool big;
  final int minLines;
  final int maxLines;

  const _InputBox({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.big = false,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextField(
      controller: controller,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
      style: big
          ? ReminderText.field.copyWith(fontSize: 19)
          : ReminderText.field.copyWith(fontWeight: FontWeight.w500, fontSize: 16),
      cursorColor: HomeColors.lavender,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: big
            ? ReminderText.fieldHint
            : ReminderText.fieldHint.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        counterText: '',
        filled: true,
        fillColor: big ? const Color(0xFFF6F4FD) : Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: big ? 24 : 18),
        enabledBorder: border(big ? const Color(0xFFB7ACEB) : HomeColors.divider, 1.5),
        focusedBorder: border(HomeColors.lavender, 2),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final TaskCategory category;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.category, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = TaskColors.category(category);
    return Material(
      color: selected ? color.withValues(alpha: 0.16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? color : HomeColors.divider, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(category.label,
                  style: ReminderText.chip.copyWith(color: HomeColors.ink, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityButton extends StatelessWidget {
  final TaskPriority priority;
  final bool selected;
  final VoidCallback onTap;
  const _PriorityButton({required this.priority, required this.selected, required this.onTap});

  String get _label => switch (priority) {
        TaskPriority.low => 'Low',
        TaskPriority.medium => 'Medium',
        TaskPriority.high => 'High',
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HomeColors.lavender : HomeColors.lavenderLight,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (priority == TaskPriority.high) ...[
                Icon(Icons.flag_rounded,
                    size: 18, color: selected ? Colors.white : HomeColors.coral),
                const SizedBox(width: 6),
              ],
              Text(_label,
                  style: ReminderText.chip.copyWith(
                      color: selected ? Colors.white : HomeColors.lavender)),
            ],
          ),
        ),
      ),
    );
  }
}

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