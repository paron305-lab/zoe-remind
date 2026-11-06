import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/core/widgets/zoe_snackbar.dart';
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/home/models/home_item.dart';
import 'package:zoe_remind/features/home/widgets/home_header.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/home/widgets/reminder_board.dart';
import 'package:zoe_remind/features/home/widgets/timeline_stats.dart';
import 'package:zoe_remind/features/home/widgets/zoe_fab.dart';
import 'package:zoe_remind/features/reminders/screens/reminder_form_screen.dart';
import 'package:zoe_remind/features/reminders/widgets/delete_reminder_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _reminders = ReminderRepository();

  String _userName = '';
  List<HomeItem> _today = const [];
  List<HomeItem> _upcoming = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadName();
    _loadItems();
  }

  Future<void> _loadName() async {
    final name = await SettingsRepository().getUserName();
    if (!mounted) return;
    setState(() => _userName = (name == null || name.isEmpty) ? 'there' : name);
  }

  HomeItem _toItem(Reminder r, DateTime day, {bool showDate = false}) => HomeItem(
        id: '${r.id}',
        title: r.title,
        time: ZoeDate.parseTime(r.time),
        type: HomeItemType.reminder,
        done: r.isDoneOn(day),
        dateLabel: showDate ? ZoeDate.relative(day) : null,
        repeats: r.repeat != ReminderRepeat.none,
      );

  Future<void> _loadItems() async {
    try {
      final today = ZoeDate.dayOnly(DateTime.now());
      final todayList = await _reminders.getForDay(today);
      final upcoming = await _reminders.getUpcoming(days: 30);
      if (!mounted) return;
      setState(() {
        _today = [for (final r in todayList) _toItem(r, today)];
        _upcoming = [
          for (final (day, r) in upcoming) _toItem(r, day, showDate: true),
        ];
        _loading = false;
      });
    } catch (e) {
      debugPrint('Loading reminders failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(HomeItem item) async {
    final id = int.tryParse(item.id);
    if (id == null) return;
    // update the UI right away, then save
    setState(() {
      _today = [
        for (final i in _today) i.id == item.id ? i.copyWith(done: !i.done) : i,
      ];
    });
    await _reminders.setDoneOn(id, DateTime.now(), !item.done);
  }

  // ---------- delete (swipe left) ----------

  Future<bool> _confirmDelete(HomeItem item) =>
      confirmDeleteReminder(context, item.title, repeats: item.repeats);

  Future<void> _delete(HomeItem item) async {
    final id = int.tryParse(item.id);
    if (id == null) return;
    // remove right away (a repeating one can be in both lists)
    setState(() {
      _today = _today.where((i) => i.id != item.id).toList();
      _upcoming = _upcoming.where((i) => i.id != item.id).toList();
    });
    try {
      await _reminders.delete(id);
      if (mounted) ZoeSnack.show(context, 'Reminder deleted');
    } catch (e) {
      debugPrint('Deleting reminder failed: $e');
      if (mounted) ZoeSnack.show(context, "Couldn't delete the reminder.", error: true);
    }
    await _loadItems();
  }

  // ---------- navigation ----------

  Future<void> _openNewReminder() async {
    final result = await context.push<String>('/reminders/new');
    if (result == null) return;
    await _loadItems();
    if (mounted) ZoeSnack.show(context, 'Reminder saved ✨');
  }

  Future<void> _openEdit(HomeItem item) async {
    final result = await context.push<String>('/reminders/edit/${item.id}');
    if (result == null) return;
    await _loadItems();
    if (!mounted) return;
    switch (result) {
      case ReminderFormResult.updated:
        ZoeSnack.show(context, 'Changes saved ✨');
      case ReminderFormResult.deleted:
        ZoeSnack.show(context, 'Reminder deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _today.where((i) => i.done).length;
    final left = _today.length - done;
    final reminders = _today.where((i) => i.type == HomeItemType.reminder).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // puting status bar icons sa ibabaw ng gradient
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: HomeColors.cream,
        floatingActionButton: ZoeFab(onTap: _openNewReminder),
        body: RefreshIndicator(
          color: HomeColors.lavender,
          onRefresh: _loadItems,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              children: [
                HomeHeader(userName: _userName, total: _today.length, done: done),
                // iaangat ng 44px para pumatong ang board sa header
                Transform.translate(
                  offset: const Offset(0, -44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: CircularProgressIndicator(color: HomeColors.lavender),
                          ),
                        )
                      else
                        ReminderBoard(
                          items: _today,
                          onToggle: _toggle,
                          onTap: _openEdit,
                          confirmDelete: _confirmDelete,
                          onDelete: _delete,
                        ),
                      const SizedBox(height: 20),
                      TimelineStats(tasksLeft: left, reminders: reminders, streak: 7),
                      if (_upcoming.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 28, 20, 14),
                          child: Text('Coming up', style: HomeText.sectionTitle),
                        ),
                        ReminderBoard(
                          items: _upcoming,
                          onTap: _openEdit,
                          confirmDelete: _confirmDelete,
                          onDelete: _delete,
                        ),
                      ],
                    ],
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