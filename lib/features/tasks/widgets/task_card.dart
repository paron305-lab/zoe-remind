import 'package:flutter/material.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/task.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/tasks/widgets/task_styles.dart';

/// One task row: checkbox · title + "9:00 AM · Study" · category dot.
class TaskCard extends StatelessWidget {
  final Task task;
  final bool showDate;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
    this.showDate = false,
  });

  String get _meta {
    final parts = <String>[];
    final day = task.day;
    if (showDate && day != null) parts.add(ZoeDate.relative(day));
    final t = task.timeOfDay;
    if (t != null) parts.add(ZoeDate.prettyTime(t));
    if (parts.isEmpty && day == null) parts.add('No date');
    parts.add(task.category.label);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final done = task.isDone;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: HomeColors.ink.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 22, 18),
            child: Row(
              children: [
                _Checkbox(done: done, onTap: onToggle),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: done
                            ? TaskText.cardTitle.copyWith(
                                color: TaskColors.doneTitle,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: TaskColors.doneTitle,
                                decorationThickness: 2,
                              )
                            : TaskText.cardTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(_meta,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TaskText.cardMeta),
                    ],
                  ),
                ),
                if (task.priority == TaskPriority.high && !done) ...[
                  const Icon(Icons.flag_rounded, size: 18, color: HomeColors.coral),
                  const SizedBox(width: 10),
                ],
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: TaskColors.category(task.category),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded-square checkbox. Done = filled mint + white check
/// (shape and fill change, not only color).
class _Checkbox extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;
  const _Checkbox({required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      button: true,
      label: done ? 'Mark as not done' : 'Mark as done',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4), // bigger tap target
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: done ? HomeColors.mint : Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: done ? HomeColors.mint : HomeColors.checkboxBorder,
                width: 2.5,
              ),
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: done ? 1 : 0,
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}