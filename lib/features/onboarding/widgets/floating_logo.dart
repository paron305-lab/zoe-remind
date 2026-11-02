import 'package:flutter/material.dart';
import 'package:zoe_remind/core/constants/asset_paths.dart';

/// Zoe's teardrop logo with a gentle float — no animation file needed.
/// Stays still when the phone's "remove animations" setting is on.
class FloatingLogo extends StatefulWidget {
  const FloatingLogo({super.key, this.size = 120});

  final double size;

  @override
  State<FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<FloatingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      ZoeAssets.logo,
      width: widget.size,
      semanticLabel: 'Zoe',
      errorBuilder: (context, error, stack) => Icon(
        Icons.sentiment_very_satisfied_rounded,
        size: widget.size * 0.7,
        color: Colors.white,
      ),
    );

    if (MediaQuery.of(context).disableAnimations) return logo;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -8 * Curves.easeInOut.transform(_controller.value)),
        child: child,
      ),
      child: logo,
    );
  }
}