import 'package:flutter/material.dart';

/// Zoe-Remind color system (from the Mobile UI Design Concept).
/// Color always means something: lavender = primary/AI, mint = success,
/// coral = reminders/alerts, sky = info, amber = habits/warnings.
class ZoeColors {
  ZoeColors._();

  static const lavender = Color(0xFF8B7FE0);
  static const sky = Color(0xFF4FADE0);
  static const coral = Color(0xFFF0768E);
  static const mint = Color(0xFF3FBE93);
  static const amber = Color(0xFFF0AA45);
  static const ink = Color(0xFF2B2A3D);
  static const cream = Color(0xFFFFF8EC);

  /// Deeper lavender for text/icons on white (buttons, selected cards).
  static const lavenderDeep = Color(0xFF6E5CD6);

  /// Onboarding background gradient (lavender → sky → mint).
  static const onboardingGradient = [
    Color(0xFF9F96EE),
    Color(0xFF7E9BE6),
    Color(0xFF5BB8D6),
    Color(0xFF45C2A4),
  ];
}