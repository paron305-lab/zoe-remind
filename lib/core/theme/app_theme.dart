import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/dimensions.dart';

/// Material theme para sa light at dark mode.
/// Fixed na kulay dito (hindi ang ZoeTheme getters) kasi parehong theme
/// ay ginagawa nang sabay ng MaterialApp.
class AppTheme {
  AppTheme._();

  static const _lavender = Color(0xFF8B7FE0);
  static const _lavenderDark = Color(0xFFA596F2);
  static const _mint = Color(0xFF3FBE93);
  static const _coral = Color(0xFFF0768E);

  static const _lightBg = Color(0xFFFFF8EC);
  static const _lightInk = Color(0xFF2B2A3D);

  static const _darkBg = Color(0xFF16151F);
  static const _darkCard = Color(0xFF221F30);
  static const _darkInk = Color(0xFFF2F0FA);

  static ThemeData light() => _build(
        brightness: Brightness.light,
        bg: _lightBg,
        card: Colors.white,
        ink: _lightInk,
        primary: _lavender,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        bg: _darkBg,
        card: _darkCard,
        ink: _darkInk,
        primary: _lavenderDark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color card,
    required Color ink,
    required Color primary,
  }) {
    final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _lavender,
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: _mint,
        error: _coral,
        surface: card,
        onSurface: ink,
      ),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      cardTheme: CardThemeData(color: card, elevation: 0, shape: shape),
      dialogTheme: DialogThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(color: card, surfaceTintColor: Colors.transparent),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}