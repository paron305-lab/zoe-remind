import 'package:flutter/material.dart';
import 'package:zoe_remind/core/constants/asset_paths.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/theme/colors.dart';
import 'package:zoe_remind/features/onboarding/widgets/glass_pill.dart';
import 'package:zoe_remind/features/onboarding/widgets/onboarding_page_body.dart';
import 'package:zoe_remind/features/onboarding/widgets/onboarding_styles.dart';
import 'package:zoe_remind/features/onboarding/widgets/zoe_icon.dart';

/// Step 2 — pick English / Tagalog / Both. No option is preselected,
/// so none looks like the "default".
class LanguagePage extends StatelessWidget {
  const LanguagePage({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ZoeLanguage? selected;
  final ValueChanged<ZoeLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    return OnboardingPageBody(
      children: [
        const Spacer(),
        const GlassCircle(child: ZoeIcon(ZoeAssets.icGlobe, size: 30)),
        const SizedBox(height: 24),
        const Text(
          'How should I talk to you?',
          style: OnboardingStyles.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Pick a language. You can change it anytime in Settings.',
          style: OnboardingStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        for (final language in ZoeLanguage.values) ...[
          _LanguageOption(
            language: language,
            selected: language == selected,
            onTap: () => onSelected(language),
          ),
          const SizedBox(height: 12),
        ],
        const Spacer(),
      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final ZoeLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = selected ? ZoeColors.ink : Colors.white;
    final subtitleColor = selected
        ? ZoeColors.ink.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.9);

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: Colors.white.withValues(alpha: selected ? 1 : 0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.label,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        language.description,
                        style: TextStyle(fontSize: 13, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: selected
                      ? const ZoeIcon(
                          ZoeAssets.icCheckLavender,
                          size: 22,
                          key: ValueKey('on'),
                        )
                      : Container(
                          key: const ValueKey('off'),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                              width: 2,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}