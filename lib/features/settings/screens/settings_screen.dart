import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';

/// TEMPORARY: "Alarm Check" screen para ma-debug ang reminders sa phone
/// (walang logs ang release APK). Papalitan ng totoong Settings mamaya.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  static const _lavender = Color(0xFF8B7FE0);
  static const _mint = Color(0xFF3FBE93);
  static const _coral = Color(0xFFF0768E);
  static const _ink = Color(0xFF2B2A3D);
  static const _cream = Color(0xFFFBF6EF);

  PermissionStatus? _notif;
  PermissionStatus? _exact;
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
    final notif = await Permission.notification.status;
    final exact = await Permission.scheduleExactAlarm.status;
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
      _notif = notif;
      _exact = exact;
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
      body: SafeArea(
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
              const Text('Pansamantala — para ma-test ang reminders.',
                  style: TextStyle(fontFamily: 'Poppins', color: Colors.black54)),
              const SizedBox(height: 20),

              _section('1. Permissions'),
              _permRow('Notifications', _notif, () async {
                await Permission.notification.request();
                await _refresh();
              }),
              _permRow('Alarms & reminders (exact alarm)', _exact, () async {
                await Permission.scheduleExactAlarm.request(); // bubuksan ang Settings
                await _refresh();
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Buksan ang App Settings ng Zoe'),
              ),
              const Text(
                'Doon: i-ON ang Full screen notifications, gawing Unrestricted ang Battery, '
                'at i-ON ang Autostart (Xiaomi / Oppo / Vivo / Realme / Infinix).',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
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

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
      );

  Widget _permRow(String label, PermissionStatus? status, VoidCallback onAllow) {
    final granted = status?.isGranted ?? false;
    return Card(
      child: ListTile(
        leading: Icon(
          granted ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: granted ? _mint : _coral,
        ),
        title: Text(label),
        subtitle: Text(status == null ? 'checking…' : status.name),
        trailing: granted ? null : TextButton(onPressed: onAllow, child: const Text('Allow')),
      ),
    );
  }
}