import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/reminder.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/home/models/home_item.dart';
import 'package:zoe_remind/features/home/widgets/home_header.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/home/widgets/reminder_board.dart';
import 'package:zoe_remind/features/home/widgets/timeline_stats.dart';
import 'package:zoe_remind/features/home/widgets/zoe_fab.dart';

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

  Future<void> _openNewReminder() async {
    final created = await context.push<bool>('/reminders/new');
    if (created == true) {
      await _loadItems();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder saved ✨')),
      );
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
                        ReminderBoard(items: _today, onToggle: _toggle),
                      const SizedBox(height: 20),
                      TimelineStats(tasksLeft: left, reminders: reminders, streak: 7),
                      if (_upcoming.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 28, 20, 14),
                          child: Text('Coming up', style: HomeText.sectionTitle),
                        ),
                        ReminderBoard(items: _upcoming),
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