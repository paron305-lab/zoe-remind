import 'dart:math' as math;

import 'package:zoe_remind/database/repositories/search_repository.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/stemmer.dart';

/// RAG retrieval (deterministic): hinahanap sa notes + memories ang sagot.
///
///   1. QueryTerms  → mga salita sa tanong (walang "ano", "ko", "the"…)
///                    + ugat (R1: "bumili" → bili) + synonyms
///   2. SearchRepository → mga kandidato (FTS4, o LIKE kung walang FTS4)
///                    + bilang ng lahat ng notes at ng may bawat salita (R2)
///   3. [rank]      → score + kumpiyansa, pinakamataas muna
///
/// Walang AI dito. Ang sagot ni Zoe ay ang note / memory mismo + ang source.
///
/// R2 — ranking + kumpiyansa:
///   • Bigat ng salita = IDF: bihirang salita ("admin", "renta") > karaniwan
///     ("wifi" na nasa maraming note). Mahinang salita ("huling", "last",
///     "gusto"…) ay ×[weakWeight].
///   • Bawat salitang tumama: bigat × BM25 (dalas sa note, mas maikling note
///     ay bahagyang lamang). Synonym lang ang tumama → ×[synonymWeight].
///   • Dagdag: nasa title (notes), magkatabi ang dalawang salita ng tanong.
///   • Pinned / bago / importance ng memory = maliit na multiplier lang.
///   • coverage = bahagi ng bigat ng tanong na nasa doc (0–1):
///       ≥ [strongCoverage] → strong (diretsong sagot)
///       mas mababa          → maybe ("Baka ito? 🤔")
///       < [minCoverage]     → hindi isasama
///     Halos magkapantay ang #1 at #2 → maybe din.
///
/// Mga numero: galing sa R2 bench (test/rag/rag_bench_test.dart) —
/// tingnan ang claude/r2-ranking-handoff.md bago baguhin.
class Retriever {
  Retriever({SearchRepository? repo, DateTime Function()? clock})
      : _repo = repo ?? SearchRepository(),
        _clock = clock ?? DateTime.now;

  final SearchRepository _repo;
  final DateTime Function() _clock;

  /// coverage ≥ ito → sigurado.
  static const strongCoverage = 0.70;

  /// coverage < ito → hindi isasama.
  static const minCoverage = 0.20;

  /// Bigat kapag synonym lang ang tumama ("office" para sa "trabaho").
  static const synonymWeight = 0.8;

  /// Dagdag na × bigat kapag nasa title ng note.
  static const titleBoost = 0.35;

  /// BM25: k1 (dalas), b (haba ng note).
  static const k1 = 1.2;
  static const b = 0.4;

  /// Dagdag na × (mas maliit na bigat) kapag magkatabi (≤ 2 pagitan) ang
  /// dalawang magkasunod na salita ng tanong ("wifi password").
  static const nearBoost = 0.5;

  /// Bigat ng [weakWords].
  static const weakWeight = 0.35;

  /// #2 ≥ ito × #1 at parehong coverage → hindi sigurado ("Baka ito?").
  static const tieRatio = 0.9;

  /// Mga salitang hindi stopword pero halos walang sinasabi kung aling note
  /// ang hinahanap ("kailan ako HULING naglaba?", "how MANY eggs…").
  static const weakWords = {
    'huling', 'last', 'how', 'many', 'much', 'ilan', 'magkano', 'which', 'why', 'bakit',
    'paano', 'need', 'kailangan', 'dapat', 'should', 'will', 'gusto', 'want', 'like',
    'oras', 'time', 'lagi', 'always', 'usually', 'ever',
  };

  /// Top [limit] na sagot sa [question]. Walang laman = walang nahanap.
  /// [includeMemories] = false kapag OFF ang long-term memory.
  /// Ang una ang sagot; tingnan ang [RetrievalHit.confidence] kung sigurado.
  Future<List<RetrievalHit>> search(
    String question, {
    bool includeMemories = true,
    int limit = 3,
  }) async {
    final terms = QueryTerms.parse(question);
    if (terms.isEmpty) return const [];
    final docs = await _repo.candidates(terms, includeMemories: includeMemories);
    if (docs.isEmpty) return const [];
    CorpusStats? stats;
    try {
      stats = await _repo.corpusStats(terms, includeMemories: includeMemories);
    } catch (_) {
      stats = null;
    }
    // Kandidato lang ang hawak dito (hindi lahat ng notes) → kapag hindi alam
    // ang laki, tinatantiya sa [rank].
    return rank(terms, docs, now: _clock(), stats: stats ?? CorpusStats.unknown)
        .take(limit)
        .toList();
  }

