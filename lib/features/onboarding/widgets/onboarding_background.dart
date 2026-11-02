import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/colors.dart';

/// Full-screen gradient + two soft circles, drawn in code (no image file).
class OnboardingBackground extends StatelessWidget {
  const OnboardingBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ZoeColors.onboardingGradient,
          stops: [0.0, 0.35, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -90,
            child: _Circle(
              size: 270,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: 110,
            right: -80,
            child: _Circle(
              size: 200,
              color: const Color(0xFF8FE3CF).withValues(alpha: 0.35),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}