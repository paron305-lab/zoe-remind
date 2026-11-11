import 'package:flutter/foundation.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/models/note.dart';

/// The only place that reads/writes the notes table.
/// Zoe Chat (later) also saves notes through here: add(source: zoe).
class NoteRepository {
  static const _table = StorageConstants.notesTable;

  /// Tumataas kada may nabago (add / edit / pin / delete).
  /// Nakikinig dito ang Notes screen, kaya kapag si Zoe ang nag-save
  /// galing sa chat, kusa itong lalabas sa Notes tab.
  static final changes = ValueNotifier<int>(0);

  void _changed() => changes.value++;

  String _now() => DateTime.now().toIso8601String();

  /// Returns the new id.
  Future<int> add({
    required String title,
    required String content,
    NoteSource source = NoteSource.typed,
    bool pinned = false,
  }) async {
    final db = await ZoeDatabase.instance.database;
    final now = _now();
    final id = await db.insert(_table, {
      'title': Note.titleFrom(title, content),
      'content': content.trim(),
      'source': source.name,
      'pinned': pinned ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });
    _changed();
    return id;
  }

  /// Sine-save ang title, content at pin. Hindi nababago ang source
  /// (ang note ni Zoe ay "From Zoe" pa rin kahit i-edit mo).
  Future<void> update(Note note) async {
    if (note.id == null) throw ArgumentError('Note has no id');
    final db = await ZoeDatabase.instance.database;
    await db.update(
      _table,
      {
        'title': Note.titleFrom(note.title, note.content),
        'content': note.content.trim(),
        'pinned': note.pinned ? 1 : 0,
        'updated_at': _now(),
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );
    _changed();
  }

  /// Pin / unpin. Hindi binabago ang updated_at — hindi ito "edit".
  Future<void> setPinned(int id, bool pinned) async {
    final db = await ZoeDatabase.instance.database;
    await db.update(_table, {'pinned': pinned ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<Note?> getById(int id) async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Note.fromMap(rows.first);
  }

  /// Pinned muna, tapos pinakabagong na-edit.
  Future<List<Note>> getAll() async {
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(_table, orderBy: 'pinned DESC, updated_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  /// Keyword search sa title + content. Para sa Memory Engine / Zoe
  /// ("Ano yung na-note ko about thesis?"). Ang Notes screen ay
  /// nagfi-filter sa memory para mabilis habang nagta-type.
  Future<List<Note>> search(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final like = '%${_escapeLike(q)}%';
    final db = await ZoeDatabase.instance.database;
    final rows = await db.query(
      _table,
      where: r"title LIKE ? ESCAPE '\' OR content LIKE ? ESCAPE '\'",
      whereArgs: [like, like],
      orderBy: 'pinned DESC, updated_at DESC',
      limit: limit,
    );
    return rows.map(Note.fromMap).toList();
  }

  /// Delete ONE (risk tier: high) — laging may confirm sa UI.
  Future<void> delete(int id) async {
    final db = await ZoeDatabase.instance.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  static String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}