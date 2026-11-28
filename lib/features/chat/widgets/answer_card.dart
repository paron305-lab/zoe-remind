import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/chat/widgets/chat_bubbles.dart';
import 'package:zoe_remind/features/chat/widgets/chat_styles.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/rag/snippet.dart';

/// Sagot sa "Ano ginawa ko noong…?" — "📅 Assuming …" chip + text + rows.
/// Sagot galing sa notes / memories → 📝 / 💜 chip, at ang rows ay ang mga
/// source (pindutin para buksan ang note).
///
/// R3: naka-**bold** ang mga salitang tumama sa tanong ([AnswerEntry.bold]),
/// at may "Buong note →" kapag bahagi lang ng note ang ipinakita.
class AnswerCard extends StatelessWidget {
  final AnswerEntry entry;
  const AnswerCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return ZoeRow(
      child: ZoeSurface(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: HomeColors.skyLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${_chipIcon(entry)} ${entry.assumption}', style: ChatText.pill),
            ),
            const SizedBox(height: 12),
            Text.rich(boldSpan(entry.text, entry.bold, ChatText.bubble)),
            if (entry.more case final more?) ...[
              const SizedBox(height: 6),
              _MoreLink(more),
            ],
            for (final row in entry.rows) ...[
              const SizedBox(height: 10),
              _AnswerRowTile(row),
            ],
          ],
        ),
      ),
    );
  }
}

/// R3: [text] na may bold sa [bold]. Ang span na lampas / patong / mali ay
/// nilalaktawan (hindi nagka-crash ang chat kahit mali ang offsets).
TextSpan boldSpan(String text, List<SnippetSpan> bold, TextStyle style) {
  if (bold.isEmpty) return TextSpan(text: text, style: style);
  final strong = style.copyWith(fontWeight: FontWeight.w700);
  final children = <TextSpan>[];
  var at = 0;
  for (final s in bold) {
    if (s.start < at || s.end <= s.start || s.end > text.length) continue;
    if (s.start > at) children.add(TextSpan(text: text.substring(at, s.start)));
    children.add(TextSpan(text: text.substring(s.start, s.end), style: strong));
    at = s.end;
  }
  if (at < text.length) children.add(TextSpan(text: text.substring(at)));
  return TextSpan(style: style, children: children);
}

/// "Buong note →" — maliit na link sa ilalim ng snippet.
class _MoreLink extends StatelessWidget {
  final AnswerLink link;
  const _MoreLink(this.link);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(link.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          link.label,
          style: ChatText.button.copyWith(color: HomeColors.lavender, fontSize: 14),
        ),
      ),
    );
  }
}

/// 📝 kapag galing sa notes, 💜 kapag sa memories, 📅 kapag history / schedule.
String _chipIcon(AnswerEntry e) {
  final first = e.rows.isEmpty ? null : e.rows.first.tone;
  return switch (first) {
    AnswerTone.note => '📝',
    AnswerTone.memory => '💜',
    _ => '📅',
  };
}

class _AnswerRowTile extends StatelessWidget {
  final AnswerRow row;
  const _AnswerRowTile(this.row);

  @override
  Widget build(BuildContext context) {
    final (icon, color, fill) = switch (row.tone) {
      AnswerTone.done => (Icons.check_rounded, HomeColors.mint, HomeColors.mintLight),
      AnswerTone.reminder => (Icons.notifications_none_rounded, HomeColors.coral, HomeColors.coralLight),
      AnswerTone.event => (Icons.event_note_rounded, HomeColors.sky, HomeColors.skyLight),
      AnswerTone.missed => (Icons.history_toggle_off_rounded, ChatColors.amber, ChatColors.amberLight),
      AnswerTone.note => (Icons.sticky_note_2_outlined, HomeColors.lavender, ChatColors.cardHeader),
      AnswerTone.memory => (Icons.auto_awesome_outlined, HomeColors.lavender, ChatColors.cardHeader),
    };
    final route = row.route;
    final radius = BorderRadius.circular(16);
    return Material(
      color: fill,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: route == null ? null : () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ChatText.button.copyWith(color: color),
                ),
              ),
              if (route != null) Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}