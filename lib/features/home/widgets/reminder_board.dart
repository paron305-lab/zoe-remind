import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/models/home_item.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

class ReminderBoard extends StatelessWidget {
  final List<HomeItem> items;
  final ValueChanged<HomeItem> onToggle;

  const ReminderBoard({super.key, required this.items, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: HomeColors.ink.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(28),
                child: Text('Nothing scheduled yet. Tap + to add one.',
                    style: HomeText.time),
              )
            : Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    _BoardRow(item: items[i], onToggle: onToggle),
                    if (i != items.length - 1)
                      const Divider(height: 1, thickness: 1, color: HomeColors.divider),
                  ],
                ],
              ),
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  final HomeItem item;
  final ValueChanged<HomeItem> onToggle;
  const _BoardRow({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final titleColor =
        item.done ? HomeColors.inkSoft.withValues(alpha: 0.6) : HomeColors.ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(item.timeLabel, style: HomeText.time)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.itemTitle.copyWith(
                    color: titleColor,
                    decoration:
                        item.done ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationColor: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                TagPill(type: item.type),
              ],
            ),
          ),
          ZoeCheckbox(checked: item.done, onTap: () => onToggle(item)),
        ],
      ),
    );
  }
}

class TagPill extends StatelessWidget {
  final HomeItemType type;
  const TagPill({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: type.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(type.label, style: HomeText.tag.copyWith(color: type.color)),
    );
  }
}

class ZoeCheckbox extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  const ZoeCheckbox({super.key, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(6), // mas malaking tap target
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: checked ? HomeColors.lavender : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: checked
                  ? null
                  : Border.all(color: HomeColors.checkboxBorder, width: 2),
            ),
            child: checked
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                : null,
          ),
        ),
      ),
    );
  }
}