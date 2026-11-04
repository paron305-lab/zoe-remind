import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

enum HomeItemType { task, habit, reminder }

extension HomeItemTypeStyle on HomeItemType {
  String get label => name.toUpperCase();

  Color get color => switch (this) {
        HomeItemType.task => HomeColors.lavender,
        HomeItemType.habit => HomeColors.mint,
        HomeItemType.reminder => HomeColors.coral,
      };

  Color get background => switch (this) {
        HomeItemType.task => HomeColors.lavenderLight,
        HomeItemType.habit => HomeColors.mintLight,
        HomeItemType.reminder => HomeColors.coralLight,
      };
}

class HomeItem {
  final String id;
  final String title;
  final TimeOfDay time;
  final HomeItemType type;
  final bool done;

  /// Shown above the time for items that aren't today ("Tomorrow", "Nov 8").
  final String? dateLabel;

  const HomeItem({
    required this.id,
    required this.title,
    required this.time,
    required this.type,
    this.done = false,
    this.dateLabel,
  });

  HomeItem copyWith({bool? done}) => HomeItem(
        id: id,
        title: title,
        time: time,
        type: type,
        done: done ?? this.done,
        dateLabel: dateLabel,
      );

  String get timeLabel =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}