import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Settings design tokens (Screen 09 · Settings).
/// May light at dark palette — sinusunod ang Appearance › Dark mode.
class SettingsPalette {
  const SettingsPalette(this.dark);

  final bool dark;

  Color get bg => dark ? const Color(0xFF16151F) : HomeColors.cream;
  Color get card => dark ? const Color(0xFF221F30) : Colors.white;
  Color get ink => dark ? const Color(0xFFF2F0FA) : HomeColors.ink;
  Color get inkSoft => dark ? const Color(0xFFB3B0C7) : HomeColors.inkSoft;
  Color get sectionLabel => dark ? const Color(0xFF9D99B5) : const Color(0xFF6B6980);
  Color get divider => dark ? const Color(0xFF2E2B3E) : HomeColors.divider;
  Color get accent => dark ? const Color(0xFFA596F2) : HomeColors.lavender;
  Color get iconBg => dark ? const Color(0xFF2E2A48) : const Color(0xFFF1EEFC);
  Color get pillBg => dark ? const Color(0xFF2E2A48) : const Color(0xFFEFECFC);
  Color get pillText => dark ? const Color(0xFFC9C0FA) : const Color(0xFF6E5BD6);
  Color get switchOff => dark ? const Color(0xFF3A3750) : const Color(0xFFDCD8EE);
  Color get mint => HomeColors.mint;
  Color get coral => HomeColors.coral;
  Color get amber => const Color(0xFFF0AA45);

  /// Profile hero card: lavender → sky → mint.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8F80E0), Color(0xFF6C9BE8), Color(0xFF52C6B0)],
    stops: [0.0, 0.55, 1.0],
  );
}

class SettingsText {
  SettingsText._();
  static const _f = 'Poppins';

  static TextStyle title(SettingsPalette p) => TextStyle(
      fontFamily: _f, fontSize: 34, fontWeight: FontWeight.w700, color: p.ink, height: 1.2);
  static TextStyle section(SettingsPalette p) => TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700,
      color: p.sectionLabel, letterSpacing: 0.4);
  static TextStyle tileTitle(SettingsPalette p) => TextStyle(
      fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w700, color: p.ink, height: 1.25);
  static TextStyle tileSub(SettingsPalette p) => TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w400, color: p.inkSoft, height: 1.35);
  static TextStyle body(SettingsPalette p) => TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w500, color: p.inkSoft, height: 1.45);

  static const heroName = TextStyle(
      fontFamily: _f, fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white,
      height: 1.2);
  static const heroSub = TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xEBFFFFFF));
  static const pill = TextStyle(fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w700);
  static const button = TextStyle(fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700);
}