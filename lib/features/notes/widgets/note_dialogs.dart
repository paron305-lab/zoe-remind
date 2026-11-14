import 'package:flutter/material.dart';
import 'package:zoe_remind/database/models/note.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';
import 'package:zoe_remind/features/home/widgets/zoe_avatar.dart';
import 'package:zoe_remind/features/notes/controllers/note_list_logic.dart';
import 'package:zoe_remind/features/notes/widgets/note_styles.dart';

enum NoteAction { pin, delete }

const _f = 'Poppins';

/// Long-press menu: Pin / Unpin · Delete.
Future<NoteAction?> showNoteActions(BuildContext context, Note note) {
  return showModalBottomSheet<NoteAction>(
    context: context,
    backgroundColor: HomeColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: HomeColors.divider, borderRadius: BorderRadius.circular(3)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Text(note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NoteText.cardTitle),
            ),
            _SheetRow(
              icon: note.pinned ? Icons.star_rounded : Icons.star_border_rounded,
              color: NoteColors.amber,
              label: note.pinned ? 'Unpin' : 'Pin to top',
              onTap: () => Navigator.pop(ctx, NoteAction.pin),
            ),
            _SheetRow(
              icon: Icons.delete_outline_rounded,
              color: HomeColors.coral,
              label: 'Delete',
              onTap: () => Navigator.pop(ctx, NoteAction.delete),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _SheetRow(
      {required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: Icon(icon, color: color, size: 26),
      title: Text(label,
          style: TextStyle(
              fontFamily: _f, fontSize: 16, fontWeight: FontWeight.w600, color: HomeColors.ink)),
      onTap: onTap,
    );
  }
}

/// Sort menu (yung button sa header).
Future<NoteSort?> showNoteSort(BuildContext context, NoteSort current) {
  return showModalBottomSheet<NoteSort>(
    context: context,
    backgroundColor: HomeColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Sort by', style: NoteText.cardTitle),
            ),
            for (final s in NoteSort.values)
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                title: Text(s.label,
                    style: TextStyle(
                        fontFamily: _f,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: HomeColors.ink)),
                trailing: s == current
                    ? Icon(Icons.check_rounded, color: HomeColors.lavender)
                    : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> _ask(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required String cancel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: HomeColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(title,
          style: TextStyle(
              fontFamily: _f, fontWeight: FontWeight.w700, color: HomeColors.ink)),
      content: Text(body,
          style: TextStyle(
              fontFamily: _f, fontSize: 15, color: HomeColors.inkSoft, height: 1.4)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancel,
              style: TextStyle(
                  fontFamily: _f, fontWeight: FontWeight.w700, color: HomeColors.inkSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm,
              style: const TextStyle(
                  fontFamily: _f, fontWeight: FontWeight.w700, color: HomeColors.coral)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Delete ONE (risk tier: high) → laging nagtatanong muna.
Future<bool> confirmDeleteNote(BuildContext context, String title) => _ask(
      context,
      title: 'Delete this note?',
      body: '"$title" will be removed. Hindi na ito maibabalik.',
      confirm: 'Delete',
      cancel: 'Cancel',
    );

/// Paglabas sa editor na may hindi pa nase-save.
Future<bool> confirmDiscardNote(BuildContext context) => _ask(
      context,
      title: 'Discard changes?',
      body: 'Hindi pa naka-save ang binago mo sa note na ito.',
      confirm: 'Discard',
      cancel: 'Keep editing',
    );

/// Friendly message instead of a blank list.
class NotesEmptyState extends StatelessWidget {
  final NoteFilter filter;
  final bool searching;

  const NotesEmptyState({super.key, required this.filter, this.searching = false});

  (String, String) get _copy {
    if (searching) return ('Walang nahanap', 'Try a different word or clear the search.');
    return switch (filter) {
      NoteFilter.all => (
          'Wala ka pang notes',
          'Sabihin mo lang sa akin o pindutin ang + para gumawa.'
        ),
      NoteFilter.pinned => (
          'Wala pang naka-pin',
          'Long-press a note and tap Pin para laging nasa taas.'
        ),
      NoteFilter.fromZoe => (
          'Wala pang note galing sa akin',
          'Sabihin mo sa Zoe chat: "i-note mo ito…" at ise-save ko dito.'
        ),
      NoteFilter.typed => ('Wala pang typed notes', 'Tap + to write your first note.'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (title, body) = _copy;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 56, 40, 40),
      child: Column(
        children: [
          const ZoeAvatar(size: 72),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: NoteText.emptyTitle),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: NoteText.emptyBody),
        ],
      ),
    );
  }
}