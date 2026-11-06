import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/tasks/controllers/task_list_logic.dart';
import 'package:zoe_remind/features/tasks/widgets/task_styles.dart';

/// All / Today / Upcoming / Done — one tap to switch.
class TaskFilterChips extends StatelessWidget {
  final TaskFilter selected;
  final ValueChanged<TaskFilter> onChanged;

  const TaskFilterChips({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final f in TaskFilter.values) ...[
            _Chip(label: f.label, selected: f == selected, onTap: () => onChanged(f)),
            if (f != TaskFilter.values.last) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? HomeColors.lavender : HomeColors.lavenderLight,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Text(
              label,
              style: TaskText.chip
                  .copyWith(color: selected ? Colors.white : HomeColors.lavender),
            ),
          ),
        ),
      ),
    );
  }
}