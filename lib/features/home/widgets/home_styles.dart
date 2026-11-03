import 'package:flutter/material.dart';

class HomeColors {
  HomeColors._();

  static const cream = Color(0xFFFFFBF4);
  static const ink = Color(0xFF2B2A3D);
  static const inkSoft = Color(0xFF5E5D70);
  static const divider = Color(0xFFEDEBF3);
  static const checkboxBorder = Color(0xFFE3E0F0);
  static const navInactive = Color(0xFF8A8999);

  static const lavender = Color(0xFF6E5BD6);
  static const lavenderLight = Color(0xFFEDEAFB);
  static const mint = Color(0xFF3FBE93);
  static const mintLight = Color(0xFFE4F7EF);
  static const coral = Color(0xFFF0768E);
  static const coralLight = Color(0xFFFCE6EC);
  static const sky = Color(0xFF4FADE0);
  static const skyLight = Color(0xFFE2F2FB);

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

  static const greetingSmall = TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xE6FFFFFF));
  static const greetingName = TextStyle(
      fontFamily: _f, fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2);
  static const bannerTitle = TextStyle(
      fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white);
  static const bannerSub = TextStyle(
      fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xF2FFFFFF));
  static const time = TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.inkSoft);
  static const itemTitle = TextStyle(
      fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static const sectionTitle = TextStyle(
      fontFamily: _f, fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.ink);
  static const link = TextStyle(
      fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w700, color: HomeColors.lavender);
  static const statNumber = TextStyle(
      fontFamily: _f, fontSize: 24, fontWeight: FontWeight.w700);
  static const statLabel = TextStyle(
      fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.inkSoft);
  static const tag = TextStyle(
      fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6);
  static const navLabel = TextStyle(
      fontFamily: _f, fontSize: 12, fontWeight: FontWeight.w600);
}