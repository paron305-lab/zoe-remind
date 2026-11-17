import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/home/widgets/zoe_avatar.dart';
import 'package:zoe_remind/features/statistics/widgets/history_charts.dart';

const _f = 'Poppins';

/// Month / Year / All time chips.
class HistoryRangeChips extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const HistoryRangeChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Material(
            color: i == selected ? HomeColors.lavender : HomeColors.lavenderLight,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => onSelect(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontFamily: _f,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: i == selected ? Colors.white : HomeColors.lavender,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class StatTileData {
  final int value;
  final String label;
  final Color color;
  final Color background;
  const StatTileData(this.value, this.label, this.color, this.background);
}

/// Kulay na tile: malaking numero + label.
class StatTile extends StatelessWidget {
  final StatTileData data;
  final bool compact;
  const StatTile({super.key, required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 20, 16, 12, 16),
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatCount(data.value),
              style: TextStyle(
                fontFamily: _f,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: data.color,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _f,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HomeColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// 2×2 grid (Month view).
class StatGrid extends StatelessWidget {
  final List<StatTileData> tiles;
  const StatGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 14));
      rows.add(Row(
        children: [
          Expanded(child: StatTile(data: tiles[i])),
          const SizedBox(width: 14),
          Expanded(
            child: i + 1 < tiles.length
                ? StatTile(data: tiles[i + 1])
                : const SizedBox.shrink(),
          ),
        ],
      ));
    }
    return Column(children: rows);
  }
}

/// Isang hanay ng 3 tiles (Year / All time).
class StatRow extends StatelessWidget {
  final List<StatTileData> tiles;
  const StatRow({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: StatTile(data: tiles[i], compact: true)),
        ],
      ],
    );
  }
}

/// Sabi ni Zoe: "You completed 62 tasks this month."
class ZoeInsightCard extends StatelessWidget {
  final String title;
  final String body;
  final String? badge;

  const ZoeInsightCard({super.key, required this.title, required this.body, this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: HomeColors.lavenderLight,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const _ZoeBubble(size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: _f,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: _f,
                    fontSize: 13,
                    color: HomeColors.inkSoft,
                    height: 1.45,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: HomeColors.mintLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontFamily: _f,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: HomeColors.mint,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Ask Zoe about a specific day…" gradient button.
class AskZoeBanner extends StatelessWidget {
  final VoidCallback onTap;
  const AskZoeBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: HomeColors.headerGradient,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C9BE8).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 18, 14),
            child: Row(
              children: [
                _ZoeBubble(size: 44),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Ask Zoe about a specific day…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _f,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bilog na lavender + Zoe logo.
class _ZoeBubble extends StatelessWidget {
  final double size;
  const _ZoeBubble({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9D8AE6), Color(0xFF7A6BD8)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ZoeAvatar(size: size, scale: 1.2),
    );
  }
}