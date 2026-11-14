import 'package:flutter/material.dart';
import 'package:zoe_remind/database/models/task_category.dart';
import 'package:zoe_remind/database/repositories/task_category_repository.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/reminders/widgets/new_reminder_widgets.dart';
import 'package:zoe_remind/features/tasks/widgets/task_styles.dart';

const _f = 'Poppins';

/// Add (existing == null) or Edit a category.
/// Returns the saved category, or null if cancelled.
Future<TaskCategory?> showCategorySheet(BuildContext context, {TaskCategory? existing}) {
  return showModalBottomSheet<TaskCategory>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HomeColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _CategorySheet(existing: existing),
  );
}

enum CategoryAction { edit, delete }

/// Long-press menu: Edit / Delete.
Future<CategoryAction?> showCategoryActions(BuildContext context, TaskCategory category) {
  return showModalBottomSheet<CategoryAction>(
    context: context,
    backgroundColor: HomeColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 12),
                _Dot(color: category.colorValue, size: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(category.label,
                      style: TextStyle(
                          fontFamily: _f,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.ink)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: HomeColors.lavender),
              title: Text('Edit',
                  style: TextStyle(
                      fontFamily: _f, fontWeight: FontWeight.w600, color: HomeColors.ink)),
              subtitle: Text('Palitan ang pangalan o kulay',
                  style: TextStyle(fontFamily: _f, color: HomeColors.inkSoft)),
              onTap: () => Navigator.pop(ctx, CategoryAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: HomeColors.coral),
              title: const Text('Delete',
                  style: TextStyle(
                      fontFamily: _f, fontWeight: FontWeight.w600, color: HomeColors.coral)),
              onTap: () => Navigator.pop(ctx, CategoryAction.delete),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Delete asks first. [taskCount] = how many tasks use this category.
Future<bool> confirmDeleteCategory(BuildContext context, String label, int taskCount) async {
  final affected = taskCount == 0
      ? 'Walang task na gumagamit nito.'
      : taskCount == 1
          ? '1 task will become "No category".'
          : '$taskCount tasks will become "No category".';

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: HomeColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('Delete "$label"?',
          style: TextStyle(
              fontFamily: _f, fontWeight: FontWeight.w700, color: HomeColors.ink)),
      content: Text(affected,
          style: TextStyle(
              fontFamily: _f, fontSize: 15, color: HomeColors.inkSoft, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel',
              style: TextStyle(
                  fontFamily: _f, fontWeight: FontWeight.w700, color: HomeColors.inkSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete',
              style: TextStyle(
                  fontFamily: _f, fontWeight: FontWeight.w700, color: HomeColors.coral)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _CategorySheet extends StatefulWidget {
  final TaskCategory? existing;
  const _CategorySheet({this.existing});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _repo = TaskCategoryRepository();
  late final TextEditingController _name;
  late int _color;
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.label ?? '');
    _name.addListener(() => setState(() => _error = null));
    _color = widget.existing?.color ?? TaskColors.categoryPresets.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final saved = existing == null
          ? await _repo.add(_name.text, _color)
          : await _repo.update(existing, _name.text, _color);
      if (!mounted) return;
      Navigator.pop(context, saved);
    } on CategoryNameException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } catch (e) {
      debugPrint('Saving category failed: $e');
      if (!mounted) return;
      setState(() {
        _error = "Couldn't save. Please try again.";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _name.text.trim().isEmpty ? 'Category' : _name.text.trim();
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide(color: HomeColors.divider, width: 1.5),
    );

    return Padding(
      // keeps the sheet above the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: HomeColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(_isEdit ? 'Edit category' : 'New category',
                  style: TextStyle(
                      fontFamily: _f,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: HomeColors.ink)),
              const FieldLabel('Name'),
              TextField(
                controller: _name,
                autofocus: !_isEdit,
                maxLength: TaskCategory.maxLabel,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                cursorColor: HomeColors.lavender,
                style: ReminderText.field.copyWith(fontSize: 17),
                decoration: InputDecoration(
                  hintText: 'e.g. Gym, Family, Side project',
                  hintStyle: ReminderText.fieldHint.copyWith(fontSize: 15),
                  errorText: _error,
                  errorStyle: const TextStyle(fontFamily: _f, color: HomeColors.coral),
                  filled: true,
                  fillColor: HomeColors.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                      borderSide: BorderSide(color: HomeColors.lavender, width: 2)),
                  errorBorder: border.copyWith(
                      borderSide: const BorderSide(color: HomeColors.coral, width: 1.5)),
                  focusedErrorBorder: border.copyWith(
                      borderSide: const BorderSide(color: HomeColors.coral, width: 2)),
                ),
              ),
              const FieldLabel('Color'),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final c in TaskColors.categoryPresets)
                    _Swatch(
                      color: Color(c),
                      selected: c == _color,
                      onTap: () => setState(() => _color = c),
                    ),
                ],
              ),
              const FieldLabel('Preview'),
              CategoryChipView(
                label: preview,
                color: Color(_color),
                selected: true,
              ),
              const SizedBox(height: 24),
              GradientButton(
                label: _isEdit ? 'Save changes' : 'Add category',
                loading: _saving,
                onTap: _name.text.trim().isEmpty ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? HomeColors.ink : HomeColors.card,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8),
            ],
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
              : null,
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  const _Dot({required this.color, this.size = 10});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// The category chip look (used in the form and in the preview).
class CategoryChipView extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const CategoryChipView({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    this.enabled = true,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled || selected ? 1 : 0.5,
      child: Material(
        color: selected ? color.withValues(alpha: 0.16) : HomeColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? color : HomeColors.divider, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(color: color),
                const SizedBox(width: 8),
                Text(label,
                    style: ReminderText.chip.copyWith(color: HomeColors.ink, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "+ Add" chip at the end of the category row.
class AddCategoryChip extends StatelessWidget {
  final VoidCallback onTap;
  const AddCategoryChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.lavenderLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 18, color: HomeColors.lavender),
              const SizedBox(width: 6),
              Text('Add',
                  style: ReminderText.chip.copyWith(color: HomeColors.lavender, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}