  /// Pure scoring (walang database) — nate-test sa test/rag/retriever_test.dart
  /// at sa bench.
  ///
  /// [stats] = null → ang [docs] ang LAHAT ng notes / memories (test, bench).
  /// [CorpusStats.unknown] → kandidato lang ang [docs]; tinatantiya ang laki.
  ///
  /// Tinatanggal ang mahina: coverage < [minCoverage], o kulang ng 2+ salita
  /// kumpara sa pinakamagaling (kailangan ≥ pinakamarami − 1, gaya ng dati).
  static List<RetrievalHit> rank(
    List<TermGroup> terms,
    Iterable<RetrievalDoc> docs, {
    required DateTime now,
    CorpusStats? stats,
  }) {
    final list = docs.toList();
    if (terms.isEmpty || list.isEmpty) return [];

    final prepared = [for (final d in list) _Prepared(d)];
    // positions[doc][term] = mga posisyon sa doc na tumama ang salita.
    final positions = [
      for (final p in prepared) [for (final t in terms) p.positionsOf(t.alts)],
    ];

    // ── Bigat ng bawat salita (IDF)
    final df = [
      for (var i = 0; i < terms.length; i++) positions.where((pos) => pos[i].isNotEmpty).length,
    ];
    var n = list.length;
    if (stats != null) {
      if (stats.docFreq.length == terms.length) {
        for (var i = 0; i < df.length; i++) {
          df[i] = math.max(df[i], stats.docFreq[i]);
        }
      }
      final maxDf = df.reduce(math.max);
      n = stats.isUnknown ? math.max(n, 2 * maxDf) : math.max(n, stats.docCount);
    }
    n = math.max(n, df.reduce(math.max));
    final weights = [for (var i = 0; i < terms.length; i++) termWeight(terms[i], df[i], n)];
    final total = weights.fold<double>(0, (a, w) => a + w);
    if (total <= 0) return [];

    final avgLen = math.max(
      1.0,
      prepared.fold<int>(0, (a, p) => a + p.tokens.length) / prepared.length,
    );

    // ── Score bawat doc
    final scored = <_Scored>[];
    for (var di = 0; di < prepared.length; di++) {
      final p = prepared[di];
      final d = p.doc;
      final pos = positions[di];

      final quality = <double>[];
      for (var i = 0; i < terms.length; i++) {
        if (pos[i].isEmpty) {
          quality.add(0);
        } else if (p.positionsOf(terms[i].directAlts).isNotEmpty) {
          quality.add(1);
        } else {
          quality.add(synonymWeight);
        }
      }
      if (!quality.any((q) => q > 0)) continue;

      final lengthNorm = k1 * (1 - b + b * p.tokens.length / avgLen);
      var matchedWeight = 0.0;
      var score = 0.0;
      var matched = 0;
      var inTitle = 0;
      for (var i = 0; i < terms.length; i++) {
        if (quality[i] == 0) continue;
        matched++;
        matchedWeight += weights[i] * quality[i];
        final tf = pos[i].length;
        score += weights[i] * quality[i] * tf * (k1 + 1) / (tf + lengthNorm);
        if (!d.isMemory && pos[i].any((x) => x < p.titleLength)) {
          inTitle++;
          score += titleBoost * weights[i];
        }
      }

      // Magkatabi: "wifi password" na magkasunod din sa note.
      for (var i = 0; i + 1 < terms.length; i++) {
        if (quality[i] == 0 || quality[i + 1] == 0) continue;
        final next = pos[i + 1].toSet();
        if (pos[i].any((x) => next.contains(x + 1) || next.contains(x + 2))) {
          score += nearBoost * math.min(weights[i], weights[i + 1]);
        }
      }

      var boost = 1.0;
      if (d.pinned) boost += 0.1;
      boost += 0.05 * recencyBonus(d.updatedAt, now);
      if (d.isMemory) boost += 0.05 * math.max(-2, math.min(2, d.importance - 3));
      score *= boost;

      scored.add(_Scored(d, score, matched, inTitle, matchedWeight / total));
    }
    if (scored.isEmpty) return [];

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byTime = b.doc.updatedAt.compareTo(a.doc.updatedAt);
      if (byTime != 0) return byTime;
      return b.doc.id.compareTo(a.doc.id);
    });

    final bestMatched = scored.map((s) => s.matched).reduce(math.max);
    final kept = scored
        .where((s) => s.coverage >= minCoverage && s.matched >= bestMatched - 1)
        .toList();
    if (kept.isEmpty) return [];

    // ── Kumpiyansa
    final conf = [
      for (final s in kept)
        s.coverage >= strongCoverage ? RetrievalConfidence.strong : RetrievalConfidence.maybe,
    ];
    if (kept.length >= 2 && conf[0] == RetrievalConfidence.strong) {
      final a = kept[0];
      final b2 = kept[1];
      if (b2.coverage >= a.coverage - 0.01 && b2.score >= a.score * tieRatio) {
        conf[0] = RetrievalConfidence.maybe;
      }
    }

    return [
      for (var i = 0; i < kept.length; i++)
        RetrievalHit(
          doc: kept[i].doc,
          score: kept[i].score,
          matched: kept[i].matched,
          matchedInTitle: kept[i].inTitle,
          coverage: kept[i].coverage,
          confidence: conf[i],
        ),
    ];
  }

  /// IDF ng salita: bihira = mabigat. Wala sa kahit anong note (df 0) →
  /// parang nasa isa (para hindi sobrang bigat ang salitang wala sa notes).
  /// Mahinang salita ([weakWords]) → ×[weakWeight].
  static double termWeight(TermGroup t, int df, int n) {
    final d = math.max(df, 1);
    var w = math.log(1 + (n - d + 0.5) / (d + 0.5));
    final key = QueryTerms.fold(t.word);
    if (weakWords.contains(key) || weakWords.contains(Stemmer.stem(key))) w *= weakWeight;
    return w;
  }

  /// +2 sa huling 7 araw, +1 sa huling 30 araw, 0 kung mas luma.
  /// (R2: ×0.05 bilang multiplier ng score.)
  static int recencyBonus(DateTime updatedAt, DateTime now) {
    final days = now.difference(updatedAt).inDays;
    if (days <= 7) return 2;
    if (days <= 30) return 1;
    return 0;
  }
}

