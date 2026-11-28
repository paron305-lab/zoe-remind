import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zoe_remind/core/constants/storage_constants.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/database/repositories/search_log_repository.dart';
import 'package:zoe_remind/rag/rag_learning.dart';
import 'package:zoe_remind/rag/rag_models.dart';

/// Takbuhin:  flutter test test/database/search_log_repository_test.dart
///
/// R6 (DB v16): search_log, learned_terms, search_feedback +
/// memories.use_count. Totoong SQLite sa PC (sqflite_common_ffi), sariling
/// temp folder — hindi ang phone, hindi kasabay ng ibang DB test.
void main() {
  final now = DateTime(2026, 11, 28, 15, 0);
  late Database db;
  late SearchLogRepository repo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = Directory.systemTemp.createTempSync('zoe_search_log_');
    await databaseFactory.setDatabasesPath(dir.path);
    db = await ZoeDatabase.instance.database;
    repo = SearchLogRepository(clock: () => now);
  });

  Future<Set<String>> columns(String table) async =>
      (await db.rawQuery('PRAGMA table_info($table)')).map((c) => c['name'] as String).toSet();

  test('v16: may bagong tables at memories.use_count / last_used_at', () async {
    expect(await db.getVersion(), 16);
    expect(await columns(StorageConstants.searchLogTable),
        containsAll(['question', 'search_query', 'hit_count', 'top_key', 'sure', 'outcome', 'doc_key']));
    expect(await columns(StorageConstants.learnedTermsTable), containsAll(['term', 'alt', 'count']));
    expect(await columns(StorageConstants.searchFeedbackTable), containsAll(['doc_key', 'good', 'bad']));
    expect(await columns(StorageConstants.memoriesTable), containsAll(['use_count', 'last_used_at']));
  });

  test('search_log: add, update, pinakabago muna, filter ayon sa outcome', () async {
    final a = await repo.addLog(SearchLogEntry(
      question: 'ano plate ko?',
      query: 'ano plate ko?',
      hitCount: 0,
      outcome: SearchOutcome.none,
      at: now,
    ));
    final b = await repo.addLog(SearchLogEntry(
      question: 'ano wifi ko?',
      query: 'ano wifi ko?',
      hitCount: 2,
      topKey: 'note#1',
      sure: true,
      at: now,
    ));
    expect(a, isNotNull);
    await repo.updateLog(b!, SearchOutcome.confirmed, docKey: 'note#1');

    final all = await repo.recentLogs();
    expect(all.first.question, 'ano wifi ko?');
    expect(all.first.outcome, SearchOutcome.confirmed);
    expect(all.first.docKey, 'note#1');
    expect(all.first.sure, isTrue);
    final misses = await repo.recentLogs(outcome: SearchOutcome.none);
    expect(misses.single.question, 'ano plate ko?');
  });

  test('search_log: ang lampas 60 araw ay nabubura', () async {
    await repo.addLog(SearchLogEntry(
      question: 'luma',
      query: 'luma',
      hitCount: 0,
      at: now.subtract(const Duration(days: 61)),
    ));
    // Sa susunod na add tinatanggal ang luma.
    await repo.addLog(SearchLogEntry(question: 'bago', query: 'bago', hitCount: 0, at: now));
    final questions = (await repo.recentLogs(limit: 100)).map((e) => e.question);
    expect(questions, contains('bago'));
    expect(questions, isNot(contains('luma')));
  });

  test('learned_terms: kahit anong ayos ay iisang pares; bilang; burahin', () async {
    expect(await repo.learnPair('net', 'wifi'), 1);
    expect(await repo.learnPair('wifi', 'net'), 2);
    final terms = await repo.learnedTerms();
    expect(terms.single.term, 'net');
    expect(terms.single.alt, 'wifi');
    expect(terms.single.count, 2);
    expect(terms.single.active, isTrue);

    await repo.deleteLearned('wifi', 'net');
    expect(await repo.learnedTerms(), isEmpty);
  });

  test('search_feedback: naiipon ang good / bad', () async {
    await repo.addFeedback('note#1', good: 1);
    await repo.addFeedback('note#1', good: 1);
    await repo.addFeedback('note#1', bad: 1);
    await repo.addFeedback('task#3', bad: 1);
    final f = await repo.feedback();
    expect(f['note#1']!.good, 2);
    expect(f['note#1']!.bad, 1);
    expect(f['task#3']!.bad, 1);
  });

  test('memories: +1 use_count ayon sa id o content; hindi gumagalaw ang updated_at', () async {
    const t = '2026-11-01T08:00:00.000';
    final id = await db.insert(StorageConstants.memoriesTable, {
      'content': 'Allergic ako sa hipon',
      'created_at': t,
      'updated_at': t,
    });
    await repo.memoryUsed(id: id);
    await repo.memoryUsed(content: 'Allergic ako sa hipon');
    final row = (await db.query(StorageConstants.memoriesTable, where: 'id = ?', whereArgs: [id])).single;
    expect(row['use_count'], 2);
    expect(row['last_used_at'], isNotNull);
    expect(row['updated_at'], t);
  });

  test('RagLearning + SQLite: pumalya → rephrase ×2 → aktibo sa snapshot', () async {
    final l = RagLearning(repo, clock: () => now);
    final wifi = RetrievalHit(
      doc: RetrievalDoc(
        source: RetrievalSource.note,
        id: 1,
        title: 'Wifi',
        text: 'ZoeHome / pass 1234',
        updatedAt: now,
      ),
      score: 5,
      matched: 2,
      matchedInTitle: 1,
    );
    for (var i = 0; i < 2; i++) {
      await l.searched(question: 'ano pw ng net ko?', query: 'ano pw ng net ko?', hits: const []);
      await l.searched(
        question: 'ano wifi password ko?',
        query: 'ano wifi password ko?',
        hits: [wifi],
        isKnown: (_) async => false,
      );
    }
    final snap = await l.snapshot();
    expect(snap.synonyms['net'], ['wifi']);
  });

  test('clearAll: wala nang natutunan, 0 ang use_count', () async {
    await repo.clearAll();
    expect(await repo.recentLogs(), isEmpty);
    expect(await repo.learnedTerms(), isEmpty);
    expect(await repo.feedback(), isEmpty);
    final rows = await db.rawQuery(
        'SELECT SUM(use_count) AS n FROM ${StorageConstants.memoriesTable}');
    expect(rows.first['n'] ?? 0, 0);
  });
}