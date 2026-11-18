import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/companion/controllers/mood_controller.dart';
import 'package:zoe_remind/features/companion/controllers/mood_log.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/features/companion/models/mood_week.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
import 'package:zoe_remind/features/reminders/services/reminder_permissions.dart';
import 'package:zoe_remind/features/settings/screens/brain_test_screen.dart';

/// Developer (hidden): "Alarm Check" para ma-debug ang reminders sa phone
/// (walang logs ang release APK), at "Brain Test" para kay Qwen. Lumalabas sa Settings › About pagkatapos
/// i-tap ang app version nang 7 beses. Route: /settings/developer
class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> with WidgetsBindingObserver {
  static const _lavender = Color(0xFF8B7FE0);
  static const _mint = Color(0xFF3FBE93);
  static const _coral = Color(0xFFF0768E);
  static Color get _ink => HomeColors.ink;
  static Color get _cream => HomeColors.cream;

  SetupStatus? _setup;
  List<AlarmSettings> _alarms = const [];
  String _result = '';
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Pagbalik galing sa phone Settings → i-refresh ang status.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final setup = await ReminderPermissions.instance.check();
    var alarms = <AlarmSettings>[];
    var result = _result;
    try {
      alarms = await Alarm.getAlarms();
      alarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    } catch (e) {
      result = '❌ getAlarms error: $e';
    }
    if (!mounted) return;
    setState(() {
      _setup = setup;
      _alarms = alarms;
      _result = result;
    });
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = '';
    });
    try {
      await ReminderAlarmService.instance.scheduleTest();
      _result = '✅ Naka-schedule ang test! I-lock mo na ang phone at hintayin ang 10 seconds.';
    } catch (e) {
      _result = '❌ ERROR sa pag-schedule:\n$e';
    }
    _testing = false;
    await _refresh();
  }

  String _hm(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.month}/${t.day}  $h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final lastError = ReminderAlarmService.instance.lastError;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: Colors.transparent,
        title: Text('Developer',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: _ink)),
        actions: [
          TextButton(
            onPressed: _hide,
            child: const Text('Hide',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: _coral)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Alarm Check',
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 26, fontWeight: FontWeight.w700, color: _ink),
              ),
              Text('Para ma-test ang reminders sa phone na ito.',
                  style: TextStyle(fontFamily: 'Poppins', color: HomeColors.inkSoft)),
              const SizedBox(height: 20),

              _section('1. Reminder Setup (permissions)'),
              _setupCard(),
              const SizedBox(height: 24),

              _section('2. Test'),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _lavender),
                  onPressed: _testing ? null : _test,
                  icon: const Icon(Icons.alarm_rounded),
                  label: const Text('Tumunog after 10 seconds'),
                ),
              ),
              if (_result.isNotEmpty) ...[
                const SizedBox(height: 10),
                SelectableText(_result, style: const TextStyle(fontSize: 14)),
              ],
              const SizedBox(height: 24),

              _section('3. Naka-schedule na alarms (${_alarms.length})'),
              if (_alarms.isEmpty)
                const Text(
                  'Wala. Kung may ginawa kang reminder sa future at wala siya dito, '
                  'hindi siya na-schedule.',
                  style: TextStyle(color: _coral),
                ),
              for (final a in _alarms)
                Card(
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.alarm_on_rounded, color: _mint),
                    title: Text(ReminderAlarmService.readPayload(a).title),
                    subtitle: Text('id ${a.id} · tutunog ${_hm(a.dateTime)}'),
                  ),
                ),
              const SizedBox(height: 24),

              _section('4. Huling error'),
              SelectableText(lastError ?? 'Wala ✅',
                  style: TextStyle(color: lastError == null ? _mint : _coral)),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
              const SizedBox(height: 24),

              _section("5. Zoe's Brain (Qwen)"),
              Text('I-load si Qwen sa phone at sukatin ang bilis at RAM.',
                  style: TextStyle(fontFamily: 'Poppins', color: HomeColors.inkSoft)),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _lavender),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const BrainTestScreen()),
                  ),
                  icon: const Icon(Icons.psychology_rounded),
                  label: const Text('Buksan ang Brain Test'),
                ),
              ),
              const SizedBox(height: 24),

              _section('6. Mood ni Zoe'),
              Text(
                'Naka-save sa phone. Isara at buksan ulit ang app — dapat pareho pa rin.',
                style: TextStyle(fontFamily: 'Poppins', color: HomeColors.inkSoft),
              ),
              const SizedBox(height: 8),
              _moodCard(),
              const SizedBox(height: 24),

              _section('7. Mood log (7 araw)'),
              Text(
                'Pindutin ang "3 araw pagod", saka sabihin sa chat: "pagod na ako". '
                'Dapat sabihin ni Zoe: "Mukhang busy ang linggo mo…" (isang beses kada araw).',
                style: TextStyle(fontFamily: 'Poppins', color: HomeColors.inkSoft),
              ),
              const SizedBox(height: 8),
              _moodLogCard(),
            ],
          ),
        ),
      ),
    );
  }

  static String _moodEmoji(MoodState s) => switch (s) {
        MoodState.content => '🙂',
        MoodState.sleepy => '😴',
        MoodState.happy => '😊',
        MoodState.proud => '🥳',
        MoodState.focused => '🤔',
        MoodState.gentle => '🫶',
        MoodState.sorry => '🙏',
      };

  /// Mood ngayon + huling mga event + test buttons.
  Widget _moodCard() {
    final c = MoodController.instance;
    return ValueListenableBuilder<ZoeMood>(
      valueListenable: c.mood,
      builder: (context, m, _) {
        final celebrated = m.celebrated.isEmpty ? '—' : (m.celebrated.toList()..sort()).join(', ');
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_moodEmoji(m.state)}  ${m.state.name}  ·  intensity ${m.intensity}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _lavender),
                ),
                const SizedBox(height: 4),
                Text('reason: ${m.reason.isEmpty ? '—' : m.reason}', style: const TextStyle(fontSize: 13)),
                Text('since: ${_hm(m.since)}', style: const TextStyle(fontSize: 13)),
                Text('na-celebrate ngayon: $celebrated', style: const TextStyle(fontSize: 13)),
                if (!c.isStarted)
                  const Text('⚠️ Hindi pa nagsisimula ang MoodController',
                      style: TextStyle(fontSize: 13, color: _coral)),
                const SizedBox(height: 10),
                const Text('Huling events:', style: TextStyle(fontWeight: FontWeight.w700)),
                if (c.recent.isEmpty) const Text('wala pa', style: TextStyle(fontSize: 13)),
                for (final line in c.recent.take(6)) Text(line, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _moodButton('Natapos', const TaskCompleted()),
                    _moodButton('Na-miss', const ReminderMissed()),
                    _moodButton('Pagod ako', const UserFeelsDown()),
                    _moodButton('AI error', const ZoeFailed(ZoeFailure.inference)),
                    OutlinedButton(
                      onPressed: () => c.refresh(),
                      child: const Text('Silipin ang araw'),
                    ),
                    TextButton(
                      onPressed: () => c.reset(),
                      child: const Text('Reset mood', style: TextStyle(color: _coral)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Buod ng huling 7 araw + kailan huling nagsalita si Zoe tungkol sa linggo.
  Future<(MoodWeek, String)> _loadMoodLog() async {
    final log = MoodLog.instance;
    final week = await log.week();
    final noted = await log.notedOn();
    return (week, noted);
  }

  /// Laman ng mood log + test buttons (Level 2).
  Widget _moodLogCard() {
    final log = MoodLog.instance;
    return ValueListenableBuilder<int>(
      valueListenable: log.changes,
      builder: (context, _, __) => FutureBuilder<(MoodWeek, String)>(
        future: _loadMoodLog(),
        builder: (context, snap) {
          final (week, noted) = snap.data ?? (MoodWeek.empty, '');
          final counts = week.counts.entries.map((e) => '${e.key.name} ${e.value}').join(', ');
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'vibe: ${week.vibe?.name ?? '—'}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: _lavender),
                  ),
                  const SizedBox(height: 4),
                  Text('bilang: ${counts.isEmpty ? '—' : counts}',
                      style: const TextStyle(fontSize: 13)),
                  Text('araw na pagod/stressed/malungkot…: ${week.downDays} · masaya: ${week.happyDays}',
                      style: const TextStyle(fontSize: 13)),
                  Text('huling nasabi ni Zoe: ${noted.isEmpty ? '—' : noted}',
                      style: const TextStyle(fontSize: 13)),
                  if (!log.isStarted)
                    const Text('⚠️ Hindi pa nagsisimula ang MoodLog',
                        style: TextStyle(fontSize: 13, color: _coral)),
                  if (!log.enabled.value)
                    const Text('⚠️ OFF sa Settings › Privacy & memory',
                        style: TextStyle(fontSize: 13, color: _coral)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton(
                        onPressed: () => log.seedTestDays(),
                        child: const Text('3 araw pagod'),
                      ),
                      OutlinedButton(
                        onPressed: () => log.seedTestDays(UserTone.sad),
                        child: const Text('3 araw malungkot'),
                      ),
                      OutlinedButton(
                        onPressed: () => log.seedTestDays(UserTone.happy),
                        child: const Text('3 araw masaya'),
                      ),
                      OutlinedButton(
                        onPressed: () => log.resetNotedToday(),
                        child: const Text('Pwede ulit ngayon'),
                      ),
                      TextButton(
                        onPressed: () => log.clearAll(),
                        child: const Text('Burahin lahat', style: TextStyle(color: _coral)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _moodButton(String label, ZoeEvent event) => OutlinedButton(
        onPressed: () => MoodController.instance.add(event),
        child: Text(label),
      );

  /// Itago ulit ang Developer row sa Settings.
  Future<void> _hide() async {
    await SettingsRepository().setDeveloperUnlocked(false);
    if (mounted) context.pop('hidden');
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
      );

  Widget _setupCard() {
    final s = _setup;
    if (s == null) return const Card(child: ListTile(title: Text('checking…')));
    final color = s.allOk ? _mint : (s.criticalOk ? const Color(0xFFF0AA45) : _coral);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.readyCount}/${s.items.length} ready · ${s.manufacturer} · SDK ${s.sdkInt}',
                style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 6),
            for (final i in s.items)
              Text('${s.isOk(i) ? '✅' : '❌'}  ${i.name}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _lavender),
              onPressed: () async {
                await context.push('/reminders/setup');
                await _refresh();
              },
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Buksan ang Reminder Setup'),
            ),
          ],
        ),
      ),
    );
  }
}