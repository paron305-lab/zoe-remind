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
///
/// R1: kasama sa paghahanap ang column na search_stems (mga ugat ng salita),
/// kaya ang "=bili" mula sa "bumili?" ay tumatama sa note na "Binili ko…".
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
    // LIKE ay substring ("pass" sa "passport") → salain gamit ang parehong
    // patakaran ng FTS (prefix 4+ letra, "=" eksakto), para pareho ang lumalabas.
    // Kasama ang ugat (R1), gaya ng search_stems sa FTS.
    return found.values
        .where((d) {
          final words = QueryTerms.searchTokens('${d.title} ${d.text}');
          return terms.any((t) => QueryTerms.groupIn(t, words));
        })
        .toList();
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
  // Substring ito ("pin" sa "shopping"), kaya sinasala sa [candidates]
  // gamit ang parehong patakaran ng FTS, at hindi lalabas ang mali.

  Future<List<RetrievalDoc>> _likeNotes(Database db, TermGroup t) async {
    final where = t.plainAlts
        .map((_) => '(title LIKE ? OR content LIKE ? OR search_stems LIKE ?)')
        .join(' OR ');
    final args = [for (final a in t.plainAlts) ...['%$a%', '%$a%', '%$a%']];
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
    final where = t.plainAlts.map((_) => '(content LIKE ? OR search_stems LIKE ?)').join(' OR ');
    final rows = await db.query(
      _memories,
      columns: ['id', 'content', 'importance', 'updated_at'],
      where: where,
      whereArgs: [for (final a in t.plainAlts) ...['%$a%', '%$a%']],
      orderBy: 'updated_at DESC',
      limit: perTerm,
    );
    return rows.map(RetrievalDoc.memoryRow).toList();
  }
}