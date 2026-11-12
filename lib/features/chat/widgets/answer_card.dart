import 'package:flutter/material.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/chat/widgets/chat_bubbles.dart';
import 'package:zoe_remind/features/chat/widgets/chat_styles.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Sagot sa "Ano ginawa ko noong…?" — "📅 Assuming …" chip + text + rows.
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
              child: Text('📅 ${entry.assumption}', style: ChatText.pill),
            ),
            const SizedBox(height: 12),
            Text(entry.text, style: ChatText.bubble),
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
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(row.label, style: ChatText.button.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}