import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

class TimelineStats extends StatelessWidget {
  final int tasksLeft;
  final int reminders;
  final int streak;
  final VoidCallback? onSeeAll;

  const TimelineStats({
    super.key,
    required this.tasksLeft,
    required this.reminders,
    required this.streak,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              const Text("Today's timeline", style: HomeText.sectionTitle),
              const Spacer(),
              GestureDetector(
                onTap: onSeeAll,
                child: const Text('See all', style: HomeText.link),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  value: tasksLeft,
                  label: tasksLeft == 1 ? 'Task left' : 'Tasks left',
                  color: HomeColors.mint,
                  background: HomeColors.mintLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  value: reminders,
                  label: reminders == 1 ? 'Reminder' : 'Reminders',
                  color: HomeColors.coral,
                  background: HomeColors.coralLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  value: streak,
                  label: 'Day streak',
                  color: HomeColors.sky,
                  background: HomeColors.skyLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  final Color background;

  const _StatChip({
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: HomeText.statNumber.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: HomeText.statLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}