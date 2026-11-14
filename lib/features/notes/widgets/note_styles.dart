import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Notes design tokens (Screen 08 ng UI Design Concept).
/// Lavender = Typed, mint = From Zoe, coral→amber = pinned accent.
class NoteColors {
  NoteColors._();

  static const amber = Color(0xFFF0AA45);
  static Color get timeText => ZoeTheme.pick(const Color(0xFF9B99AB), const Color(0xFF8E8BA3));
  static Color get searchFill => ZoeTheme.pick(const Color(0xFFF3F5FD), const Color(0xFF2A2738));
  static Color get cardShadow => ZoeTheme.pick(const Color(0x0F2B2A3D), const Color(0x33000000));

  /// Placeholder / hint text.
  static Color get hint => ZoeTheme.pick(const Color(0xFF8A8999), const Color(0xFF8E8BA3));
  static Color get hintLight => ZoeTheme.pick(const Color(0xFFC9C7D6), const Color(0xFF5E5B73));

  /// Header: lavender → sky (gaya ng mockup).
  static const headerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF8F80E0), Color(0xFF6E98E2), Color(0xFF4FAEE0)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Left accent bar ng pinned note.
  static const pinnedAccent = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [HomeColors.coral, amber],
  );
}

class NoteText {
  NoteText._();
  static const _f = 'Poppins';

  static TextStyle get screenTitle => TextStyle(
      fontFamily: _f, fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white,
      height: 1.15);
  static TextStyle get search => TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w500, color: HomeColors.ink);
  static TextStyle get searchHint => TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w400, color: NoteColors.hint);
  static TextStyle get chip => TextStyle(fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w700);
  static TextStyle get groupLabel => TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700,
      color: NoteColors.hint, letterSpacing: 0.8);
  static TextStyle get cardTitle => TextStyle(
      fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.ink,
      height: 1.3);
  static TextStyle get cardPreview => TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w400, color: HomeColors.inkSoft,
      height: 1.45);
  static TextStyle get pill => TextStyle(
      fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6);
  static TextStyle get time => TextStyle(
      fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w500, color: NoteColors.timeText);

  // Editor
  static TextStyle get editorTitle => TextStyle(
      fontFamily: _f, fontSize: 24, fontWeight: FontWeight.w700, color: HomeColors.ink,
      height: 1.3);
  static TextStyle get editorTitleHint => TextStyle(
      fontFamily: _f, fontSize: 24, fontWeight: FontWeight.w700, color: NoteColors.hintLight,
      height: 1.3);
  static TextStyle get editorBody => TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w400, color: HomeColors.ink,
      height: 1.6);
  static TextStyle get editorBodyHint => TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w400, color: NoteColors.hint,
      height: 1.6);
  static TextStyle get meta => TextStyle(
      fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w500, color: NoteColors.timeText);

  static TextStyle get emptyTitle => TextStyle(
      fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static TextStyle get emptyBody => TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w500,
      color: HomeColors.inkSoft, height: 1.45);
}

/// FROM ZOE (mint) / TYPED (lavender) pill.
class NoteSourcePill extends StatelessWidget {
  final bool fromZoe;
  const NoteSourcePill({super.key, required this.fromZoe});

  @override
  Widget build(BuildContext context) {
    final bg = fromZoe ? HomeColors.mintLight : HomeColors.lavenderLight;
    final fg = fromZoe ? HomeColors.mint : HomeColors.lavender;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Text(fromZoe ? 'FROM ZOE' : 'TYPED', style: NoteText.pill.copyWith(color: fg)),
    );
  }
}