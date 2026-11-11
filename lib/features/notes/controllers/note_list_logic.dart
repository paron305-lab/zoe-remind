import 'package:flutter/material.dart' show TimeOfDay;
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/note.dart';

enum NoteFilter {
  all('All'),
  pinned('Pinned'),
  fromZoe('From Zoe'),
  typed('Typed');

  final String label;
  const NoteFilter(this.label);
}

/// Anong oras ang basehan ng grouping at sorting.
enum NoteSort {
  edited('Last edited'),
  created('Date created');

  final String label;
  const NoteSort(this.label);
}

class NoteGroup {
  final String label;
  final List<Note> notes;
  final bool pinned;
  const NoteGroup(this.label, this.notes, {this.pinned = false});
}

/// Pure logic (walang UI) para madaling i-test.
class NoteListLogic {
  NoteListLogic._();

  static DateTime timeOf(Note n, NoteSort sort) =>
      sort == NoteSort.created ? n.createdAtTime : n.updatedAtTime;

  static List<Note> applyFilter(List<Note> notes, NoteFilter filter, {String query = ''}) {
    final q = query.trim().toLowerCase();
    return notes.where((n) {
      final okFilter = switch (filter) {
        NoteFilter.all => true,
        NoteFilter.pinned => n.pinned,
        NoteFilter.fromZoe => n.fromZoe,
        NoteFilter.typed => !n.fromZoe,
      };
      if (!okFilter) return false;
      if (q.isEmpty) return true;
      return n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q);
    }).toList();
  }

  /// Pinned (sariling section) → Today → Yesterday → This week → Older.
  /// Walang laman na group = hindi ipinapakita.
  static List<NoteGroup> group(List<Note> notes, DateTime now,
      {NoteSort sort = NoteSort.edited}) {
    int newestFirst(Note a, Note b) => timeOf(b, sort).compareTo(timeOf(a, sort));

    final pinned = notes.where((n) => n.pinned).toList()..sort(newestFirst);
    final rest = notes.where((n) => !n.pinned).toList()..sort(newestFirst);

    final today = ZoeDate.dayOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(const Duration(days: 6));

    final buckets = <String, List<Note>>{
      'Today': [],
      'Yesterday': [],
      'This week': [],
      'Older': [],
    };
    for (final n in rest) {
      final d = ZoeDate.dayOnly(timeOf(n, sort));
      final key = !d.isBefore(today)
          ? 'Today'
          : !d.isBefore(yesterday)
              ? 'Yesterday'
              : !d.isBefore(weekStart)
                  ? 'This week'
                  : 'Older';
      buckets[key]!.add(n);
    }

    return [
      if (pinned.isNotEmpty) NoteGroup('Pinned', pinned, pinned: true),
      for (final e in buckets.entries)
        if (e.value.isNotEmpty) NoteGroup(e.key, e.value),
    ];
  }

  /// Label sa kanan ng card.
  /// - na-edit within 24h → "Edited 2h ago" / "Edited 5m ago" / "Edited just now"
  /// - ngayong araw        → "9:12 AM"
  /// - kahapon / this week → "Tue · 9:12 AM"
  /// - mas luma            → "Nov 3"
  static String timeLabel(Note n, DateTime now, {NoteSort sort = NoteSort.edited}) {
    if (sort == NoteSort.edited && n.wasEdited) {
      final ago = now.difference(n.updatedAtTime);
      if (ago.inMinutes < 1) return 'Edited just now';
      if (ago.inMinutes < 60) return 'Edited ${ago.inMinutes}m ago';
      if (ago.inHours < 24) return 'Edited ${ago.inHours}h ago';
    }
    final t = timeOf(n, sort);
    final time = ZoeDate.prettyTime(TimeOfDay(hour: t.hour, minute: t.minute));
    final today = ZoeDate.dayOnly(now);
    final day = ZoeDate.dayOnly(t);
    if (!day.isBefore(today)) return time;
    if (today.difference(day).inDays < 7) {
      return '${ZoeDate.weekday(t).substring(0, 3)} · $time';
    }
    return t.year == now.year ? ZoeDate.short(t) : ZoeDate.pretty(t);
  }

  /// Preview sa card: walang sobrang blank lines.
  static String preview(Note n) =>
      n.content.trim().replaceAll(RegExp(r'\s*\n\s*'), ' ');
}