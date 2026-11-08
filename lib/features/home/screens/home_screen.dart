import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
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
import 'package:zoe_remind/features/reminders/models/reminder_status.dart';
import 'package:zoe_remind/features/reminders/screens/reminder_form_screen.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
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
  bool _remindersOn = true;
  ZoeLanguage _language = ZoeLanguage.both;

  /// Bawat minuto: i-refresh para maging "Missed" / "Done ✓" ang lumipas na.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _loadName();
    _loadItems();
    // Done / Snooze / Dismiss sa ringing screen -> i-refresh ang Home
    ReminderAlarmService.instance.changes.addListener(_loadItems);
    _loadRemindersOn();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _loadItems());
  }

  // ---------- bell: reminders ON / OFF ----------

  Future<void> _loadRemindersOn() async {
    final on = await ReminderAlarmService.instance.loadEnabled();
    if (mounted) setState(() => _remindersOn = on);
  }

  Future<void> _toggleReminders() async {
    final on = !_remindersOn;
    setState(() => _remindersOn = on); // palitan agad ang kulay
    HapticFeedback.lightImpact();
    await ReminderAlarmService.instance.setEnabled(on);
    if (!mounted) return;
    ZoeSnack.show(
      context,
      on ? 'Reminders ON 🔔 — tutunog na si Zoe' : 'Reminders OFF 🔕 — walang tutunog',
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    ReminderAlarmService.instance.changes.removeListener(_loadItems);
    super.dispose();
  }

  Future<void> _loadName() async {
    final settings = SettingsRepository();
    final name = await settings.getUserName();
    final language = await settings.getLanguage();
    if (!mounted) return;
    setState(() {
      _userName = (name == null || name.isEmpty) ? 'there' : name;
      _language = language;
    });
  }

  HomeItem _toItem(
    Reminder r,
    DateTime day, {
    bool showDate = false,
    required DateTime now,
    Map<int, DateTime> activeAlarms = const {},
  }) {
    // May alarm pa para sa occurrence na ito (naka-snooze / nagri-ring)?
    final at = ReminderStatusRules.occurrenceTime(r, day);
    final pendingAt = activeAlarms[r.id];
    final alarmPending = pendingAt != null &&
        pendingAt.year == at.year &&
        pendingAt.month == at.month &&
        pendingAt.day == at.day &&
        pendingAt.hour == at.hour &&
        pendingAt.minute == at.minute;

    final status =
        ReminderStatusRules.statusOn(r, day, now: now, alarmPending: alarmPending);
    return HomeItem(
      id: '${r.id}',
      title: r.title,
      time: ZoeDate.parseTime(r.time),
      type: HomeItemType.reminder,
      done: status.isDone,
      dateLabel: showDate ? ZoeDate.relative(day) : null,
      repeats: r.repeat != ReminderRepeat.none,
      day: day,
      status: status,
    );
  }

  Future<void> _loadItems() async {
    try {
      final now = DateTime.now();
      final today = ZoeDate.dayOnly(now);
      final todayList = await _reminders.getForDay(today);
      final upcoming = await _reminders.getUpcoming(days: 30);
      final active = await ReminderAlarmService.instance.activeAlarmOccurrences();
      if (!mounted) return;
      setState(() {
        _today = [
          for (final r in todayList) _toItem(r, today, now: now, activeAlarms: active),
        ];
        _upcoming = [
          for (final (day, r) in upcoming)
            _toItem(r, day, showDate: true, now: now, activeAlarms: active),
        ];
        _loading = false;
      });
    } catch (e) {
      debugPrint('Loading reminders failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Checkbox — gumagana lang kapag HINDI PA oras (check nang maaga / uncheck).
  Future<void> _toggle(HomeItem item) async {
    final id = int.tryParse(item.id);
    if (id == null || item.locked || !item.status.showsCheckbox) return;
    final done = !item.done;
    // update the UI right away, then save
    setState(() {
      _today = [
        for (final i in _today)
          i.id == item.id
              ? i.copyWith(
                  done: done,
                  status: done ? ReminderStatus.doneEarly : ReminderStatus.upcoming)
              : i,
      ];
    });
    await _reminders.setDoneOn(id, item.day ?? DateTime.now(), done);
    await ReminderAlarmService.instance.syncById(id); // cancel o next day
    await _loadItems();
  }

  /// Pinindot ang "Missed" / "Dismissed" → tanungin kung tapos na (late).
  Future<void> _markLate(HomeItem item) async {
    final id = int.tryParse(item.id);
    if (id == null || !item.status.canMarkLate) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'Tapos mo na ba ito?',
          style: TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: HomeColors.ink),
        ),
        content: Text(
          '"${item.title}" — ${item.status.label(_language)} kanina. '
          'Kapag minark mo as done, mapupunta na ito sa history mo 🔒.',
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 15, color: HomeColors.inkSoft, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hindi pa',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: HomeColors.inkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark as done',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: HomeColors.mint)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _reminders.setDoneOn(id, item.day ?? DateTime.now(), true);
    await ReminderAlarmService.instance.syncById(id);
    await _loadItems();
    if (mounted) ZoeSnack.show(context, 'Nice! Nasa history na ✓');
  }

  // ---------- delete (swipe left) ----------

  Future<bool> _confirmDelete(HomeItem item) =>
      confirmDeleteReminder(context, item.title, repeats: item.repeats);

  Future<void> _delete(HomeItem item) async {
    final id = int.tryParse(item.id);
    if (id == null || item.locked) return; // history 🔒 → bawal i-delete
    // remove right away (a repeating one can be in both lists)
    setState(() {
      _today = _today.where((i) => i.id != item.id).toList();
      _upcoming = _upcoming.where((i) => i.id != item.id).toList();
    });
    try {
      await _reminders.delete(id);
      await ReminderAlarmService.instance.cancel(id); // cancel alarm
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
    // History 🔒 → read-only view
    final path = item.locked
        ? '/reminders/edit/${item.id}?view=1'
        : '/reminders/edit/${item.id}';
    final result = await context.push<String>(path);
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
                HomeHeader(
                  userName: _userName,
                  total: _today.length,
                  done: done,
                  remindersOn: _remindersOn,
                  onBellTap: _toggleReminders,
                ),
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
                          language: _language,
                          onToggle: _toggle,
                          onTap: _openEdit,
                          confirmDelete: _confirmDelete,
                          onDelete: _delete,
                          onStatusTap: _markLate,
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
                          language: _language,
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