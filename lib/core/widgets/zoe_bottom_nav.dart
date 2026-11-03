import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

class ZoeBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ZoeBottomNav({super.key, required this.currentIndex, required this.onTap});

  static const _items = <(IconData, String)>[
    (Icons.home_outlined, 'Home'),
    (Icons.chat_bubble_outline_rounded, 'Zoe'),
    (Icons.check_box_outlined, 'Tasks'),
    (Icons.description_outlined, 'Notes'),
    (Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: HomeColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_items[i].$1,
                            size: 26,
                            color: i == currentIndex
                                ? HomeColors.lavender
                                : HomeColors.navInactive),
                        const SizedBox(height: 4),
                        Text(
                          _items[i].$2,
                          style: HomeText.navLabel.copyWith(
                            color: i == currentIndex
                                ? HomeColors.lavender
                                : HomeColors.navInactive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}