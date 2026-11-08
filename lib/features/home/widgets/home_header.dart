import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/home/widgets/zoe_avatar.dart';

class HomeHeader extends StatelessWidget {
  final String userName;
  final int total;
  final int done;
  final VoidCallback? onBellTap;

  /// Naka-ON ba ang reminders (green bell) o OFF (gray bell).
  final bool remindersOn;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.total,
    required this.done,
    this.onBellTap,
    this.remindersOn = true,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning ☀️';
    if (h < 18) return 'Good afternoon 🌤️';
    return 'Good evening 🌙';
  }

  String _title() {
    if (total == 0) return 'Free day today!';
    return 'You have $total thing${total == 1 ? '' : 's'} today!';
  }

  String _subtitle() {
    if (total == 0) return 'Tap + to plan something.';
    if (done == 0) return "Let's start the first one 💪";
    if (done == total) return 'All done — great job! 🎉';
    return '$done done already — keep going 💪';
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      // malaki ang bottom padding para may space na papatungan ng board card
      padding: EdgeInsets.fromLTRB(22, topInset + 20, 22, 64),
      decoration: const BoxDecoration(
        gradient: HomeColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(), style: HomeText.greetingSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Hi, $userName',
                      style: HomeText.greetingName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _BellButton(on: remindersOn, onTap: onBellTap),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const ZoeAvatar(size: 54),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title(), style: HomeText.bannerTitle),
                      const SizedBox(height: 2),
                      Text(_subtitle(), style: HomeText.bannerSub),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reminders ON/OFF switch.
/// ON  = green na may tunog na bell.
/// OFF = gray na may guhit na bell.
class _BellButton extends StatelessWidget {
  final bool on;
  final VoidCallback? onTap;
  const _BellButton({required this.on, this.onTap});

  static const _offGray = Color(0xFF9E9CAE);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: on ? 'Reminders ON' : 'Reminders OFF',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: on ? HomeColors.mint : _offGray,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(
              color: (on ? HomeColors.mint : _offGray).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                on ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                key: ValueKey(on),
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}