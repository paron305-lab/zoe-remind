import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';

/// Kumukuha ng mga KANDIDATO (notes + memories + reminders + tasks) para sa
/// Retriever. Ang Retriever ang nagsi-score at pumipili — dito, paghahanap lang.
///
/// FTS4 (notes_fts / memories_fts) kapag gumagana sa phone;
/// kung hindi (o pumalya ang query) → LIKE, gaya ng dati.
///
/// R1: kasama sa paghahanap ang column na search_stems (mga ugat ng salita),
/// kaya ang "=bili" mula sa "bumili?" ay tumatama sa note na "Binili ko…".
///
/// R2: [corpusStats] — ilang notes / memories lahat, at ilan ang may bawat
/// salita (COUNT lang). Para sa IDF ng Retriever: bihirang salita = mas mabigat.
///
/// R4: kasama ang reminders + tasks. Walang FTS para sa kanila (title lang,
/// at kaunti lang ang rows): binabasa ang pinakabagong [maxItems] bawat isa,
/// tapos sinasala sa Dart gamit ang parehong patakaran (salita o ugat,
/// 4+ letra = prefix). Walang DB change — v15 pa rin.
class SearchRepository {
  static const _notes = StorageConstants.notesTable;
  static const _notesFts = StorageConstants.notesFtsTable;
  static const _memories = StorageConstants.memoriesTable;
  static const _memoriesFts = StorageConstants.memoriesFtsTable;
  static const _reminders = StorageConstants.remindersTable;
  static const _tasks = StorageConstants.tasksTable;

  /// Hanggang ilan kada salita.
  static const perTerm = 30;

  /// R4: hanggang ilang reminders / tasks ang binabasa (pinakabago muna;
  /// sa tasks, hindi pa tapos muna).
  static const maxItems = 500;

  /// R4: lahat ng nabasang reminders + tasks sa huling [candidates], kasama
  /// ang mga salita (+ ugat) ng bawat isa — para sa [corpusStats].
  List<(RetrievalDoc, List<String>)> _items = const [];

  /// R4: ilan lahat ang reminders / tasks (galing sa huling [candidates]).
  /// Para sa IDF kapag isang uri lang ang hinahanap ("may reminder ba…").
  /// Walang laman = hindi alam (fake na repository sa test).
  Map<RetrievalSource, int> get itemTotals => _itemTotals;
  Map<RetrievalSource, int> _itemTotals = const {};

  /// Lahat ng note / memory / reminder / task na may kahit isang salita mula
  /// sa [terms].
  Future<List<RetrievalDoc>> candidates(
    List<TermGroup> terms, {
    bool includeMemories = true,
  }) async {
    if (terms.isEmpty) return const [];
    final db = await ZoeDatabase.instance.database;
    final found = <String, RetrievalDoc>{};

    void keep(RetrievalDoc d) => found['${d.source.name}:${d.id}'] = d;

    // R4: reminders + tasks (pareho sa FTS at LIKE).
    final items = await _itemCandidates(db, terms);

    if (ZoeDatabase.instance.searchReady) {
      try {
        for (final t in terms) {
          (await _ftsNotes(db, t)).forEach(keep);
          if (includeMemories) (await _ftsMemories(db, t)).forEach(keep);
        }
        return [...found.values, ...items];
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
    return [
      ...found.values.where((d) {
        final words = QueryTerms.searchTokens('${d.title} ${d.text}');
        return terms.any((t) => QueryTerms.groupIn(t, words));
      }),
      ...items,
    ];
  }

  /// R2: N (lahat ng notes + memories kung ON) at df (ilan ang may bawat
  /// salita, kapareho ng order ng [terms]) para sa IDF. COUNT lang — walang
  /// binabasang laman.
  ///
  /// R4: + reminders + tasks na nabasa na ng huling [candidates] (kaya
  /// tawagin ito PAGKATAPOS ng [candidates], gaya ng ginagawa ng Retriever).
  ///
  /// null kapag hindi handa ang FTS4 (hindi pa bukas ang database, walang
  /// FTS4 sa phone, o fake na repository sa test) o pumalya ang query →
  /// ang Retriever ang tatantiya mula sa mga kandidato.
  Future<CorpusStats?> corpusStats(
    List<TermGroup> terms, {
    bool includeMemories = true,
  }) async {
    if (terms.isEmpty || !ZoeDatabase.instance.searchReady) return null;
    try {
      final db = await ZoeDatabase.instance.database;
      var n = await _count(db, 'SELECT COUNT(*) FROM $_notes');
      if (includeMemories) n += await _count(db, 'SELECT COUNT(*) FROM $_memories');
      final df = <int>[];
      for (final t in terms) {
        var c = await _count(
          db,
          'SELECT COUNT(*) FROM $_notesFts WHERE $_notesFts MATCH ?',
          [t.matchExpr],
        );
        if (includeMemories) {
          c += await _count(
            db,
            'SELECT COUNT(*) FROM $_memoriesFts WHERE $_memoriesFts MATCH ?',
            [t.matchExpr],
          );
        }
        // R4: reminders + tasks (parehong patakaran ng candidates).
        c += _items.where((it) => QueryTerms.groupIn(t, it.$2)).length;
        df.add(c);
      }
      n += _items.length;
      return CorpusStats(docCount: n, docFreq: df);
    } on DatabaseException catch (e) {
      debugPrint('corpusStats failed: $e');
      return null;
    }
  }

  static Future<int> _count(Database db, String sql, [List<Object?> args = const []]) async =>
      Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;

  // ───────────────────────── Reminders + tasks (R4) ─────────────────────────

  /// Mga reminder / task na tumama sa kahit isang salita. Binabasa lahat
  /// (hanggang [maxItems] bawat isa) at sinasala sa Dart — maliit lang ito
  /// (title + description). Kapag pumalya → walang item, tuloy ang notes.
  Future<List<RetrievalDoc>> _itemCandidates(Database db, List<TermGroup> terms) async {
    _items = const [];
    _itemTotals = const {};
    try {
      final reminders = await db.query(
        _reminders,
        columns: ['id', 'title', 'date', 'time', 'repeat', 'status', 'updated_at'],
        orderBy: 'updated_at DESC',
        limit: maxItems,
      );
      final tasks = await db.query(
        _tasks,
        columns: ['id', 'title', 'description', 'date', 'time', 'status', 'updated_at', 'created_at'],
        orderBy: "CASE WHEN status = 'done' THEN 1 ELSE 0 END, "
            'COALESCE(updated_at, created_at) DESC',
        limit: maxItems,
      );
      final all = [
        for (final r in reminders) RetrievalDoc.reminderRow(r),
        for (final r in tasks) RetrievalDoc.taskRow(r),
      ];
      _items = [
        for (final d in all) (d, QueryTerms.searchTokens('${d.title} ${d.text}')),
      ];
      _itemTotals = {
        RetrievalSource.reminder: reminders.length,
        RetrievalSource.task: tasks.length,
      };
      return [
        for (final (d, words) in _items)
          if (terms.any((t) => QueryTerms.groupIn(t, words))) d,
      ];
    } on DatabaseException catch (e) {
      debugPrint('Reminder / task search failed: $e');
      return const [];
    }
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