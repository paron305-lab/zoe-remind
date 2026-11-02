import 'package:flutter/material.dart';
import 'package:zoe_remind/core/constants/asset_paths.dart';
import 'package:zoe_remind/features/onboarding/widgets/floating_logo.dart';
import 'package:zoe_remind/features/onboarding/widgets/glass_pill.dart';
import 'package:zoe_remind/features/onboarding/widgets/onboarding_page_body.dart';
import 'package:zoe_remind/features/onboarding/widgets/onboarding_styles.dart';

/// Step 1 — "Hi, I'm Zoe!"
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingPageBody(
      children: [
        const Spacer(flex: 2),
        const FloatingLogo(size: 120),
        const SizedBox(height: 36),
        const GlassPill(
          iconPath: ZoeAssets.icSparkle,
          label: 'Your offline AI companion',
          bordered: true,
          emphasized: true,
        ),
        const SizedBox(height: 22),
        const Text(
          "Hi, I'm Zoe!",
          style: OnboardingStyles.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Text(
          "I'll help you remember tasks, notes, and the little things — "
          'right on your phone, in English, Tagalog, or both.',
          style: OnboardingStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        const GlassPill(
          iconPath: ZoeAssets.icLock,
          iconSize: 18,
          label: 'Everything stays on your device. Always.',
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}