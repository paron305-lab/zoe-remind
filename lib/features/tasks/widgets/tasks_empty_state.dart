import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/zoe_avatar.dart';
import 'package:zoe_remind/features/tasks/controllers/task_list_logic.dart';
import 'package:zoe_remind/features/tasks/widgets/task_styles.dart';

/// Friendly message instead of a blank list.
class TasksEmptyState extends StatelessWidget {
  final TaskFilter filter;
  final bool searching;

  const TasksEmptyState({super.key, required this.filter, this.searching = false});

  (String, String) get _copy {
    if (searching) {
      return ('Walang nahanap', 'Try a different word or clear the search.');
    }
    return switch (filter) {
      TaskFilter.all => (
          'Wala ka pang tasks!',
          'Tap the + button para gumawa ng una mong task.'
        ),
      TaskFilter.today => (
          'Wala kang task today',
          'Enjoy your free time — or tap + to plan something.'
        ),
      TaskFilter.upcoming => (
          'Nothing coming up',
          'Tasks you plan for later will show here.'
        ),
      TaskFilter.done => (
          'Wala pang natatapos',
          'Check off a task and it will show up here. Kaya mo yan!'
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (title, body) = _copy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 56, 40, 40),
      child: Column(
        children: [
          const ZoeAvatar(size: 72),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: TaskText.emptyTitle),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: TaskText.emptyBody),
        ],
      ),
    );
  }
}