import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/stemmer.dart';

/// Bahagi ng [Snippet.text] na naka-**bold**: mula [start] hanggang bago ang
/// [end] (gaya ng `substring(start, end)`).
class SnippetSpan {
  const SnippetSpan(this.start, this.end);
  final int start;
  final int end;

  SnippetSpan shift(int by) => SnippetSpan(start + by, end + by);

  @override
  bool operator ==(Object other) =>
      other is SnippetSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '[$start, $end)';
}

/// R3 — ang bahagi lang ng note / memory na sumasagot sa tanong.
///
///   Tanong: "saan ang susi ng kotse?"
///   Note (mahaba):  "Bahay checklist\nIlaw sa garahe…\nSusi ng kotse: nasa
///                    drawer sa kusina\nPassword ng gate…"
///   Snippet:        "**Susi** ng **kotse**: nasa drawer sa kusina"  + "Buong note →"
///
/// Patakaran:
///   • Maikli ang note (≤ [maxChars]) → buong note, naka-bold ang tumama.
///   • Mahaba → hinahati sa linya (at sa pangungusap kung mahaba ang linya).
///     Pinipili ang 1–[maxLines] magkakasunod na linya (≤ [maxChars] lahat)
///     na may pinakamaraming salita ng tanong (−[linePenalty] bawat dagdag
///     na linya). Pantay → mas kaunting linya, tapos ang mas nauna.
///   • Isang pangungusap na sobrang haba → hinihiwa sa paligid ng unang
///     tumamang salita, sa pagitan ng mga salita, may "…".
///   • Walang tumama sa text (sa title lang) → simula ng note.
///   • "…" lang kapag hiniwa sa gitna ng linya; buong linya = walang "…".
///   • [partial] = may hindi ipinakita → "Buong note →" sa chat.
///
/// Parehong pagtutugma ng Retriever (R1/R2): salita o ugat nito, 4+ letra =
/// prefix, "=" = eksakto, may space = magkasunod na salita ("wi fi" → "Wi-Fi").
/// Kaya ang naka-bold ay ang mismong dahilan kung bakit lumabas ang note.
///
/// Pure Dart, walang database — nate-test sa test/rag/snippet_test.dart.
class Snippet {
  const Snippet({required this.text, this.bold = const [], this.partial = false});

  static const empty = Snippet(text: '');

  /// Pinakamahabang snippet (letra), hindi kasama ang "…".
  static const maxChars = 160;

  /// Hanggang ilang magkakasunod na linya.
  static const maxLines = 3;

  /// Bigat kapag synonym lang ang tumama (gaya ng Retriever.synonymWeight).
  static const synonymWeight = 0.8;

  /// Bawas sa score bawat dagdag na linya: ang dagdag na linya ay dapat may
  /// dalang salita ng tanong. ("Mga password sa bahay / Netflix… / Wi-Fi"
  /// ay talo sa "Wi-Fi: ZoeHome / pass: zoe2026".)
  static const linePenalty = 0.25;

  /// Ang ipapakita.
  final String text;

  /// Mga naka-bold sa [text], magkakasunod, walang patong.
  final List<SnippetSpan> bold;

  /// true = may bahagi ng note na hindi ipinakita.
  final bool partial;

  bool get isEmpty => text.isEmpty;

  /// Mga salitang naka-bold (para sa test / Developer).
  List<String> get boldWords => [for (final s in bold) text.substring(s.start, s.end)];

  /// Kapag isinama ang snippet sa mas mahabang linya ("Ito ang nakita ko…: "),
  /// [by] = kung saan ito nagsimula.
  Snippet shift(int by) => by == 0
      ? this
      : Snippet(text: text, bold: [for (final s in bold) s.shift(by)], partial: partial);

  /// Snippet ng [text] para sa [question] (dinadaan sa QueryTerms.parse).
  static Snippet of(String text, String question, {int max = maxChars}) =>
      build(text, QueryTerms.parse(question), max: max);

