import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Colors + text styles ng Zoe Chat. Galing sa HomeColors para pare-pareho.
class ChatColors {
  ChatColors._();

  /// Lavender (taas) → cream (baba), gaya ng UI concept.
  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF4F1FC), Color(0xFFFFFBF4)],
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
  static const amberLight = Color(0xFFFDF1DD);
  static const inputFill = Color(0xFFEFECFB);
  static const cardHeader = Color(0xFFEDEAFB);
  static const cancelFill = Color(0xFFF1F0F5);
  static const shadow = Color(0x146E5BD6);
}

class ChatText {
  ChatText._();
  static const _f = 'Poppins';

  static const name = TextStyle(
      fontFamily: _f, fontSize: 20, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static const status = TextStyle(
      fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w600);
  static const bubble = TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w400,
      color: HomeColors.ink, height: 1.45);
  static const bubbleUser = TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w500,
      color: Colors.white, height: 1.45);
  static const footnote = TextStyle(
      fontFamily: _f, fontSize: 12.5, fontWeight: FontWeight.w400,
      color: HomeColors.inkSoft, height: 1.35);
  static const cardHeader = TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700, color: HomeColors.lavender);
  static const cardTitle = TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static const cardMeta = TextStyle(
      fontFamily: _f, fontSize: 14.5, fontWeight: FontWeight.w500, color: HomeColors.inkSoft);
  static const button = TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700);
  static const chip = TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w700, color: HomeColors.lavender);
  static const pill = TextStyle(
      fontFamily: _f, fontSize: 12.5, fontWeight: FontWeight.w600, color: HomeColors.inkSoft);
  static const input = TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w500, color: HomeColors.ink);
  static const inputHint = TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF8E8AA6));
  static const title = TextStyle(
      fontFamily: _f, fontSize: 22, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static const body = TextStyle(
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