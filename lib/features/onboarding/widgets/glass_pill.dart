import 'package:flutter/material.dart';
import 'package:zoe_remind/features/onboarding/widgets/onboarding_styles.dart';
import 'package:zoe_remind/features/onboarding/widgets/zoe_icon.dart';

/// Frosted pill: the "Your offline AI companion" badge (bordered, bold)
/// and the privacy line (no border, regular).
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.iconPath,
    required this.label,
    this.iconSize = 16,
    this.bordered = false,
    this.emphasized = false,
  });

  final String iconPath;
  final String label;
  final double iconSize;
  final bool bordered;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: bordered ? 10 : 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: bordered ? 0.16 : 0.18),
        borderRadius: BorderRadius.circular(bordered ? 999 : 16),
        border: bordered
            ? Border.all(color: Colors.white.withValues(alpha: 0.45))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ZoeIcon(iconPath, size: iconSize),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: emphasized
                  ? OnboardingStyles.pillBold
                  : OnboardingStyles.pillRegular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted circle holding an icon (language step header).
class GlassCircle extends StatelessWidget {
  const GlassCircle({super.key, required this.child, this.size = 72});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}