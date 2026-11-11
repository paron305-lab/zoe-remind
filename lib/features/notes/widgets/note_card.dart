import 'package:flutter/material.dart';
import 'package:zoe_remind/database/models/note.dart';
import 'package:zoe_remind/features/notes/widgets/note_styles.dart';

/// Note card: title, 2-line preview, source pill, oras.
/// Pinned = coral→amber bar sa kaliwa + amber star.
/// Tap = buksan · Long-press = Pin / Delete (walang swipe-delete).
class NoteCard extends StatelessWidget {
  final Note note;
  final String preview;
  final String timeLabel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const NoteCard({
    super.key,
    required this.note,
    required this.preview,
    required this.timeLabel,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    return Semantics(
      button: true,
      label: '${note.pinned ? 'Pinned note' : 'Note'}: ${note.title}',
      hint: 'Long-press for pin or delete',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(color: NoteColors.cardShadow, blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Stack(
                children: [
                  if (note.pinned)
                    const Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(gradient: NoteColors.pinnedAccent),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(26, 22, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                note.title,
                                style: NoteText.cardTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (note.pinned) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.star_border_rounded,
                                  color: NoteColors.amber, size: 24),
                            ],
                          ],
                        ),
                        if (preview.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            preview,
                            style: NoteText.cardPreview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            NoteSourcePill(fromZoe: note.fromZoe),
                            const Spacer(),
                            Text(timeLabel, style: NoteText.time),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}