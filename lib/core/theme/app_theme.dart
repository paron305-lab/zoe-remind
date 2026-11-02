import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/colors.dart';
import 'package:zoe_remind/core/theme/dimensions.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: ZoeColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ZoeColors.lavender,
        primary: ZoeColors.lavender,
        secondary: ZoeColors.mint,
        error: ZoeColors.coral,
        surface: Colors.white,
      ),
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: ZoeColors.ink,
            displayColor: ZoeColors.ink,
          ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
    );
  }
}