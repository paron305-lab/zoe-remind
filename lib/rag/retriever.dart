import 'dart:math' as math;

import 'package:zoe_remind/database/repositories/search_repository.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';

/// RAG retrieval (deterministic): hinahanap sa notes + memories ang sagot.
///
///   1. QueryTerms  → mga salita sa tanong (walang "ano", "ko", "the"…)
///                    + ugat (R1: "bumili" → bili)
///   2. SearchRepository → mga kandidato (FTS4, o LIKE kung walang FTS4)
///   3. [rank]      → score, pinakamataas muna
///
/// Walang AI dito. Ang sagot ni Zoe ay ang note / memory mismo + ang source.
///
/// Score (tingnan ang [rank]):
///   +10 bawat salitang tumama · +3 kung nasa title · +2 pinned
///   +2 kung na-edit sa huling 7 araw, +1 sa huling 30 araw
///   memory: + (importance − 3)
class Retriever {
  Retriever({SearchRepository? repo, DateTime Function()? clock})
      : _repo = repo ?? SearchRepository(),
        _clock = clock ?? DateTime.now;

  final SearchRepository _repo;
  final DateTime Function() _clock;

  /// Top [limit] na sagot sa [question]. Walang laman = walang nahanap.
  /// [includeMemories] = false kapag OFF ang long-term memory.
  Future<List<RetrievalHit>> search(
    String question, {
    bool includeMemories = true,
    int limit = 3,
  }) async {
    final terms = QueryTerms.parse(question);
    if (terms.isEmpty) return const [];
    final docs = await _repo.candidates(terms, includeMemories: includeMemories);
    return rank(terms, docs, now: _clock()).take(limit).toList();
  }

  /// Pure scoring (walang database) — nate-test sa test/rag/retriever_test.dart.
  ///
  /// Tinatanggal ang mahina: kapag ang pinakamagaling ay may 3 tumamang salita,
  /// hindi na isasama ang may 1 lang (kailangan ≥ pinakamarami − 1).
  static List<RetrievalHit> rank(
    List<TermGroup> terms,
    Iterable<RetrievalDoc> docs, {
    required DateTime now,
  }) {
    final hits = <RetrievalHit>[];
    for (final d in docs) {
      // R1: kasama ang ugat ng mga salita ("Binili" → bili, "batteries" → battery).
      final titleTokens = QueryTerms.searchTokens(d.title);
      final allTokens = [...titleTokens, ...QueryTerms.searchTokens(d.text)];
      var matched = 0;
      var inTitle = 0;
      for (final t in terms) {
        if (!QueryTerms.groupIn(t, allTokens)) continue;
        matched++;
        if (!d.isMemory && QueryTerms.groupIn(t, titleTokens)) inTitle++;
      }
      if (matched == 0) continue;

      var score = matched * 10 + inTitle * 3 + recencyBonus(d.updatedAt, now);
      if (d.pinned) score += 2;
      if (d.isMemory) score += math.max(-2, math.min(2, d.importance - 3));
      hits.add(RetrievalHit(doc: d, score: score, matched: matched, matchedInTitle: inTitle));
    }
    if (hits.isEmpty) return hits;

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byTime = b.doc.updatedAt.compareTo(a.doc.updatedAt);
      if (byTime != 0) return byTime;
      return b.doc.id.compareTo(a.doc.id);
    });

    final best = hits.map((h) => h.matched).reduce((a, b) => a > b ? a : b);
    return hits.where((h) => h.matched >= best - 1).toList();
  }

  /// +2 sa huling 7 araw, +1 sa huling 30 araw, 0 kung mas luma.
  static int recencyBonus(DateTime updatedAt, DateTime now) {
    final days = now.difference(updatedAt).inDays;
    if (days <= 7) return 2;
    if (days <= 30) return 1;
    return 0;
  }
}