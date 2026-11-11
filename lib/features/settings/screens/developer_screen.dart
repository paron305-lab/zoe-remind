import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
import 'package:zoe_remind/features/reminders/services/reminder_permissions.dart';

/// Developer (hidden): "Alarm Check" para ma-debug ang reminders sa phone
/// (walang logs ang release APK). Lumalabas sa Settings › About pagkatapos
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
  static const _ink = Color(0xFF2B2A3D);
  static const _cream = Color(0xFFFBF6EF);

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
        title: const Text('Developer',
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
              const Text(
                'Alarm Check',
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 26, fontWeight: FontWeight.w700, color: _ink),
              ),
              const Text('Para ma-test ang reminders sa phone na ito.',
                  style: TextStyle(fontFamily: 'Poppins', color: Colors.black54)),
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
            ],
          ),
        ),
      ),
    );
  }

  /// Itago ulit ang Developer row sa Settings.
  Future<void> _hide() async {
    await SettingsRepository().setDeveloperUnlocked(false);
    if (mounted) context.pop('hidden');
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
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