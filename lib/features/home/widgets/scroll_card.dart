import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// White card that scrolls inside when it has more rows than [visibleRows].
class ScrollCard extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double rowHeight;
  final double visibleRows;

  const ScrollCard({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.rowHeight = 96,
    this.visibleRows = 3.5, // .5 = kalahating row para halatang may kasunod
  });

  @override
  State<ScrollCard> createState() => _ScrollCardState();
}

class _ScrollCardState extends State<ScrollCard> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: BoxConstraints(maxHeight: widget.rowHeight * widget.visibleRows),
      decoration: BoxDecoration(
        color: HomeColors.card,
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
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: widget.itemCount > widget.visibleRows,
          radius: const Radius.circular(8),
          child: ListView.separated(
            controller: _controller,
            primary: false,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            itemCount: widget.itemCount,
            itemBuilder: widget.itemBuilder,
            separatorBuilder: (_, __) =>
                Divider(height: 1, thickness: 1, color: HomeColors.divider),
          ),
        ),
      ),
    );
  }
}