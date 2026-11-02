import 'package:flutter/material.dart';

/// Text styles for the onboarding screens (Poppins display, default body).
class OnboardingStyles {
  OnboardingStyles._();

  static const title = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.2,
  );

  static const heading = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.25,
  );

  static final body = TextStyle(
    fontSize: 15,
    height: 1.55,
    color: Colors.white.withValues(alpha: 0.95),
  );

  static const pillBold = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static final pillRegular = TextStyle(
    fontSize: 13,
    letterSpacing: 0.3,
    color: Colors.white.withValues(alpha: 0.95),
  );
}