/// Mga salita ng isang doc (title + text) at ugat ng bawat isa — isang beses
/// lang kinukuwenta bawat tanong.
class _Prepared {
  _Prepared(this.doc) {
    final title = QueryTerms.tokens(doc.title);
    titleLength = title.length;
    tokens = [...title, ...QueryTerms.tokens(doc.text)];
    stems = [for (final t in tokens) Stemmer.stem(t)];
  }

  final RetrievalDoc doc;
  late final int titleLength;
  late final List<String> tokens;
  late final List<String> stems;

  /// Mga posisyon kung saan tumama ang kahit isang alt — sa salita o sa ugat
  /// nito. Parehong patakaran ng QueryTerms.groupIn / FTS4: 4+ letra = prefix,
  /// "=" = eksakto, may space = magkasunod na salita.
  List<int> positionsOf(Iterable<String> alts) {
    final parsed = [
      for (final a in alts)
        (QueryTerms.fold(QueryTerms.bare(a)).split(' '), a.startsWith('=')),
    ];
    final out = <int>[];
    for (var i = 0; i < tokens.length; i++) {
      for (final (parts, exact) in parsed) {
        if (_matchesAt(parts, exact, i)) {
          out.add(i);
          break;
        }
      }
    }
    return out;
  }

  bool _matchesAt(List<String> parts, bool exact, int i) {
    if (parts.length > 1) {
      if (i + parts.length > tokens.length) return false;
      for (var j = 0; j < parts.length; j++) {
        if (tokens[i + j] != parts[j]) return false;
      }
      return true;
    }
    final a = parts.first;
    if (a.isEmpty) return false;
    for (final t in [tokens[i], stems[i]]) {
      if (exact || a.length < QueryTerms.prefixMin) {
        if (t == a) return true;
      } else if (t.startsWith(a)) {
        return true;
      }
    }
    return false;
  }
}

class _Scored {
  _Scored(this.doc, this.score, this.matched, this.inTitle, this.coverage);
  final RetrievalDoc doc;
  final double score;
  final int matched;
  final int inTitle;
  final double coverage;
}