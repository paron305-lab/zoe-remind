import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _userName = '';

  // DEMO DATA muna — papalitan natin ng TaskRepository sa susunod
  List<HomeItem> _items = const [
    HomeItem(id: '1', title: 'Morning study block', time: TimeOfDay(hour: 9, minute: 0), type: HomeItemType.task, done: true),
    HomeItem(id: '2', title: 'Grocery run', time: TimeOfDay(hour: 15, minute: 0), type: HomeItemType.task),
    HomeItem(id: '3', title: 'Workout — leg day', time: TimeOfDay(hour: 18, minute: 0), type: HomeItemType.habit),
    HomeItem(id: '4', title: 'Review Chapter 3', time: TimeOfDay(hour: 20, minute: 0), type: HomeItemType.reminder),
  ];

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await SettingsRepository().getUserName();
    if (!mounted) return;
    setState(() => _userName = (name == null || name.isEmpty) ? 'there' : name);
  }

  void _toggle(HomeItem item) {
    setState(() {
      _items = [
        for (final i in _items) i.id == item.id ? i.copyWith(done: !i.done) : i,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _items.where((i) => i.done).length;
    final left = _items.length - done;
    final reminders = _items.where((i) => i.type == HomeItemType.reminder).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // puting status bar icons sa ibabaw ng gradient
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: HomeColors.cream,
        floatingActionButton: ZoeFab(
          onTap: () {
            // TODO: context.push('/reminders/new');
          },
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            children: [
              HomeHeader(userName: _userName, total: _items.length, done: done),
              // iaangat ng 44px para pumatong ang board sa header
              Transform.translate(
                offset: const Offset(0, -44),
                child: Column(
                  children: [
                    ReminderBoard(items: _items, onToggle: _toggle),
                    const SizedBox(height: 28),
                    TimelineStats(tasksLeft: left, reminders: reminders, streak: 7),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}