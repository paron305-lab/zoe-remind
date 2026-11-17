import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/database/repositories/chat_history_repository.dart';
import 'package:zoe_remind/database/repositories/note_repository.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/statistics_repository.dart';
import 'package:zoe_remind/database/repositories/task_repository.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
import 'package:zoe_remind/features/statistics/widgets/history_cards.dart';
import 'package:zoe_remind/features/statistics/widgets/history_charts.dart';
import 'package:zoe_remind/features/statistics/widgets/history_header.dart';

enum HistoryRange { month, year, allTime }

/// "See all" sa Home → Your Zoe History.
/// Lahat ng numero ay binibilang mula sa zoe.db (StatisticsRepository).
class HistoryStatisticsScreen extends StatefulWidget {
  const HistoryStatisticsScreen({super.key});

  @override
  State<HistoryStatisticsScreen> createState() => _HistoryStatisticsScreenState();
}

class _HistoryStatisticsScreenState extends State<HistoryStatisticsScreen> {
  final _stats = StatisticsRepository();

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  HistoryRange _range = HistoryRange.month;

  /// Unang araw ng buwan (Month) o ng taon (Year) na tinitingnan.
  late DateTime _anchor;

  StatsBuckets? _data;
  DateTime? _earliest;
  bool _loading = true;

