import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

class ZoeFab extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const ZoeFab({super.key, required this.onTap, this.size = 45});

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.36; // rounded corners sumasabay sa laki

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: HomeColors.fabGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: HomeColors.lavender.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Icon(Icons.add_rounded, color: Colors.white, size: size * 0.52),
        ),
      ),
    );
  }
}