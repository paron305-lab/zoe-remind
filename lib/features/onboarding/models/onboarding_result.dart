import 'package:zoe_remind/core/constants/zoe_language.dart';

/// What the user chose during onboarding. The caller saves it
/// (settings / model_state / user_profile) and navigates to Home.
class OnboardingResult {
  const OnboardingResult({
    required this.language,
    required this.downloadModel,
    required this.name,
    required this.age,
    required this.policyVersion,
  });

  final ZoeLanguage language;

  /// true = "Let's get my brain ready", false = "Maybe later".
  final bool downloadModel;

  final String name;
  final int age;

  /// Which policy version the user agreed to (ZoePolicy.version).
  final String policyVersion;
}