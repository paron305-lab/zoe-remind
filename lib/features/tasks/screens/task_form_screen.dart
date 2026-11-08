import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/task.dart';
import 'package:zoe_remind/database/models/task_category.dart';
import 'package:zoe_remind/database/repositories/task_category_repository.dart';
import 'package:zoe_remind/database/repositories/task_repository.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/reminders/widgets/new_reminder_widgets.dart';
import 'package:zoe_remind/features/tasks/widgets/category_sheet.dart';
import 'package:zoe_remind/features/tasks/widgets/delete_task_dialog.dart';

enum _QuickPick { today, tomorrow, weekend, noDate, custom }

/// New Task / Edit Task. Opened from the + button (new) or by tapping a
/// task (edit). Pops `true` when something was saved or deleted so the
/// Tasks screen knows to reload.
///
/// History 🔒 task (done, at lumipas na ang araw) → read-only:
/// walang edit, walang delete.
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
  final _categoryRepo = TaskCategoryRepository();
  final _title = TextEditingController();
  final _notes = TextEditingController();

  Task? _original; // set when editing
  DateTime? _date;
  TimeOfDay? _time;
  _QuickPick? _pick;
  TaskCategories _categories = TaskCategories.empty;
  String _category = Task.defaultCategory;
  TaskPriority _priority = TaskPriority.medium;

  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.taskId != null;

  /// Done at lumipas na ang araw → history, hindi na mababago.
  bool get _locked => _original?.isLockedAt(DateTime.now()) ?? false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _loading = true;
    if (_isEdit) {
      _loadTask();
    } else {
      _pick = _QuickPick.today;
      _date = _today;
      _loadCategories(pickDefault: true);
    }
  }

  Future<void> _loadCategories({bool pickDefault = false}) async {
    try {
      final cats = await _categoryRepo.getLookup();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        if (pickDefault) _category = cats.defaultKey;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Loading categories failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
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
    final cats = await _categoryRepo.getLookup();
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
      _categories = cats;
      _category = cats.has(task.category) ? task.category : Task.noCategory;
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

  bool get _canSave =>
      !_locked && _cleanTitle.isNotEmpty && !_isPastDate && !_saving && !_loading;

  ZoeHintBanner _banner() {
    if (_locked) {
      return const ZoeHintBanner(
        tone: BannerTone.ok,
        text: 'Tapos na ito, ',
        boldText: 'kasama na sa history mo.',
      );
    }
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
      boldText: '$when · ${_categories.label(_category)}.',
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
    } on TaskLockedException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
    } on TaskLockedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } catch (e) {
      debugPrint('Deleting task failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't delete the task.")),
      );
    }
  }

  // ---------- categories ----------

  /// Tap ulit sa naka-select → walang category.
  void _selectCategory(String key) {
    setState(() => _category = _category == key ? Task.noCategory : key);
  }

  Future<void> _addCategory() async {
    final saved = await showCategorySheet(context);
    if (saved == null || !mounted) return;
    await _loadCategories();
    if (!mounted) return;
    setState(() => _category = saved.key);
  }

  Future<void> _categoryMenu(TaskCategory c) async {
    final action = await showCategoryActions(context, c);
    if (action == null || !mounted) return;
    switch (action) {
      case CategoryAction.edit:
        final saved = await showCategorySheet(context, existing: c);
        if (saved != null) await _loadCategories();
      case CategoryAction.delete:
        await _deleteCategory(c);
    }
  }

  Future<void> _deleteCategory(TaskCategory c) async {
    try {
      final count = await _categoryRepo.taskCount(c.key);
      if (!mounted) return;
      final ok = await confirmDeleteCategory(context, c.label, count);
      if (!ok) return;
      await _categoryRepo.delete(c.key);
      await _loadCategories();
      if (!mounted) return;
      if (_category == c.key) setState(() => _category = Task.noCategory);
    } catch (e) {
      debugPrint('Deleting category failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't delete the category.")),
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
                      child: Text(
                          _locked
                              ? 'Task'
                              : _isEdit
                                  ? 'Edit Task'
                                  : 'New Task',
                          style: ReminderText.screenTitle),
                    ),
                    if (_isEdit && _original != null && !_locked)
                      _DeleteButton(onTap: _delete),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: HomeColors.lavender))
                    : _form(),
              ),
              if (!_locked)
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
    final editable = !_locked;
    void noop() {}

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
            enabled: editable,
          ),
          const FieldLabel('Notes (optional)'),
          _InputBox(
            controller: _notes,
            hint: 'Details, links, reminders to self…',
            maxLength: _maxNotes,
            minLines: 3,
            maxLines: 6,
            enabled: editable,
          ),
          const FieldLabel('When'),
          Row(
            children: [
              Expanded(
                child: PickerField(
                  icon: Icons.calendar_today_outlined,
                  value: _date == null ? null : ZoeDate.pretty(_date!),
                  placeholder: 'No date',
                  onTap: editable ? _pickDate : noop,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: PickerField(
                  icon: Icons.access_time_rounded,
                  value: _time == null ? null : ZoeDate.prettyTime(_time!),
                  placeholder: 'Any time',
                  onTap: editable ? _pickTime : noop,
                ),
              ),
            ],
          ),
          if (_time != null && editable)
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
                  onTap: editable ? () => _applyQuickPick(pick) : noop,
                ),
            ],
          ),
          const FieldLabel('Category'),
          if (_category == Task.noCategory)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                editable
                    ? 'No category · pumili sa baba o pindutin ang + Add'
                    : TaskCategories.noneLabel,
                style: ReminderText.fieldHint.copyWith(fontSize: 14),
              ),
            ),
          _CategoryRow(
            categories: _categories.list,
            selected: _category,
            enabled: editable,
            onSelect: _selectCategory,
            onLongPress: _categoryMenu,
            onAdd: _addCategory,
          ),
          if (editable && _categories.list.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Long-press a category to edit or delete it.',
                  style: ReminderText.fieldHint.copyWith(fontSize: 12)),
            ),
          const FieldLabel('Priority'),
          Row(
            children: [
              for (final p in TaskPriority.values) ...[
                Expanded(
                  child: _PriorityButton(
                    priority: p,
                    selected: p == _priority,
                    onTap: editable ? () => setState(() => _priority = p) : null,
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
  final bool enabled;

  const _InputBox({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.big = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: c, width: w),
        );

    return TextField(
      controller: controller,
      readOnly: !enabled,
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

/// Horizontal scroll ng categories + "+ Add" sa dulo.
class _CategoryRow extends StatelessWidget {
  final List<TaskCategory> categories;
  final String selected;
  final bool enabled;
  final ValueChanged<String> onSelect;
  final ValueChanged<TaskCategory> onLongPress;
  final VoidCallback onAdd;

  const _CategoryRow({
    required this.categories,
    required this.selected,
    required this.enabled,
    required this.onSelect,
    required this.onLongPress,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final c in categories) ...[
            CategoryChipView(
              label: c.label,
              color: c.colorValue,
              selected: c.key == selected,
              enabled: enabled,
              onTap: () => onSelect(c.key),
              onLongPress: () => onLongPress(c),
            ),
            const SizedBox(width: 10),
          ],
          if (enabled) AddCategoryChip(onTap: onAdd),
        ],
      ),
    );
  }
}

class _PriorityButton extends StatelessWidget {
  final TaskPriority priority;
  final bool selected;
  final VoidCallback? onTap; // null = read-only
  const _PriorityButton({required this.priority, required this.selected, this.onTap});

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