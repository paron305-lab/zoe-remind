import 'dart:async';
import 'dart:math' as math;

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
import 'package:alarm/utils/alarm_set.dart';

class ReminderRingingScreen extends StatefulWidget {
  const ReminderRingingScreen({super.key, required this.alarm});
  final AlarmSettings alarm;

  @override
  State<ReminderRingingScreen> createState() => _ReminderRingingScreenState();
}

class _ReminderRingingScreenState extends State<ReminderRingingScreen>
    with SingleTickerProviderStateMixin {
  // Palette (Mobile UI Design Concept)
  static const _gradTop = Color(0xFF7B6FD6);
  static const _gradBottom = Color(0xFF4FADE0);
  static const _lavender = Color(0xFF8B7FE0);
  static const _coral = Color(0xFFF0768E);
  static const _mint = Color(0xFF3FBE93);
  static const _ink = Color(0xFF2B2A3D);
  static const _cream = Color(0xFFFBF6EF);
  static const _muted = Color(0xFF8E8AA3);
  static const _font = 'Poppins';

  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final Timer _clock;
  late final RingInfo _info;
  StreamSubscription<AlarmSet>? _ringSub;
  DateTime _now = DateTime.now();
  bool _busy = false;
  bool _showSnooze = false;

  @override
  void initState() {
    super.initState();
    _info = ReminderAlarmService.readPayload(widget.alarm);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Kung na-stop ang alarm sa ibang paraan, isara ang screen.
    _ringSub = Alarm.ringing.listen((set) {
      final stillRinging = set.alarms.any((a) => a.id == widget.alarm.id);
      if (!stillRinging && !_busy) {
        _busy = true;
        ReminderAlarmService.instance.finish();
        _leave();
      }
    });
  }

  @override
  void dispose() {
    _bob.dispose();
    _clock.cancel();
    _ringSub?.cancel();
    super.dispose();
  }

  // ───────────────────────── Actions ─────────────────────────

  Future<void> _run(Future<void> Function() action, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _leave();
  }

  void _snooze(int minutes) => _run(
        () => ReminderAlarmService.instance.snooze(widget.alarm, minutes),
        'Sige! I-reremind kita ulit in $minutes min.',
      );

  void _done() => _run(
        () => ReminderAlarmService.instance.markDone(widget.alarm),
        'Nice! Tapos na "${_info.title}" ✓',
      );

  void _dismiss() => _run(
        () => ReminderAlarmService.instance.dismiss(widget.alarm),
        'Okay, dinismiss ko muna. Pending pa rin siya.',
      );

  void _leave() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home'); // palitan kung iba ang home path mo
    }
  }

  // ───────────────────────── Helpers ─────────────────────────

  String _hm(DateTime t, {bool withAmPm = true}) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return withAmPm ? '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}' : '$h:$m';
  }

  String _dateLabel(DateTime d) =>
      '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

  String _dayLabel(DateTime t) {
    final diff = DateUtils.dateOnly(t).difference(DateUtils.dateOnly(_now)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${_months[t.month - 1].substring(0, 3)} ${t.day}';
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // bawal i-back; Snooze / Done / Dismiss lang
      child: Scaffold(
        backgroundColor: _gradBottom,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_gradTop, _gradBottom],
            ),
          ),
          child: Stack(
            children: [
              Positioned(top: -90, right: -130, child: _blob(340)),
              Positioned(bottom: 260, left: -110, child: _blob(220)),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 28),
                    Text(
                      _hm(_now, withAmPm: false),
                      style: const TextStyle(
                        fontFamily: _font,
                        fontSize: 84,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dateLabel(_now),
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _zoe(),
                                const SizedBox(height: 4),
                                _reminderCard(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _actionSheet(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.10),
        ),
      );

  Widget _zoe() => AnimatedBuilder(
        animation: _bob,
        builder: (_, child) {
          final t = Curves.easeInOut.transform(_bob.value);
          return Transform.translate(
            offset: Offset(0, -10 * t),
            child: Transform.rotate(angle: math.sin(t * math.pi) * 0.03, child: child),
          );
        },
        child: Image.asset('assets/images/logo/02_happy.png', height: 220),
      );

  Widget _reminderCard() => Container(
        width: 320,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE9E5FA), width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _coral.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'REMINDER',
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _coral,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _info.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_dayLabel(_info.originalTime)} · ${_hm(_info.originalTime)}',
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ],
        ),
      );

  Widget _actionSheet(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
            24, 14, 24, 24 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE4DDD0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 18),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _showSnooze
                  ? _snoozeOptions()
                  : const SizedBox(width: double.infinity),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _circleAction(
                  icon: Icons.snooze_rounded,
                  label: 'Snooze',
                  size: 68,
                  bg: _lavender.withValues(alpha: 0.15),
                  fg: _lavender,
                  onTap: () => setState(() => _showSnooze = !_showSnooze),
                ),
                _circleAction(
                  icon: Icons.check_rounded,
                  label: 'Mark done',
                  size: 84,
                  bg: _mint,
                  fg: Colors.white,
                  onTap: _done,
                ),
                _circleAction(
                  icon: Icons.close_rounded,
                  label: 'Dismiss',
                  size: 68,
                  bg: const Color(0xFFF1EEFA),
                  fg: _muted,
                  border: const Color(0xFFE2DDF5),
                  onTap: _dismiss,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _snoozeOptions() => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            const Text(
              'SNOOZE FOR',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: _muted,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final m in ReminderAlarmService.snoozeOptions)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _snoozeChip(m),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );

  /// Ang default snooze (Settings › Reminders) ay naka-fill na lavender.
  Widget _snoozeChip(int minutes) {
    final isDefault = minutes == ReminderAlarmService.instance.defaultSnooze.value;
    return Material(
      color: isDefault ? _lavender : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _lavender.withValues(alpha: 0.5), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _busy ? null : () => _snooze(minutes),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              '$minutes min',
              style: TextStyle(
                fontFamily: _font,
                fontSize: 16,
                fontWeight: isDefault ? FontWeight.w700 : FontWeight.w600,
                color: isDefault ? Colors.white : _lavender,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleAction({
    required IconData icon,
    required String label,
    required double size,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
    Color? border,
  }) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: bg,
            shape: CircleBorder(
              side: border == null
                  ? BorderSide.none
                  : BorderSide(color: border, width: 3),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _busy ? null : onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: fg, size: size * 0.45),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
        ],
      );
}