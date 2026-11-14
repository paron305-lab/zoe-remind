import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

class TaskColors {
  TaskColors._();

  static const amber = Color(0xFFF0AA45);
  static Color get doneTitle => ZoeTheme.pick(const Color(0xFFB5B3C4), const Color(0xFF6E6B85));
  static Color get searchFill => ZoeTheme.pick(const Color(0xFFF6F4FD), const Color(0xFF2A2738));

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

  static TextStyle get screenTitle => TextStyle(
      fontFamily: _f, fontSize: 32, fontWeight: FontWeight.w700, color: HomeColors.ink,
      height: 1.15);
  static TextStyle get subtitle => TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w500, color: HomeColors.inkSoft);
  static TextStyle get chip => TextStyle(fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w700);
  static TextStyle get groupLabel => TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700,
      color: HomeColors.inkSoft, letterSpacing: 0.6);
  static TextStyle get cardTitle => TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static TextStyle get cardMeta => TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w500, color: HomeColors.inkSoft);
  static TextStyle get statusPill => TextStyle(fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w700);
  static TextStyle get emptyTitle => TextStyle(
      fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static TextStyle get emptyBody => TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w500,
      color: HomeColors.inkSoft, height: 1.45);
}