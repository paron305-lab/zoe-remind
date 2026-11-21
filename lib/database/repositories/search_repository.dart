import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';

/// Kumukuha ng mga KANDIDATO (notes + memories) para sa Retriever.
/// Ang Retriever ang nagsi-score at pumipili — dito, paghahanap lang.
///
/// FTS4 (notes_fts / memories_fts) kapag gumagana sa phone;
/// kung hindi (o pumalya ang query) → LIKE, gaya ng dati.
class SearchRepository {
  static const _notes = StorageConstants.notesTable;
  static const _notesFts = StorageConstants.notesFtsTable;
  static const _memories = StorageConstants.memoriesTable;
  static const _memoriesFts = StorageConstants.memoriesFtsTable;

  /// Hanggang ilan kada salita.
  static const perTerm = 30;

  /// Lahat ng note / memory na may kahit isang salita mula sa [terms].
  Future<List<RetrievalDoc>> candidates(
    List<TermGroup> terms, {
    bool includeMemories = true,
  }) async {
    if (terms.isEmpty) return const [];
    final db = await ZoeDatabase.instance.database;
    final found = <String, RetrievalDoc>{};

    void keep(RetrievalDoc d) => found['${d.source.name}:${d.id}'] = d;

    if (ZoeDatabase.instance.searchReady) {
      try {
        for (final t in terms) {
          (await _ftsNotes(db, t)).forEach(keep);
          if (includeMemories) (await _ftsMemories(db, t)).forEach(keep);
        }
        return found.values.toList();
      } on DatabaseException catch (e) {
        debugPrint('FTS search failed, using LIKE: $e');
        found.clear();
      }
    }

    for (final t in terms) {
      (await _likeNotes(db, t)).forEach(keep);
      if (includeMemories) (await _likeMemories(db, t)).forEach(keep);
    }
    return found.values.toList();
  }

  // ───────────────────────── FTS4 ─────────────────────────

  Future<List<RetrievalDoc>> _ftsNotes(Database db, TermGroup t) async {
    final rows = await db.rawQuery(
      'SELECT id, title, content, pinned, updated_at FROM $_notes '
      'WHERE id IN (SELECT docid FROM $_notesFts WHERE $_notesFts MATCH ?) '
      'ORDER BY pinned DESC, updated_at DESC LIMIT $perTerm',
      [t.matchExpr],
    );
    return rows.map(RetrievalDoc.noteRow).toList();
  }

  Future<List<RetrievalDoc>> _ftsMemories(Database db, TermGroup t) async {
    final rows = await db.rawQuery(
      'SELECT id, content, importance, updated_at FROM $_memories '
      'WHERE id IN (SELECT docid FROM $_memoriesFts WHERE $_memoriesFts MATCH ?) '
      'ORDER BY updated_at DESC LIMIT $perTerm',
      [t.matchExpr],
    );
    return rows.map(RetrievalDoc.memoryRow).toList();
  }

  // ───────────────────────── LIKE (fallback) ─────────────────────────
  // Substring ito ("pin" sa "shopping"), pero sinasala ulit ng Retriever
  // gamit ang parehong patakaran ng FTS, kaya hindi lalabas ang mali.

  Future<List<RetrievalDoc>> _likeNotes(Database db, TermGroup t) async {
    final where = t.alts.map((_) => '(title LIKE ? OR content LIKE ?)').join(' OR ');
    final args = [for (final a in t.alts) ...['%$a%', '%$a%']];
    final rows = await db.query(
      _notes,
      columns: ['id', 'title', 'content', 'pinned', 'updated_at'],
      where: where,
      whereArgs: args,
      orderBy: 'pinned DESC, updated_at DESC',
      limit: perTerm,
    );
    return rows.map(RetrievalDoc.noteRow).toList();
  }

  Future<List<RetrievalDoc>> _likeMemories(Database db, TermGroup t) async {
    final where = t.alts.map((_) => 'content LIKE ?').join(' OR ');
    final rows = await db.query(
      _memories,
      columns: ['id', 'content', 'importance', 'updated_at'],
      where: where,
      whereArgs: [for (final a in t.alts) '%$a%'],
      orderBy: 'updated_at DESC',
      limit: perTerm,
    );
    return rows.map(RetrievalDoc.memoryRow).toList();
  }
}