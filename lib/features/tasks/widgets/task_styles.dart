import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

class TaskColors {
  TaskColors._();

  static const amber = Color(0xFFF0AA45);
  static const doneTitle = Color(0xFFB5B3C4);
  static const searchFill = Color(0xFFF6F4FD);

  /// 12 kulay na pwedeng piliin para sa category.
  /// Ang unang 7 = kulay ng mga dating category (Study … Other).
  static const categoryPresets = <int>[
    0xFF3FBE93, // mint
    0xFFF0768E, // coral
    0xFF4FADE0, // sky
    0xFF6E5BD6, // lavender
    0xFFF0AA45, // amber
    0xFFC98BDB, // orchid
    0xFF8A8999, // gray
    0xFF2BB5B0, // teal
    0xFFE8735A, // tomato
    0xFF9BC53D, // lime
    0xFF4A6FE0, // blue
    0xFFB08A6E, // mocha
  ];
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
  static const statusPill = TextStyle(fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w700);
  static const emptyTitle = TextStyle(
      fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static const emptyBody = TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w500,
      color: HomeColors.inkSoft, height: 1.45);
}