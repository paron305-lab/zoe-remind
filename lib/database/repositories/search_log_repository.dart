import 'package:sqflite/sqflite.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/rag/rag_learning.dart';

/// R6 — ang tanging nagbabasa / nagsusulat ng search_log, learned_terms at
/// search_feedback (DB v16), at ng memories.use_count / last_used_at.
/// Ginagamit ng [RagLearning] (lib/rag/rag_learning.dart).
///
/// Sa phone lang, may limit, at nabubura sa "Burahin lahat" (WipeRepository).
///   search_log      → [maxLogs] rows at [keepDays] araw lang
///   learned_terms   → [maxTerms] pares (ang pinakamahina ang natatanggal)
///   search_feedback → [maxFeedback] item (ang pinakaluma ang natatanggal)
///
/// Walang UPSERT (wala sa lumang SQLite ng Android): UPDATE muna, at kapag
/// walang nagbago, INSERT.
class SearchLogRepository implements LearningStore {
  SearchLogRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const _log = StorageConstants.searchLogTable;
  static const _terms = StorageConstants.learnedTermsTable;
  static const _feedback = StorageConstants.searchFeedbackTable;
  static const _memories = StorageConstants.memoriesTable;

  static const maxLogs = 500;
  static const keepDays = 60;
  static const maxTerms = 200;
  static const maxFeedback = 300;

  final DateTime Function() _clock;

  Future<Database> get _db => ZoeDatabase.instance.database;

  String _now() => _clock().toIso8601String();

  // ───────────────────────── search_log ─────────────────────────

  @override
  Future<int?> addLog(SearchLogEntry entry) async {
    final db = await _db;
    final id = await db.insert(_log, entry.toRow());
    await _pruneLogs(db);
    return id;
  }

  Future<void> _pruneLogs(Database db) async {
    final cutoff = _clock().subtract(const Duration(days: keepDays)).toIso8601String();
    await db.delete(_log, where: 'created_at < ?', whereArgs: [cutoff]);
    await db.rawDelete(
      'DELETE FROM $_log WHERE id NOT IN '
      '(SELECT id FROM $_log ORDER BY id DESC LIMIT $maxLogs)',
    );
  }

  @override
  Future<void> updateLog(int id, SearchOutcome outcome, {String? docKey}) async {
    final db = await _db;
    await db.update(
      _log,
      {
        'outcome': outcome.name,
        if (docKey != null) 'doc_key': docKey,
        'updated_at': _now(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<SearchLogEntry>> recentLogs({int limit = 30, SearchOutcome? outcome}) async {
    final db = await _db;
    final rows = await db.query(
      _log,
      where: outcome == null ? null : 'outcome = ?',
      whereArgs: outcome == null ? null : [outcome.name],
      orderBy: 'id DESC',
      limit: limit,
    );
    return rows.map(SearchLogEntry.fromRow).toList();
  }

  /// Ilang row lahat (Developer / test).
  Future<int> logCount() async {
    final db = await _db;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $_log');
    return (rows.first['n'] as int?) ?? 0;
  }

  // ───────────────────────── search_feedback ─────────────────────────

  @override
  Future<void> addFeedback(String docKey, {int good = 0, int bad = 0}) async {
    if (good == 0 && bad == 0) return;
    final db = await _db;
    final now = _now();
    final changed = await db.rawUpdate(
      'UPDATE $_feedback SET good = good + ?, bad = bad + ?, updated_at = ? WHERE doc_key = ?',
      [good, bad, now, docKey],
    );
    if (changed == 0) {
      await db.insert(_feedback, {'doc_key': docKey, 'good': good, 'bad': bad, 'updated_at': now});
      await db.rawDelete(
        'DELETE FROM $_feedback WHERE doc_key NOT IN '
        '(SELECT doc_key FROM $_feedback ORDER BY updated_at DESC LIMIT $maxFeedback)',
      );
    }
  }

  @override
  Future<Map<String, DocFeedback>> feedback() async {
    final db = await _db;
    final rows = await db.query(_feedback);
    return {
      for (final r in rows)
        (r['doc_key'] as String): DocFeedback(
          good: (r['good'] as int?) ?? 0,
          bad: (r['bad'] as int?) ?? 0,
        ),
    };
  }

  // ───────────────────────── learned_terms ─────────────────────────

  @override
  Future<int> learnPair(String a, String b) async {
    final (term, alt) = LearnedTerm.normalize(a, b);
    final db = await _db;
    final now = _now();
    final changed = await db.rawUpdate(
      'UPDATE $_terms SET count = count + 1, updated_at = ? WHERE term = ? AND alt = ?',
      [now, term, alt],
    );
    if (changed == 0) {
      await db.insert(_terms, {
        'term': term,
        'alt': alt,
        'count': 1,
        'created_at': now,
        'updated_at': now,
      });
      // Sobra na → tanggalin ang pinakamahina (bilang), pinakaluma muna.
      await db.rawDelete(
        'DELETE FROM $_terms WHERE rowid NOT IN '
        '(SELECT rowid FROM $_terms ORDER BY count DESC, updated_at DESC LIMIT $maxTerms)',
      );
    }
    final rows = await db.query(_terms,
        columns: ['count'], where: 'term = ? AND alt = ?', whereArgs: [term, alt], limit: 1);
    return rows.isEmpty ? 0 : (rows.first['count'] as int?) ?? 0;
  }

  @override
  Future<List<LearnedTerm>> learnedTerms() async {
    final db = await _db;
    final rows = await db.query(_terms, orderBy: 'count DESC, updated_at DESC');
    return [
      for (final r in rows)
        LearnedTerm(
          r['term'] as String,
          r['alt'] as String,
          (r['count'] as int?) ?? 0,
          DateTime.tryParse((r['updated_at'] as String?) ?? '') ?? DateTime(2000),
        ),
    ];
  }

  @override
  Future<void> deleteLearned(String a, String b) async {
    final (term, alt) = LearnedTerm.normalize(a, b);
    final db = await _db;
    await db.delete(_terms, where: 'term = ? AND alt = ?', whereArgs: [term, alt]);
  }

  // ───────────────────────── memories (lakas) ─────────────────────────

  /// +1 sa use_count. Hindi ginagalaw ang updated_at (iyon ang "kailan
  /// sinabi", ipinapakita sa sagot at ginagamit sa ranking).
  @override
  Future<void> memoryUsed({int? id, String? content}) async {
    if (id == null && (content == null || content.trim().isEmpty)) return;
    final db = await _db;
    await db.rawUpdate(
      'UPDATE $_memories SET use_count = use_count + 1, last_used_at = ? '
      'WHERE ${id != null ? 'id = ?' : 'content = ?'}',
      [_now(), id ?? content!.trim()],
    );
  }

  @override
  Future<void> clearAll() async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(_log);
      await txn.delete(_terms);
      await txn.delete(_feedback);
      await txn.rawUpdate('UPDATE $_memories SET use_count = 0, last_used_at = NULL');
    });
  }
}