  /// Snippet ng [text] para sa mga salita ng tanong ([terms]).
  static Snippet build(String text, List<TermGroup> terms, {int max = maxChars}) {
    final clean = text.trim();
    if (clean.isEmpty) return empty;

    if (clean.length <= max) {
      final out = _tidy(clean);
      return Snippet(text: out, bold: boldIn(out, terms));
    }

    final tokens = _tokens(clean);
    final hits = _hits(tokens, terms);
    final segs = _segments(clean, max);
    if (segs.isEmpty) return empty;

    // ── Pinakamagandang 1–3 magkakasunod na linya
    //    score = bigat ng mga salitang tumama − [linePenalty] bawat dagdag na
    //    linya. Pantay → mas kaunting linya → mas nauna.
    var bestScore = 0.0;
    var bestFrom = -1;
    var bestTo = -1;
    for (var i = 0; i < segs.length; i++) {
      final groups = <int, double>{};
      for (var j = i; j < segs.length && j < i + maxLines; j++) {
        if (j > i && segs[j].end - segs[i].start > max) break;
        for (final h in hits) {
          final start = tokens[h.token].start;
          if (start < segs[j].start || start >= segs[j].end) continue;
          final had = groups[h.group] ?? 0;
          if (h.quality > had) groups[h.group] = h.quality;
        }
        final raw = groups.values.fold<double>(0, (a, q) => a + q);
        if (raw <= 0) continue;
        final score = raw - linePenalty * (j - i);
        final better = bestFrom < 0 ||
            score > bestScore + 1e-9 ||
            ((score - bestScore).abs() <= 1e-9 && j - i < bestTo - bestFrom);
        if (better) {
          bestScore = score;
          bestFrom = i;
          bestTo = j;
        }
      }
    }

    int from;
    int to;
    if (bestFrom < 0) {
      // Walang tumama sa text (title lang, o synonym na wala rito) → simula.
      from = segs.first.start;
      to = segs.first.end;
      for (var j = 1; j < segs.length && j < maxLines; j++) {
        if (segs[j].end - from > max) break;
        to = segs[j].end;
      }
    } else {
      from = segs[bestFrom].start;
      to = segs[bestTo].end;
    }

    // ── Isang pangungusap na sobrang haba → hiwain sa paligid ng tumama
    if (to - from > max) {
      final first = hits
          .map((h) => tokens[h.token].start)
          .where((s) => s >= from && s < to)
          .fold<int?>(null, (a, s) => a == null || s < a ? s : a);
      (from, to) = _cut(clean, from, to, first ?? from, max);
    }

    final body = _tidy(clean.substring(from, to));
    final before = _midLine(clean, from, back: true);
    // Tapos na ang pangungusap (. ! ?) → hindi na kailangan ng "…" sa dulo.
    final after = _midLine(clean, to, back: false) && !_endsSentence(body);
    final out = '${before ? '…' : ''}$body${after ? '…' : ''}';
    return Snippet(text: out, bold: boldIn(out, terms), partial: true);
  }

  /// Mga bahagi ng [text] na tumama sa [terms] (para sa bold).
  static List<SnippetSpan> boldIn(String text, List<TermGroup> terms) {
    if (terms.isEmpty || text.isEmpty) return const [];
    final tokens = _tokens(text);
    final spans = [
      for (final h in _hits(tokens, terms))
        SnippetSpan(tokens[h.token].start, tokens[h.token + h.length - 1].end),
    ]..sort((a, b) => a.start != b.start ? a.start - b.start : b.end - a.end);

    final merged = <SnippetSpan>[];
    for (final s in spans) {
      if (merged.isNotEmpty && s.start < merged.last.end) {
        final last = merged.removeLast();
        merged.add(SnippetSpan(last.start, s.end > last.end ? s.end : last.end));
      } else {
        merged.add(s);
      }
    }
    return merged;
  }

  // ───────────────────────── loob ─────────────────────────

  static final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  /// Mga salita + posisyon sa text. Kapareho ng hati ng QueryTerms.tokens
  /// (letra / numero lang), pero naaalala kung saan nakalagay.
  static List<_Token> _tokens(String text) => [
        for (final m in _word.allMatches(text))
          _Token(m.start, m.end, QueryTerms.fold(m[0]!)),
      ];

  /// Bawat (salita sa text, grupo ng tanong) na tumama.
  /// Isang hit bawat salita bawat grupo; ang salita mismo (direct) muna bago
  /// synonym.
  static List<_Hit> _hits(List<_Token> tokens, List<TermGroup> terms) {
    final out = <_Hit>[];
    for (var g = 0; g < terms.length; g++) {
      final direct = terms[g].directAlts.toList();
      final syn = terms[g].alts.skip(direct.length).toList();
      for (var k = 0; k < tokens.length; k++) {
        var n = _matchAny(tokens, k, direct);
        if (n > 0) {
          out.add(_Hit(k, n, g, 1));
          continue;
        }
        n = _matchAny(tokens, k, syn);
        if (n > 0) out.add(_Hit(k, n, g, synonymWeight));
      }
    }
    return out;
  }

  /// Ilang salita ang tumama simula sa [k] (0 = wala).
  static int _matchAny(List<_Token> tokens, int k, List<String> alts) {
    for (final alt in alts) {
      final n = _matchAt(tokens, k, alt);
      if (n > 0) return n;
    }
    return 0;
  }

  /// Parehong patakaran ng Retriever._Prepared._matchesAt.
  static int _matchAt(List<_Token> tokens, int k, String alt) {
    final exact = alt.startsWith('=');
    final parts = QueryTerms.fold(QueryTerms.bare(alt)).split(' ');
    if (parts.length > 1) {
      if (k + parts.length > tokens.length) return 0;
      for (var j = 0; j < parts.length; j++) {
        if (tokens[k + j].key != parts[j]) return 0;
      }
      return parts.length;
    }
    final a = parts.first;
    if (a.isEmpty) return 0;
    final t = tokens[k];
    for (final w in [t.key, t.stem]) {
      if (exact || a.length < QueryTerms.prefixMin) {
        if (w == a) return 1;
      } else if (w.startsWith(a)) {
        return 1;
      }
    }
    return 0;
  }

