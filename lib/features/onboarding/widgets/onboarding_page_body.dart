import 'package:flutter/material.dart';

/// Centers a step's content and scrolls on short screens,
/// so nothing overflows on small 4 GB phones or with large system fonts.
class OnboardingPageBody extends StatelessWidget {
  const OnboardingPageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(children: children),
            ),
          ),
        );
      },
    );
  }
}