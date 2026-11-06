import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/models/home_item.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

class ReminderBoard extends StatefulWidget {
  final List<HomeItem> items;

  /// null = read-only board (no checkboxes), e.g. "Coming up".
  final ValueChanged<HomeItem>? onToggle;

  /// Tap a row → edit it. null = rows aren't tappable.
  final ValueChanged<HomeItem>? onTap;

  /// Swipe a row left → ask first ([confirmDelete]), then [onDelete].
  /// Both null = no swipe-to-delete.
  final Future<bool> Function(HomeItem)? confirmDelete;
  final ValueChanged<HomeItem>? onDelete;

  final String emptyText;

  /// Ilang row ang kita bago mag-scroll sa loob ng card.
  /// .5 = kalahating row para halatang may kasunod pa.
  final double maxVisibleRows;

  const ReminderBoard({
    super.key,
    required this.items,
    this.onToggle,
    this.onTap,
    this.confirmDelete,
    this.onDelete,
    this.emptyText = 'Nothing scheduled yet. Tap + to add one.',
    this.maxVisibleRows = 3.5,
  });

  @override
  State<ReminderBoard> createState() => _ReminderBoardState();
}

class _ReminderBoardState extends State<ReminderBoard> {
  static const double _rowHeight = 86; // tinatayang taas ng isang row
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _buildRow(HomeItem item) {
    final row = _BoardRow(item: item, onToggle: widget.onToggle, onTap: widget.onTap);
    final confirm = widget.confirmDelete;
    final onDelete = widget.onDelete;
    if (confirm == null || onDelete == null) return row;

    return Dismissible(
      // same reminder can show on several days in "Coming up" → add the day
      key: ValueKey('board-${item.id}-${item.dateLabel ?? 'today'}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirm(item),
      onDismissed: (_) => onDelete(item),
      background: Container(
        color: HomeColors.coralLight,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        child: const Icon(Icons.delete_outline_rounded, color: HomeColors.coral, size: 28),
      ),
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final scrollable = items.length > widget.maxVisibleRows;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: BoxConstraints(
        maxHeight: _rowHeight * widget.maxVisibleRows,
      ),
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
            ? Padding(
                padding: const EdgeInsets.all(28),
                child: Text(widget.emptyText, style: HomeText.time),
              )
            : Scrollbar(
                controller: _scroll,
                thumbVisibility: scrollable,
                radius: const Radius.circular(8),
                child: ListView.separated(
                  controller: _scroll,
                  primary: false,
                  shrinkWrap: true, // kung kaunti lang, sakto lang ang taas
                  padding: EdgeInsets.zero,
                  physics: scrollable
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _buildRow(items[i]),
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, thickness: 1, color: HomeColors.divider),
                ),
              ),
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  final HomeItem item;
  final ValueChanged<HomeItem>? onToggle;
  final ValueChanged<HomeItem>? onTap;
  const _BoardRow({required this.item, required this.onToggle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = _content();
    if (onTap == null) return row;
    return Material(
      color: Colors.white,
      child: InkWell(onTap: () => onTap!(item), child: row),
    );
  }

  Widget _content() {
    final titleColor =
        item.done ? HomeColors.inkSoft.withValues(alpha: 0.6) : HomeColors.ink;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 18, 14),
      child: Row(
        children: [
          // Date + time sa kaliwa
          SizedBox(
            width: 96, // sapat para sa "Tomorrow" nang hindi dumidikit sa title
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.dateLabel ?? 'Today',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HomeText.time.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.lavender,
                  ),
                ),
                const SizedBox(height: 2),
                Text(item.timeLabel, style: HomeText.time),
              ],
            ),
          ),
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
          if (onToggle != null)
            ZoeCheckbox(checked: item.done, onTap: () => onToggle!(item)),
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