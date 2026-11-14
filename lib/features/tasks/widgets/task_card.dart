import 'package:flutter/material.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/task.dart';
import 'package:zoe_remind/database/models/task_category.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/tasks/models/task_status.dart';
import 'package:zoe_remind/features/tasks/widgets/task_styles.dart';

/// One task row: checkbox · title + "9:00 AM · Study" · status pill · category dot.
class TaskCard extends StatelessWidget {
  final Task task;
  final TaskStatus status;
  final TaskCategories categories;
  final ZoeLanguage language;
  final bool showDate;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const TaskCard({
    super.key,
    required this.task,
    required this.status,
    required this.categories,
    required this.language,
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
    parts.add(categories.label(task.category));
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final done = status.isDone;
    final locked = status.isLocked;

    return Container(
      decoration: BoxDecoration(
        color: HomeColors.card,
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
                _Checkbox(done: done, locked: locked, onTap: onToggle),
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
                if (status.hasLabel) ...[
                  const SizedBox(width: 8),
                  _StatusPill(status: status, language: language),
                  const SizedBox(width: 10),
                ],
                if (task.priority == TaskPriority.high && !done) ...[
                  const Icon(Icons.flag_rounded, size: 18, color: HomeColors.coral),
                  const SizedBox(width: 10),
                ],
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: categories.color(task.category),
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

/// "Missed" (coral) o "🔒 Done ✓" (mint) sa right side.
class _StatusPill extends StatelessWidget {
  final TaskStatus status;
  final ZoeLanguage language;
  const _StatusPill({required this.status, required this.language});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.isLocked) ...[
            Icon(Icons.lock_rounded, size: 13, color: status.color),
            const SizedBox(width: 4),
          ],
          Text(status.label(language),
              style: TaskText.statusPill.copyWith(color: status.color)),
        ],
      ),
    );
  }
}

/// Rounded-square checkbox. Done = filled mint + white check
/// (shape and fill change, not only color). Locked = faded, can't be tapped.
class _Checkbox extends StatelessWidget {
  final bool done;
  final bool locked;
  final VoidCallback onTap;
  const _Checkbox({required this.done, required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      button: !locked,
      enabled: !locked,
      label: locked
          ? 'Done, saved to history'
          : done
              ? 'Mark as not done'
              : 'Mark as done',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: locked ? null : onTap,
        child: Opacity(
          opacity: locked ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.all(4), // bigger tap target
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: done ? HomeColors.mint : HomeColors.card,
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
      ),
    );
  }
}