import 'package:flutter/material.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Gradient header ng History: back button, title, at period card
/// ("September 2026 · 288 activities this month") na may ‹ › arrows.
class HistoryHeader extends StatelessWidget {
  final String periodLabel;
  final String periodSub;
  final VoidCallback? onBack;

  /// null = naka-disable ang arrow (hal. walang mas bagong buwan).
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  /// false sa "All time" — walang arrows.
  final bool showArrows;

  const HistoryHeader({
    super.key,
    required this.periodLabel,
    required this.periodSub,
    this.onBack,
    this.onPrev,
    this.onNext,
    this.showArrows = true,
  });

  static const _f = 'Poppins';

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 24),
      decoration: const BoxDecoration(
        gradient: HomeColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GlassButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Back',
                onTap: onBack,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Zoe History',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _f,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Memory & activity at a glance',
                      style: TextStyle(
                        fontFamily: _f,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xE6FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 10, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          periodLabel,
                          key: ValueKey(periodLabel),
                          style: const TextStyle(
                            fontFamily: _f,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        periodSub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: _f,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xF2FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showArrows) ...[
                  _Arrow(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Previous',
                    onTap: onPrev,
                  ),
                  _Arrow(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'Next',
                    onTap: onNext,
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

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _GlassButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _Arrow({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 30,
        color: Colors.white.withValues(alpha: enabled ? 1 : 0.35),
      ),
    );
  }
}