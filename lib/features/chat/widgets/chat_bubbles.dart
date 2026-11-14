import 'package:flutter/material.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/chat/widgets/chat_styles.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Zoe sa kaliwa: avatar sa baba + [child] (bubble o card).
class ZoeRow extends StatelessWidget {
  final Widget child;
  final bool showAvatar;
  const ZoeRow({super.key, required this.child, this.showAvatar = true});

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.78;
    return Padding(
      padding: const EdgeInsets.only(right: 24, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: 40, child: showAvatar ? const ChatAvatar() : null),
          const SizedBox(width: 10),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// White card na may maliit na shadow (Zoe bubble, answer card, atbp).
class ZoeSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const ZoeSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ChatColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
          bottomLeft: Radius.circular(8),
        ),
        boxShadow: [
          BoxShadow(color: ChatColors.shadow, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

class UserBubble extends StatelessWidget {
  final String text;
  const UserBubble(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.75;
    return Padding(
      padding: const EdgeInsets.only(left: 48, bottom: 14),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
            decoration: const BoxDecoration(
              gradient: ChatColors.userBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Text(text, style: ChatText.bubbleUser),
          ),
        ),
      ),
    );
  }
}

class ZoeBubble extends StatelessWidget {
  final String text;
  final String? footnote;
  const ZoeBubble({super.key, required this.text, this.footnote});

  @override
  Widget build(BuildContext context) {
    return ZoeRow(
      child: ZoeSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: ChatText.bubble),
            if (footnote != null) ...[
              const SizedBox(height: 6),
              Text(footnote!, style: ChatText.footnote),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Language: English" — maliit na pill sa gitna.
class InfoPill extends StatelessWidget {
  final String text;
  const InfoPill(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: HomeColors.lavenderLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(text, style: ChatText.pill),
        ),
      ),
    );
  }
}

/// Tatlong tumatalbog na tuldok — "Thinking…".
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZoeRow(
      child: ZoeSurface(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                _dot(i),
                if (i < 2) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(int i) {
    // Bawat tuldok ay medyo late (wave).
    final t = (_anim.value - i * 0.18) % 1.0;
    final up = t < 0.5 ? t * 2 : (1 - t) * 2;
    return Transform.translate(
      offset: Offset(0, -5 * up),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: Color.lerp(ChatColors.dotLow, HomeColors.lavender, up),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Error / fallback + [Retry].
class ErrorBubble extends StatelessWidget {
  final ErrorEntry entry;
  final VoidCallback onRetry;
  const ErrorBubble({super.key, required this.entry, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ZoeRow(
      child: ZoeSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 8),
                  child: Icon(Icons.error_outline_rounded, color: HomeColors.coral, size: 20),
                ),
                Expanded(child: Text(entry.text, style: ChatText.bubble)),
              ],
            ),
            const SizedBox(height: 10),
            _SmallButton(
              icon: Icons.refresh_rounded,
              label: 'Retry',
              color: HomeColors.coral,
              fill: HomeColors.coralLight,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Anong oras?" + chips [8 AM] [12 PM] [7 PM] [Iba pa].
class ClarifyBubble extends StatelessWidget {
  final ClarifyEntry entry;
  final ValueChanged<ClarifyChip> onChip;
  const ClarifyBubble({super.key, required this.entry, required this.onChip});

  @override
  Widget build(BuildContext context) {
    final showChips = !entry.answered && entry.chips.isNotEmpty;
    return ZoeRow(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ZoeSurface(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🤔 ', style: TextStyle(fontSize: 18)),
                Flexible(child: Text(entry.question, style: ChatText.bubble)),
              ],
            ),
          ),
          if (showChips) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in entry.chips)
                  ActionChip(
                    label: Text(c.label, style: ChatText.chip),
                    avatar: c.time == null
                        ? Icon(Icons.schedule_rounded, size: 18, color: HomeColors.lavender)
                        : null,
                    backgroundColor: ChatColors.surface,
                    side: BorderSide(color: ChatColors.chipBorder, width: 1.5),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    onPressed: () => onChip(c),
                  ),
              ],
            ),
          ],
          if (!entry.answered && entry.wantsText) ...[
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('Type your answer below 👇', style: ChatText.footnote),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color fill;
  final VoidCallback onTap;

  const _SmallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.fill,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: ChatText.button.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}