  /// Mga linya (walang laman = laktaw). Linyang mas mahaba sa [max] →
  /// hinahati sa pangungusap (. ! ? na may kasunod na space).
  static List<_Seg> _segments(String t, int max) {
    final out = <_Seg>[];
    var lineStart = 0;
    for (var i = 0; i <= t.length; i++) {
      if (i == t.length || t.codeUnitAt(i) == 10) {
        _addLine(t, lineStart, i, max, out);
        lineStart = i + 1;
      }
    }
    return out;
  }

  static void _addLine(String t, int s, int e, int max, List<_Seg> out) {
    while (s < e && _isSpace(t.codeUnitAt(s))) {
      s++;
    }
    while (e > s && _isSpace(t.codeUnitAt(e - 1))) {
      e--;
    }
    if (s >= e) return;
    if (e - s <= max) {
      out.add(_Seg(s, e));
      return;
    }
    var start = s;
    for (var i = s; i < e; i++) {
      final c = t.codeUnitAt(i);
      final isEnd = c == 46 || c == 33 || c == 63; // . ! ?
      if (isEnd && (i + 1 == e || _isSpace(t.codeUnitAt(i + 1)))) {
        out.add(_Seg(start, i + 1));
        start = i + 1;
        while (start < e && _isSpace(t.codeUnitAt(start))) {
          start++;
        }
      }
    }
    if (start < e) out.add(_Seg(start, e));
  }

  /// Hiwain ang [from]–[to] para ≤ [max] letra, kasama ang salitang nasa
  /// [focus], sa pagitan ng mga salita.
  static (int, int) _cut(String t, int from, int to, int focus, int max) {
    var s = focus - max ~/ 3;
    if (s <= from) {
      s = from;
    } else {
      // Huwag hiwain ang salita: lumipat sa simula ng susunod na salita.
      while (s < focus && _isWordChar(t.codeUnitAt(s - 1))) {
        s++;
      }
      while (s < focus && _isSpace(t.codeUnitAt(s))) {
        s++;
      }
    }
    var e = s + max;
    if (e >= to) {
      e = to;
    } else {
      // Bumalik sa huling space (pero huwag lampas sa kalahati).
      var k = e;
      while (k > s + max ~/ 2 && !_isSpace(t.codeUnitAt(k))) {
        k--;
      }
      if (k > s + max ~/ 2) e = k;
      while (e > s && _isSpace(t.codeUnitAt(e - 1))) {
        e--;
      }
    }
    return (s, e);
  }

  /// May text pa ba sa parehong linya bago ([back]) / pagkatapos ng [at]?
  static bool _midLine(String t, int at, {required bool back}) {
    if (back) {
      for (var i = at - 1; i >= 0; i--) {
        final c = t.codeUnitAt(i);
        if (c == 10) return false;
        if (!_isSpace(c)) return true;
      }
      return false;
    }
    for (var i = at; i < t.length; i++) {
      final c = t.codeUnitAt(i);
      if (c == 10) return false;
      if (!_isSpace(c)) return true;
    }
    return false;
  }

  static bool _endsSentence(String s) {
    if (s.isEmpty) return false;
    final c = s.codeUnitAt(s.length - 1);
    return c == 46 || c == 33 || c == 63; // . ! ?
  }

  /// Linya-linya, walang espasyo sa dulo, walang blangkong linya.
  static String _tidy(String s) => s
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .join('\n');

  /// Space, tab, \r, \n (hindi kasama ang ibang whitespace — sapat na sa notes).
  static bool _isSpace(int c) => c == 32 || c == 9 || c == 13 || c == 10;

  /// Letra / numero (ASCII + Latin na may tuldik). Para hindi mahiwa ang salita.
  static bool _isWordChar(int c) =>
      (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c >= 0xC0;
}

class _Token {
  _Token(this.start, this.end, this.key) : stem = Stemmer.stem(key);
  final int start;
  final int end;

  /// Maliit na titik, walang tuldik.
  final String key;

  /// Ugat (R1).
  final String stem;
}

class _Hit {
  const _Hit(this.token, this.length, this.group, this.quality);

  /// Index ng unang salita sa tokens.
  final int token;

  /// Ilang salita (higit sa 1 kapag phrase: "wi fi").
  final int length;

  /// Index ng TermGroup.
  final int group;

  /// 1 = salita mismo · [Snippet.synonymWeight] = synonym.
  final double quality;
}

class _Seg {
  const _Seg(this.start, this.end);
  final int start;
  final int end;
}