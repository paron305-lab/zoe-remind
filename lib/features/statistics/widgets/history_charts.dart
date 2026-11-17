import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zoe_remind/core/theme/zoe_theme.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Kulay na pang-History lang (charts).
class HistoryColors {
  HistoryColors._();

  /// Bar na hindi naka-highlight.
  static Color get barSoft =>
      ZoeTheme.pick(const Color(0xFFDDD8F6), const Color(0xFF3A3558));

  /// Track sa likod ng bar / donut.
  static Color get track =>
      ZoeTheme.pick(const Color(0xFFF0EEFA), const Color(0xFF2E2A42));

  /// Fill ng monthly bars.
  static Color get barFill =>
      ZoeTheme.pick(const Color(0xFFB3A9EA), const Color(0xFF6E62B8));

  static const highlight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B7FE0), Color(0xFF4FADE0)],
  );

  static const highlightRow = LinearGradient(
    colors: [Color(0xFF8B7FE0), Color(0xFF4FADE0), Color(0xFF3FBE93)],
  );
}

String formatCount(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

const _f = 'Poppins';

BoxDecoration historyCardDecoration() => BoxDecoration(
      color: HomeColors.card,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: HomeColors.divider, width: 1.5),
    );

// ───────────────────────── Donut card ─────────────────────────

/// "84 Tasks" donut + completed / pending.
class TaskDonutCard extends StatelessWidget {
  final int done;
  final int open;

  const TaskDonutCard({super.key, required this.done, required this.open});

  @override
  Widget build(BuildContext context) {
    final total = done + open;
    final ratio = total == 0 ? 0.0 : done / total;
    final pct = (ratio * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 22, 22),
      decoration: historyCardDecoration(),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ratio),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Row(
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: CustomPaint(
                painter: _DonutPainter(
                  value: value,
                  track: HomeColors.lavenderLight,
                  color: HomeColors.mint,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatCount(total),
                        style: TextStyle(
                          fontFamily: _f,
                          fontSize: total > 999 ? 22 : 28,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.ink,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        total == 1 ? 'Task' : 'Tasks',
                        style: TextStyle(
                          fontFamily: _f,
                          fontSize: 12,
                          color: HomeColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Legend(
                    color: HomeColors.mint,
                    title: '${formatCount(done)} completed',
                    sub: total == 0 ? 'No tasks yet' : '$pct% completion rate',
                  ),
                  const SizedBox(height: 14),
                  _Legend(
                    color: HomeColors.amber,
                    title: '${formatCount(open)} pending',
                    sub: open == 0 ? 'Nothing left open' : 'Still open',
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 10,
                      child: Stack(
                        children: [
                          Container(color: HistoryColors.track),
                          FractionallySizedBox(
                            widthFactor: value.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: HomeColors.mint,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String title;
  final String sub;
  const _Legend({required this.color, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: _f,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.ink,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontFamily: _f,
                  fontSize: 12,
                  color: HomeColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double value;
  final Color track;
  final Color color;
  _DonutPainter({required this.value, required this.track, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    if (value <= 0) return;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = value >= 1 ? StrokeCap.butt : StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.value != value || old.track != track || old.color != color;
}

// ───────────────────────── Weekly bars ─────────────────────────

/// "Tasks completed / week" — W1…W5. Ang pinakamataas ay naka-gradient.
class WeekBarChart extends StatelessWidget {
  final List<int> values;
  const WeekBarChart({super.key, required this.values});

  static const _maxBar = 96.0;

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<int>(0, math.max);
    final best = maxV == 0 ? -1 : values.indexOf(maxV);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: historyCardDecoration(),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${values[i]}',
                      style: TextStyle(
                        fontFamily: _f,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: i == best ? HomeColors.lavender : HomeColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: values.length > 4 ? 46 : 56,
                      height: maxV == 0
                          ? 8
                          : math.max(8.0, _maxBar * (values[i] / maxV) * t),
                      decoration: BoxDecoration(
                        gradient: i == best ? HistoryColors.highlight : null,
                        color: i == best ? null : HistoryColors.barSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'W${i + 1}',
                      style: TextStyle(
                        fontFamily: _f,
                        fontSize: 13,
                        color: HomeColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Horizontal rows ─────────────────────────

class OverviewRow {
  final String label;
  final int value;
  final bool highlight;
  const OverviewRow(this.label, this.value, {this.highlight = false});
}

/// "Monthly overview" (Year) o "Yearly overview" (All time).
class OverviewBarChart extends StatelessWidget {
  final List<OverviewRow> rows;
  const OverviewBarChart({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final maxV = rows.fold<int>(0, (m, r) => math.max(m, r.value));

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: historyCardDecoration(),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => Column(
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        r.label,
                        style: TextStyle(
                          fontFamily: _f,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: r.highlight ? HomeColors.lavender : HomeColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 22,
                          child: Stack(
                            children: [
                              Container(color: HistoryColors.track),
                              FractionallySizedBox(
                                widthFactor:
                                    maxV == 0 ? 0 : (r.value / maxV * t).clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient:
                                        r.highlight ? HistoryColors.highlightRow : null,
                                    color: r.highlight ? null : HistoryColors.barFill,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 62,
                      child: Text(
                        formatCount(r.value),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: _f,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: r.highlight ? HomeColors.lavender : HomeColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}