import 'package:flutter/material.dart';
import 'package:zoe_remind/database/models/task.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

class TaskColors {
  TaskColors._();

  static const amber = Color(0xFFF0AA45);
  static const doneTitle = Color(0xFFB5B3C4);
  static const searchFill = Color(0xFFF6F4FD);

  /// Color always means the category (same dot on every screen).
  static Color category(TaskCategory c) => switch (c) {
        TaskCategory.study => HomeColors.mint,
        TaskCategory.thesis => HomeColors.coral,
        TaskCategory.work => HomeColors.sky,
        TaskCategory.errand => HomeColors.lavender,
        TaskCategory.habit => amber,
        TaskCategory.personal => const Color(0xFFC98BDB),
        TaskCategory.other => HomeColors.navInactive,
      };
}

class TaskText {
  TaskText._();
  static const _f = 'Poppins';

  static const screenTitle = TextStyle(
      fontFamily: _f, fontSize: 32, fontWeight: FontWeight.w700, color: HomeColors.ink,
      height: 1.15);
  static const subtitle = TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w500, color: HomeColors.inkSoft);
  static const chip = TextStyle(fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w700);
  static const groupLabel = TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700,
      color: HomeColors.inkSoft, letterSpacing: 0.6);
  static const cardTitle = TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static const cardMeta = TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w500, color: HomeColors.inkSoft);
  static const emptyTitle = TextStyle(
      fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static const emptyBody = TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w500,
      color: HomeColors.inkSoft, height: 1.45);
}