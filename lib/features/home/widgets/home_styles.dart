import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';

class HomeColors {
  HomeColors._();

  // ───── Nagbabago sa dark mode ─────
  static Color get cream => ZoeTheme.pick(const Color(0xFFFFFBF4), const Color(0xFF16151F));

  /// Cards, sheets, dialogs, bottom nav (puti sa light mode).
  static Color get card => ZoeTheme.pick(Colors.white, const Color(0xFF221F30));
  static Color get ink => ZoeTheme.pick(const Color(0xFF2B2A3D), const Color(0xFFF2F0FA));
  static Color get inkSoft => ZoeTheme.pick(const Color(0xFF5E5D70), const Color(0xFFB3B0C7));
  static Color get divider => ZoeTheme.pick(const Color(0xFFEDEBF3), const Color(0xFF2E2B3E));
  static Color get checkboxBorder =>
      ZoeTheme.pick(const Color(0xFFE3E0F0), const Color(0xFF45415C));
  static Color get navInactive => ZoeTheme.pick(const Color(0xFF8A8999), const Color(0xFF8E8BA3));

  /// Input / search na naka-fill (hal. title field, search bar).
  static Color get fieldFill => ZoeTheme.pick(const Color(0xFFF6F4FD), const Color(0xFF2A2738));

  static Color get lavender => ZoeTheme.pick(const Color(0xFF6E5BD6), const Color(0xFFA596F2));
  static Color get lavenderLight =>
      ZoeTheme.pick(const Color(0xFFEDEAFB), const Color(0xFF2E2A48));
  static Color get mintLight => ZoeTheme.pick(const Color(0xFFE4F7EF), const Color(0xFF173A30));
  static Color get coralLight => ZoeTheme.pick(const Color(0xFFFCE6EC), const Color(0xFF42222C));
  static Color get skyLight => ZoeTheme.pick(const Color(0xFFE2F2FB), const Color(0xFF16323F));
  static Color get amberLight => ZoeTheme.pick(const Color(0xFFFDF1DE), const Color(0xFF3D2F18));

  // ───── Pareho sa light at dark ─────
  static const mint = Color(0xFF3FBE93);
  static const coral = Color(0xFFF0768E);
  static const sky = Color(0xFF4FADE0);
  static const amber = Color(0xFFF0AA45);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9D8AE6), Color(0xFF6C9BE8), Color(0xFF52C2B4)],
    stops: [0.0, 0.55, 1.0],
  );

  static const fabGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B7FE0), Color(0xFF52C2B4)],
  );
}

class HomeText {
  HomeText._();
  static const _f = 'Poppins';

  static TextStyle get greetingSmall => TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xE6FFFFFF));
  static TextStyle get greetingName => TextStyle(
      fontFamily: _f, fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2);
  static TextStyle get bannerTitle => TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white);
  static TextStyle get bannerSub => TextStyle(
      fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xF2FFFFFF));
  static TextStyle get time => TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.inkSoft);
  static TextStyle get itemTitle => TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static TextStyle get sectionTitle => TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static TextStyle get link => TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w700, color: HomeColors.lavender);
  static TextStyle get statNumber => TextStyle(
      fontFamily: _f, fontSize: 24, fontWeight: FontWeight.w700);
  static TextStyle get statLabel => TextStyle(
      fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.inkSoft);
  static TextStyle get tag => TextStyle(
      fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6);
  static TextStyle get navLabel => TextStyle(
      fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w600);
}