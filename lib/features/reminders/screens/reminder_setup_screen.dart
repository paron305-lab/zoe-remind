import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
import 'package:zoe_remind/features/reminders/services/reminder_permissions.dart';

/// "Reminder Setup" — checklist ng permissions para tumunog si Zoe
/// sa kahit anong brand. Binubuksan mula sa Settings o pagkatapos
/// mag-save ng reminder kung may kulang.
class ReminderSetupScreen extends StatefulWidget {
  const ReminderSetupScreen({super.key});

  @override
  State<ReminderSetupScreen> createState() => _ReminderSetupScreenState();
}

class _ReminderSetupScreenState extends State<ReminderSetupScreen>
    with WidgetsBindingObserver {
  static const _lavender = Color(0xFF8B7FE0);
  static const _mint = Color(0xFF3FBE93);
  static const _coral = Color(0xFFF0768E);
  static const _amber = Color(0xFFF0AA45);
  static Color get _ink => HomeColors.ink;
  static Color get _cream => HomeColors.cream;
  static Color get _muted => HomeColors.navInactive;
  static const _font = 'Poppins';

  final _perms = ReminderPermissions.instance;
  SetupStatus? _status;
  bool _openedAutostart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Kung na-ON ang exact alarm ngayon, i-schedule ulit lahat ng reminders.
    ReminderAlarmService.instance.syncAll();
    super.dispose();
  }

  // Pagbalik galing sa phone Settings → i-check ulit.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await _perms.check();
    if (mounted) setState(() => _status = s);
  }

  Future<void> _fix(SetupItem item) async {
    if (item == SetupItem.autostart) setState(() => _openedAutostart = true);
    await _perms.fix(item);
    await _refresh();
  }

  // ───────────────────────── Text per item ─────────────────────────

  String _title(SetupItem i) => switch (i) {
        SetupItem.notifications => 'Notifications',
        SetupItem.exactAlarm => 'Alarms & reminders',
        SetupItem.fullScreen => 'Full screen notifications',
        SetupItem.battery => 'Battery: Unrestricted',
        SetupItem.overlay => 'Display over other apps',
        SetupItem.autostart => 'Autostart at background',
      };

  String _why(SetupItem i) => switch (i) {
        SetupItem.notifications => 'Para makapagpakita si Zoe ng reminder.',
        SetupItem.exactAlarm => 'Para tumunog sa eksaktong oras, hindi late.',
        SetupItem.fullScreen =>
          'Para lumabas ang screen ni Zoe kahit naka-lock ang phone.',
        SetupItem.battery =>
          'Para hindi patayin ng battery saver ang alarm. Piliin ang "Allow".',
        SetupItem.overlay =>
          'Para lumabas ang buong screen ni Zoe kahit gamit mo ang phone '
          '(nasa ibang app o home screen). Hanapin ang Zoe at i-ON.',
        SetupItem.autostart => _autostartTip(_status?.manufacturer ?? ''),
      };

  IconData _icon(SetupItem i) => switch (i) {
        SetupItem.notifications => Icons.notifications_active_rounded,
        SetupItem.exactAlarm => Icons.alarm_rounded,
        SetupItem.fullScreen => Icons.fullscreen_rounded,
        SetupItem.battery => Icons.battery_charging_full_rounded,
        SetupItem.overlay => Icons.picture_in_picture_alt_rounded,
        SetupItem.autostart => Icons.rocket_launch_rounded,
      };

  bool _critical(SetupItem i) =>
      i == SetupItem.notifications || i == SetupItem.exactAlarm;

  String _autostartTip(String m) {
    switch (m) {
      case 'xiaomi':
      case 'redmi':
      case 'poco':
        return 'I-ON ang Autostart ng Zoe. Sa "Other permissions", i-ON din ang '
            '"Show on Lock screen" at "Display pop-up windows while running in background".';
      case 'oppo':
      case 'realme':
      case 'oneplus':
        return 'I-ON ang "Allow auto launch" / "Auto startup" ng Zoe. '
            'Sa Battery, piliin ang "Allow background activity".';
      case 'vivo':
      case 'iqoo':
        return 'I-ON ang "Autostart" / "Background startup" ng Zoe. '
            'Sa Battery, piliin ang "Allow high background power consumption".';
      case 'huawei':
      case 'honor':
        return 'Sa App launch, i-OFF ang "Manage automatically", tapos i-ON lahat: '
            'Auto-launch, Secondary launch, Run in background.';
      case 'samsung':
        return 'Sa Battery → Background usage limits, siguraduhing WALA si Zoe sa '
            '"Sleeping apps" at "Deep sleeping apps".';
      case 'infinix':
      case 'tecno':
      case 'itel':
        return 'Sa Phone Master → Auto-start management, i-ON ang Zoe. '
            'I-lock din ang Zoe sa Recents para hindi ma-clear.';
      default:
        return 'I-ON ang Autostart / background activity ng Zoe sa settings ng phone.';
    }
  }

  bool get _isXiaomi => const {'xiaomi', 'redmi', 'poco'}.contains(_status?.manufacturer);

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text('Reminder Setup',
            style: TextStyle(fontFamily: _font, fontWeight: FontWeight.w700)),
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  _summary(s),
                  const SizedBox(height: 16),
                  for (final item in s.items) _stepCard(s, item),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _perms.openAppDetails,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Buksan ang App info ng Zoe'),
                  ),
                  Text(
                    'Phone: ${s.manufacturer} · Android SDK ${s.sdkInt}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: s.criticalOk ? _mint : _muted),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(s.allOk ? 'Tapos na! 🎉' : 'Mamaya na lang'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summary(SetupStatus s) {
    final total = s.items.length;
    final color = s.allOk ? _mint : (s.criticalOk ? _amber : _coral);
    final text = s.allOk
        ? 'Ready na si Zoe! Tutunog ang reminders mo kahit naka-lock o naka-close ang app.'
        : s.criticalOk
            ? 'Tutunog na si Zoe, pero ayusin pa ang natitira para siguradong '
                'lalabas ang screen niya at hindi papatayin ng phone.'
            : 'Hindi pa tutunog ang reminders. Ayusin muna ang may pulang ❗.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: total == 0 ? 1 : s.readyCount / total,
                  strokeWidth: 6,
                  color: color,
                  backgroundColor: HomeColors.card,
                ),
                Text('${s.readyCount}/$total',
                    style: TextStyle(
                        fontFamily: _font, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(text,
                style: TextStyle(fontFamily: _font, fontSize: 14, color: _ink)),
          ),
        ],
      ),
    );
  }

  Widget _stepCard(SetupStatus s, SetupItem item) {
    final ok = s.isOk(item);
    final critical = _critical(item);
    final badColor = critical ? _coral : _amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ok ? _mint.withValues(alpha: 0.4) : badColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon(item), color: ok ? _mint : badColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_title(item),
                    style: TextStyle(
                        fontFamily: _font,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _ink)),
              ),
              Icon(
                ok ? Icons.check_circle_rounded : Icons.error_rounded,
                color: ok ? _mint : badColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_why(item), style: TextStyle(fontSize: 13, color: _muted)),
          if (!ok) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _lavender),
                  onPressed: () => _fix(item),
                  child: Text(item == SetupItem.autostart ? 'Buksan' : 'Ayusin'),
                ),
                if (item == SetupItem.autostart && _isXiaomi)
                  OutlinedButton(
                    onPressed: _perms.openOemPermissions,
                    child: const Text('Other permissions'),
                  ),
                // Walang API para i-check ang autostart → user ang magkukumpirma
                if (item == SetupItem.autostart)
                  OutlinedButton(
                    onPressed: _openedAutostart
                        ? () async {
                            await _perms.confirmAutostart(true);
                            await _refresh();
                          }
                        : null,
                    child: const Text('Na-ON ko na ✓'),
                  ),
              ],
            ),
          ],
          if (ok && item == SetupItem.autostart)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await _perms.confirmAutostart(false);
                  await _refresh();
                },
                child: const Text('Ulitin'),
              ),
            ),
        ],
      ),
    );
  }
}