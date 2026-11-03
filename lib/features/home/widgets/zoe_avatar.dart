import 'package:flutter/material.dart';

class ZoeAvatar extends StatelessWidget {
  final double size;
  const ZoeAvatar({super.key, this.size = 65});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo/02_happy.png', // palitan ng ZoeAssets constant mo
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.sentiment_satisfied_alt_rounded,
        size: size,
        color: Colors.white,
      ),
    );
  }
}