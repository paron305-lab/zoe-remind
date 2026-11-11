import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Notes design tokens (Screen 08 ng UI Design Concept).
/// Lavender = Typed, mint = From Zoe, coral→amber = pinned accent.
class NoteColors {
  NoteColors._();

  static const amber = Color(0xFFF0AA45);
  static const timeText = Color(0xFF9B99AB);
  static const searchFill = Color(0xFFF3F5FD);
  static const cardShadow = Color(0x0F2B2A3D);

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

  static const screenTitle = TextStyle(
      fontFamily: _f, fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white,
      height: 1.15);
  static const search = TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w500, color: HomeColors.ink);
  static const searchHint = TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w400, color: Color(0xFF8A8999));
  static const chip = TextStyle(fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w700);
  static const groupLabel = TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700,
      color: Color(0xFF8A8999), letterSpacing: 0.8);
  static const cardTitle = TextStyle(
      fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.ink,
      height: 1.3);
  static const cardPreview = TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w400, color: HomeColors.inkSoft,
      height: 1.45);
  static const pill = TextStyle(
      fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6);
  static const time = TextStyle(
      fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w500, color: NoteColors.timeText);

  // Editor
  static const editorTitle = TextStyle(
      fontFamily: _f, fontSize: 24, fontWeight: FontWeight.w700, color: HomeColors.ink,
      height: 1.3);
  static const editorTitleHint = TextStyle(
      fontFamily: _f, fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFFC9C7D6),
      height: 1.3);
  static const editorBody = TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w400, color: HomeColors.ink,
      height: 1.6);
  static const editorBodyHint = TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w400, color: Color(0xFFAAA8B8),
      height: 1.6);
  static const meta = TextStyle(
      fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w500, color: NoteColors.timeText);

  static const emptyTitle = TextStyle(
      fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static const emptyBody = TextStyle(
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