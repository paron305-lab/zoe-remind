import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/database/models/task.dart';
import 'package:zoe_remind/database/repositories/task_repository.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/home/widgets/zoe_fab.dart';
import 'package:zoe_remind/features/tasks/controllers/task_list_logic.dart';
import 'package:zoe_remind/features/tasks/widgets/delete_task_dialog.dart';
import 'package:zoe_remind/features/tasks/widgets/task_card.dart';
import 'package:zoe_remind/features/tasks/widgets/task_filter_chips.dart';
import 'package:zoe_remind/features/tasks/widgets/task_styles.dart';
import 'package:zoe_remind/features/tasks/widgets/tasks_empty_state.dart';

/// Tasks tab: filter chips, tasks grouped by day, + button → New Task screen.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const _snackDuration = Duration(seconds: 2);

  final _repo = TaskRepository();
  final _search = TextEditingController();

  List<Task> _all = const [];
  TaskFilter _filter = TaskFilter.all;
  bool _loading = true;
  bool _failed = false;
  bool _searching = false;
  Timer? _snackTimer;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _snackTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  // ---------- data ----------

  Future<void> _load() async {
    try {
      final tasks = await _repo.getAll();
      if (!mounted) return;
      setState(() {
        _all = tasks;
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('Loading tasks failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _replace(Task updated) {
    setState(() {
      _all = [for (final t in _all) t.id == updated.id ? updated : t];
    });
  }

  Future<void> _toggle(Task task, {bool showUndo = true}) async {
    final id = task.id;
    if (id == null) return;
    final nowDone = !task.isDone;

    // update the UI right away, then save
    _replace(task.copyWith(
      status: nowDone ? Task.statusDone : Task.statusPending,
      completedAt: nowDone ? DateTime.now().toIso8601String() : null,
      clearCompletedAt: !nowDone,
    ));
    if (nowDone) HapticFeedback.lightImpact();

    try {
      await _repo.setDone(id, nowDone);
    } catch (e) {
      debugPrint('Updating task failed: $e');
      _replace(task); // put it back
      _snack("Couldn't update the task. Please try again.");
      return;
    }

    if (nowDone && showUndo && mounted) {
      _snack(
        'Nice! "${task.title}" done ✨',
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            _snackTimer?.cancel();
            final current = _all.where((t) => t.id == id).firstOrNull;
            if (current != null && current.isDone) _toggle(current, showUndo: false);
          },
        ),
      );
    }
  }

  Future<void> _delete(Task task) async {
    final id = task.id;
    if (id == null) return;
    setState(() => _all = _all.where((t) => t.id != id).toList());
    try {
      await _repo.delete(id);
      _snack('Task deleted');
    } catch (e) {
      debugPrint('Deleting task failed: $e');
      _snack("Couldn't delete the task.");
      _load();
    }
  }

  // ---------- navigation ----------

  Future<void> _openNew() async {
    final saved = await context.push<bool>('/tasks/new');
    if (saved == true) {
      await _load();
      _snack('Task saved ✨');
    }
  }

  Future<void> _openEdit(Task task) async {
    final changed = await context.push<bool>('/tasks/edit/${task.id}');
    if (changed == true) await _load();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
  }

  // ---------- snackbar ----------

  /// Shows a Zoe-style snackbar (floating, rounded, mint) for 2 seconds.
  /// Newer Flutter keeps snackbars that have an action (Undo) on screen,
  /// so a timer closes it ourselves.
  void _snack(String text, {SnackBarAction? action}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    _snackTimer?.cancel();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: HomeColors.mint,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
          duration: _snackDuration,
          action: action,
        ),
      );

    _snackTimer = Timer(_snackDuration, messenger.hideCurrentSnackBar);
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final summary = TaskListLogic.weekSummary(_all, now);
    final visible = TaskListLogic.applyFilter(_all, _filter, now, query: _search.text);
    final groups = TaskListLogic.group(visible, _filter, now);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: HomeColors.cream,
        floatingActionButton: ZoeFab(onTap: _openNew, size: 64),
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: HomeColors.lavender,
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 110),
              children: [
                _Header(
                  subtitle: TaskListLogic.weekSummaryText(summary),
                  searching: _searching,
                  onSearchTap: _toggleSearch,
                ),
                if (_searching) _SearchField(controller: _search),
                const SizedBox(height: 22),
                TaskFilterChips(
                  selected: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(color: HomeColors.lavender),
                    ),
                  )
                else if (_failed)
                  _ErrorState(onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  })
                else if (groups.isEmpty)
                  TasksEmptyState(filter: _filter, searching: _search.text.trim().isNotEmpty)
                else
                  for (final g in groups) ..._buildGroup(g),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroup(TaskGroup g) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 14),
          child: Text(
            g.label.toUpperCase(),
            style: g.warn
                ? TaskText.groupLabel.copyWith(color: HomeColors.coral)
                : TaskText.groupLabel,
          ),
        ),
        for (final t in g.tasks)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Dismissible(
              key: ValueKey('task-${t.id}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => confirmDeleteTask(context, t.title),
              onDismissed: (_) => _delete(t),
              background: const _DeleteBackground(),
              child: TaskCard(
                task: t,
                showDate: g.showDate,
                onToggle: () => _toggle(t),
                onTap: () => _openEdit(t),
              ),
            ),
          ),
      ];
}

class _Header extends StatelessWidget {
  final String subtitle;
  final bool searching;
  final VoidCallback onSearchTap;

  const _Header({required this.subtitle, required this.searching, required this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tasks', style: TaskText.screenTitle),
                const SizedBox(height: 4),
                Text(subtitle, style: TaskText.subtitle),
              ],
            ),
          ),
          Material(
            color: HomeColors.lavenderLight,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onSearchTap,
              child: SizedBox(
                width: 64,
                height: 64,
                child: Icon(
                  searching ? Icons.close_rounded : Icons.search_rounded,
                  color: HomeColors.lavender,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        cursorColor: HomeColors.lavender,
        style: TaskText.cardTitle.copyWith(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search tasks…',
          hintStyle: TaskText.cardMeta,
          prefixIcon: const Icon(Icons.search_rounded, color: HomeColors.lavender),
          filled: true,
          fillColor: TaskColors.searchFill,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 28),
      decoration: BoxDecoration(
        color: HomeColors.coralLight,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(Icons.delete_outline_rounded, color: HomeColors.coral, size: 28),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Text("Hindi ko ma-load ang tasks mo",
              textAlign: TextAlign.center, style: TaskText.emptyTitle),
          const SizedBox(height: 6),
          const Text('Something went wrong reading your tasks.',
              textAlign: TextAlign.center, style: TaskText.emptyBody),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: const Text('Try again',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: HomeColors.lavender)),
          ),
        ],
      ),
    );
  }
}