  /// Para hindi mag-overwrite ang lumang query kapag mabilis pumindot.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month);
    _load(recordMissed: true);
    NoteRepository.changes.addListener(_reload);
    ChatHistoryRepository.changes.addListener(_reload);
    ReminderAlarmService.instance.changes.addListener(_reload);
  }

  @override
  void dispose() {
    NoteRepository.changes.removeListener(_reload);
    ChatHistoryRepository.changes.removeListener(_reload);
    ReminderAlarmService.instance.changes.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load();

  // ───────────────────────── data ─────────────────────────

  (DateTime, DateTime, StatsGroup) _window() {
    switch (_range) {
      case HistoryRange.month:
        return (
          _anchor,
          DateTime(_anchor.year, _anchor.month + 1),
          StatsGroup.day,
        );
      case HistoryRange.year:
        return (DateTime(_anchor.year), DateTime(_anchor.year + 1), StatsGroup.month);
      case HistoryRange.allTime:
        return (DateTime(1970), DateTime(9999), StatsGroup.year);
    }
  }

  Future<void> _load({bool recordMissed = false}) async {
    final id = ++_request;
    try {
      if (recordMissed) {
        // Siguraduhing naka-record na ang lahat ng Missed bago bumilang.
        final now = DateTime.now();
        final active = await ReminderAlarmService.instance.activeAlarmOccurrences();
        await ReminderRepository().recordMissed(pending: active, now: now);
        await TaskRepository().recordMissed(now: now);
      }
      final (from, to, group) = _window();
      final data = await _stats.load(from: from, to: to, group: group);
      final earliest = await _stats.earliestDay();
      if (!mounted || id != _request) return;
      setState(() {
        _data = data;
        _earliest = earliest;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Loading history failed: $e');
      if (mounted && id == _request) setState(() => _loading = false);
    }
  }

  void _setRange(int i) {
    final r = HistoryRange.values[i];
    if (r == _range) return;
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() {
      _range = r;
      // Month → kasalukuyang buwan ng taong tinitingnan (o ngayon).
      _anchor = r == HistoryRange.month && _anchor.year == now.year
          ? DateTime(now.year, now.month)
          : r == HistoryRange.month
              ? DateTime(_anchor.year, 12)
              : DateTime(_anchor.year, _anchor.month);
      _loading = true;
    });
    _load();
  }

  void _shift(int step) {
    HapticFeedback.selectionClick();
    setState(() {
      _anchor = _range == HistoryRange.month
          ? DateTime(_anchor.year, _anchor.month + step)
          : DateTime(_anchor.year + step, _anchor.month);
      _loading = true;
    });
    _load();
  }

  bool get _canGoNext {
    final now = DateTime.now();
    if (_range == HistoryRange.month) {
      return _anchor.isBefore(DateTime(now.year, now.month));
    }
    return _anchor.year < now.year;
  }

  bool get _canGoPrev {
    final first = _earliest;
    if (first == null) return false;
    if (_range == HistoryRange.month) {
      return _anchor.isAfter(DateTime(first.year, first.month));
    }
    return _anchor.year > first.year;
  }

  bool get _isCurrent {
    final now = DateTime.now();
    if (_range == HistoryRange.month) {
      return _anchor.year == now.year && _anchor.month == now.month;
    }
    return _anchor.year == now.year;
  }

  // ───────────────────────── labels ─────────────────────────

  String get _periodLabel => switch (_range) {
        HistoryRange.month => '${_months[_anchor.month - 1]} ${_anchor.year}',
        HistoryRange.year => '${_anchor.year}',
        HistoryRange.allTime => 'All time',
      };

  String _periodSub(int activities) {
    final n = formatCount(activities);
    final word = activities == 1 ? 'activity' : 'activities';
    switch (_range) {
      case HistoryRange.month:
        return _isCurrent ? '$n $word this month' : '$n $word';
      case HistoryRange.year:
        return _isCurrent ? '$n $word so far' : '$n $word';
      case HistoryRange.allTime:
        final first = _earliest;
        if (first == null) return 'No activity yet';
        return '$n $word since ${_months[first.month - 1].substring(0, 3)} ${first.year}';
    }
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: HomeColors.cream,
        body: RefreshIndicator(
          color: HomeColors.lavender,
          onRefresh: () => _load(recordMissed: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HistoryHeader(
                  periodLabel: _periodLabel,
                  periodSub: data == null ? ' ' : _periodSub(data.totalActivities),
                  onBack: () => context.canPop() ? context.pop() : context.go('/home'),
                  showArrows: _range != HistoryRange.allTime,
                  onPrev: _canGoPrev ? () => _shift(-1) : null,
                  onNext: _canGoNext ? () => _shift(1) : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: HistoryRangeChips(
                    labels: const ['Month', 'Year', 'All time'],
                    selected: _range.index,
                    onSelect: _setRange,
                  ),
                ),
                const SizedBox(height: 22),
                if (data == null && _loading)
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: CircularProgressIndicator(color: HomeColors.lavender),
                    ),
                  )
                else if (data != null)
                  AnimatedOpacity(
                    opacity: _loading ? 0.5 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: switch (_range) {
                        HistoryRange.month => _monthBody(data),
                        HistoryRange.year => _yearBody(data),
                        HistoryRange.allTime => _allTimeBody(data),
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 14, left: 4, right: 4),
        child: Row(
          children: [
            Text(title, style: HomeText.sectionTitle.copyWith(fontSize: 19)),
            const Spacer(),
            Text(
              hint,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: HomeColors.inkSoft),
            ),
          ],
        ),
      );

  Widget _askZoe() => AskZoeBanner(onTap: () => context.go('/chat'));

  // ───────────── Month ─────────────

  Widget _monthBody(StatsBuckets d) {
    final daysInMonth = DateTime(_anchor.year, _anchor.month + 1, 0).day;
    final weekCount = (daysInMonth - 1) ~/ 7 + 1;
    final weeks = List<int>.filled(weekCount, 0);
    d.tasksDone.forEach((key, count) {
      final day = int.tryParse(key.length >= 10 ? key.substring(8, 10) : '');
      if (day == null || day < 1) return;
      final w = (day - 1) ~/ 7;
      weeks[w < weekCount ? w : weekCount - 1] += count;
    });

    final done = d.totalTasksDone;
    var bestWeek = 0;
    for (var i = 1; i < weeks.length; i++) {
      if (weeks[i] > weeks[bestWeek]) bestWeek = i;
    }
    final period = _isCurrent ? 'this month' : 'in ${_months[_anchor.month - 1]}';

    final String title;
    final String body;
    if (done == 0) {
      title = d.totalTasks == 0
          ? 'No tasks $period yet.'
          : 'No tasks completed $period yet.';
      body = d.totalTasks == 0
          ? 'Add a task and Zoe will keep count here.'
          : '${d.totalTasksOpen} still open — you got this 💪';
    } else {
      title = 'You completed ${formatCount(done)} task${done == 1 ? '' : 's'} $period.';
      body = 'Week ${bestWeek + 1} was your busiest — ${weeks[bestWeek]} done.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaskDonutCard(done: done, open: d.totalTasksOpen),
        const SizedBox(height: 16),
        StatGrid(tiles: [
          StatTileData(d.totalReminders, 'Reminders', HomeColors.coral, HomeColors.coralLight),
          StatTileData(d.totalNotes, 'Notes', HomeColors.lavender, HomeColors.lavenderLight),
          StatTileData(d.totalChats, 'Zoe chats', HomeColors.sky, HomeColors.skyLight),
          StatTileData(d.totalMissed, 'Missed', HomeColors.amber, HomeColors.amberLight),
        ]),
        const SizedBox(height: 28),
        _sectionTitle('Activity', 'Tasks completed / week'),
        WeekBarChart(values: weeks),
        const SizedBox(height: 18),
        ZoeInsightCard(title: title, body: body, badge: 'Counted from SQLite'),
        const SizedBox(height: 18),
        _askZoe(),
      ],
    );
  }

  // ───────────── Year ─────────────

  Widget _yearBody(StatsBuckets d) {
    final now = DateTime.now();
    final y = _anchor.year;
    final rows = <OverviewRow>[];
    var bestMonth = -1;
    var bestValue = 0;

    for (var m = 1; m <= 12; m++) {
      final key = '$y-${m.toString().padLeft(2, '0')}';
      final value = d.activitiesFor(key);
      final isFuture = y == now.year && m > now.month;
      if (isFuture && value == 0) continue; // walang ipapakitang darating na buwan
      if (value > bestValue) {
        bestValue = value;
        bestMonth = m;
      }
      rows.add(OverviewRow(
        _months[m - 1].substring(0, 3),
        value,
        highlight: y == now.year && m == now.month,
      ));
    }

    final soFar = _isCurrent ? ' so far' : '';
    final title = bestMonth == -1
        ? 'No activity in $y yet.'
        : 'You were most active in ${_months[bestMonth - 1]}.';
    final body = bestMonth == -1
        ? 'Tasks, reminders, notes and Zoe chats will show up here.'
        : '${formatCount(bestValue)} activities — your busiest month of $y$soFar.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Monthly overview', 'Activities'),
        OverviewBarChart(rows: rows),
        const SizedBox(height: 18),
        StatRow(tiles: _summaryTiles(d)),
        const SizedBox(height: 18),
        ZoeInsightCard(title: title, body: body),
        const SizedBox(height: 18),
        _askZoe(),
      ],
    );
  }

  // ───────────── All time ─────────────

  Widget _allTimeBody(StatsBuckets d) {
    final now = DateTime.now();
    final years = d.activityKeys.map(int.tryParse).whereType<int>().toSet();
    final firstYear = _earliest?.year ?? now.year;
    final lastYear = [now.year, ...years].reduce((a, b) => a > b ? a : b);

    final rows = <OverviewRow>[];
    var bestYear = -1;
    var bestValue = 0;
    for (var y = firstYear; y <= lastYear; y++) {
      final value = d.activitiesFor('$y');
      if (value > bestValue) {
        bestValue = value;
        bestYear = y;
      }
      rows.add(OverviewRow('$y', value, highlight: y == now.year));
    }

    final total = d.totalActivities;
    final title = total == 0
        ? 'Your history starts today.'
        : 'Zoe has helped you ${formatCount(total)} times.';
    final body = total == 0
        ? 'Tasks, reminders, notes and Zoe chats will show up here.'
        : rows.length == 1
            ? '${formatCount(d.totalTasksDone)} tasks done and '
                '${formatCount(d.totalReminders)} reminders so far.'
            : '$bestYear was your busiest year — ${formatCount(bestValue)} activities.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Yearly overview', 'Activities'),
        OverviewBarChart(rows: rows),
        const SizedBox(height: 18),
        StatRow(tiles: _summaryTiles(d)),
        const SizedBox(height: 18),
        ZoeInsightCard(title: title, body: body),
        const SizedBox(height: 18),
        _askZoe(),
      ],
    );
  }

  List<StatTileData> _summaryTiles(StatsBuckets d) => [
        StatTileData(d.totalTasksDone, 'Tasks done', HomeColors.mint, HomeColors.mintLight),
        StatTileData(d.totalReminders, 'Reminders', HomeColors.coral, HomeColors.coralLight),
        StatTileData(d.totalChats, 'Zoe chats', HomeColors.sky, HomeColors.skyLight),
      ];
}