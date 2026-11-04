import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

class DateTimeLabel extends StatelessWidget {
  final DateTime at;
  const DateTimeLabel({super.key, required this.at});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _dateText() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = day.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    final base = '${_months[at.month - 1]} ${at.day}';
    return at.year == now.year ? base : '$base, ${at.year}';
  }

  String _timeText() =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96, // sapat para sa "Tomorrow" nang hindi dumidikit sa title
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _dateText(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HomeText.time.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: HomeColors.lavender,
            ),
          ),
          const SizedBox(height: 2),
          Text(_timeText(), style: HomeText.time),
        ],
      ),
    );
  }
}