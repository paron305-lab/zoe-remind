import 'package:flutter/material.dart';

/// PNG icon from assets/images/icons (Flutter picks 1x/2x/3x by itself).
/// Decorative: the text next to it carries the meaning.
class ZoeIcon extends StatelessWidget {
  const ZoeIcon(this.path, {super.key, this.size = 20});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: size,
      height: size,
      excludeFromSemantics: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stack) =>
          SizedBox(width: size, height: size),
    );
  }
}

