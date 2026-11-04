import 'package:flutter/material.dart';

class ZoeAvatar extends StatelessWidget {
  final double size;
  final double scale; // >1 = zoom in kung maraming transparent space ang PNG

  const ZoeAvatar({super.key, this.size = 64, this.scale = 1.5});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Transform.scale(
        scale: scale,
        child: Image.asset(
          'assets/images/logo/02_happy.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.sentiment_satisfied_alt_rounded,
            size: size,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}