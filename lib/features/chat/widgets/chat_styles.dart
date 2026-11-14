import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Colors + text styles ng Zoe Chat. Galing sa HomeColors para pare-pareho.
class ChatColors {
  ChatColors._();

  /// Lavender (taas) → cream (baba), gaya ng UI concept.
  static LinearGradient get background => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: ZoeTheme.isDark
            ? const [Color(0xFF1E1B2E), Color(0xFF16151F)]
            : const [Color(0xFFF4F1FC), Color(0xFFFFFBF4)],
      );

  /// User bubble + send button.
  static const userBubble = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B7FE0), Color(0xFF6C9BE8), Color(0xFF52C2B4)],
    stops: [0.0, 0.6, 1.0],
  );

  static const online = HomeColors.mint;
  static const amber = Color(0xFFF0AA45);
  static Color get amberLight => HomeColors.amberLight;
  static Color get inputFill => ZoeTheme.pick(const Color(0xFFEFECFB), const Color(0xFF2A2738));
  static Color get cardHeader => HomeColors.lavenderLight;
  static Color get cancelFill => ZoeTheme.pick(const Color(0xFFF1F0F5), const Color(0xFF2E2B3E));
  static Color get shadow => ZoeTheme.pick(const Color(0x146E5BD6), const Color(0x33000000));

  /// Zoe bubble, header, input bar, cards (puti sa light mode).
  static Color get surface => HomeColors.card;

  /// Border ng chips (suggestions, clarify).
  static Color get chipBorder => ZoeTheme.pick(const Color(0xFFD9D3F5), const Color(0xFF45415C));

  /// Typing dots (mahina → lavender).
  static Color get dotLow => ZoeTheme.pick(const Color(0xFFC9C2F2), const Color(0xFF4A4568));

  /// Fill ng detail rows sa confirm card.
  static Color get detailFill => ZoeTheme.pick(const Color(0xFFF8F7FC), const Color(0xFF2A2738));
}

class ChatText {
  ChatText._();
  static const _f = 'Poppins';

  static TextStyle get name => TextStyle(
      fontFamily: _f, fontSize: 20, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static TextStyle get status => TextStyle(
      fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w600);
  static TextStyle get bubble => TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w400,
      color: HomeColors.ink, height: 1.45);
  static TextStyle get bubbleUser => TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w500,
      color: Colors.white, height: 1.45);
  static TextStyle get footnote => TextStyle(
      fontFamily: _f, fontSize: 12.5, fontWeight: FontWeight.w400,
      color: HomeColors.inkSoft, height: 1.35);
  static TextStyle get cardHeader => TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700, color: HomeColors.lavender);
  static TextStyle get cardTitle => TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static TextStyle get cardMeta => TextStyle(
      fontFamily: _f, fontSize: 14.5, fontWeight: FontWeight.w500, color: HomeColors.inkSoft);
  static TextStyle get button => TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700);
  static TextStyle get chip => TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w700, color: HomeColors.lavender);
  static TextStyle get pill => TextStyle(
      fontFamily: _f, fontSize: 12.5, fontWeight: FontWeight.w600, color: HomeColors.inkSoft);
  static TextStyle get input => TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w500, color: HomeColors.ink);
  static TextStyle get inputHint => TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w400, color: ZoeTheme.pick(const Color(0xFF8E8AA6), const Color(0xFF8E8BA3)));
  static TextStyle get title => TextStyle(
      fontFamily: _f, fontSize: 22, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static TextStyle get body => TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w400,
      color: HomeColors.inkSoft, height: 1.5);
}

/// Bilog na Zoe avatar (logo) sa tabi ng Zoe bubbles.
class ChatAvatar extends StatelessWidget {
  final double size;
  final String asset;
  const ChatAvatar({super.key, this.size = 40, this.asset = 'assets/images/logo/02_happy.png'});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: HomeColors.fabGradient,
          ),
          child: Icon(Icons.sentiment_satisfied_alt_rounded,
              color: Colors.white, size: size * 0.6),
        ),
      ),
    );
  }
}