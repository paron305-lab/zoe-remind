import 'package:flutter/foundation.dart';
import 'package:zoe_remind/rag/query_terms.dart';

/// Isang tanong sa chat na WALANG nahanap sa notes / memories.
class SearchMiss {
  const SearchMiss({required this.question, required this.terms, required this.at});

  /// Ang tanong (na-normalize na, maliit na titik).
  final String question;

  /// Ang mga salitang hinanap ("internet(wifi|wi fi…), password").
  final String terms;
  final DateTime at;
}

/// Listahan ng mga tanong na hindi nahanap (B6) — para malaman kung kulang
/// ang synonyms (`QueryTerms._synonyms`) o kung kailangan na ng embeddings.
///
/// Sa RAM lang, sa session na ito lang: HINDI sine-save sa database, at
/// nawawala pagsara ng app. Makikita sa Developer › 8. Search index.
class SearchMisses {
  SearchMisses._();

  /// Hanggang ilan ang itatabi (pinakaluma ang natatanggal).
  static const max = 20;

  /// Nagbabago tuwing may bagong miss o nag-Clear (para sa Developer card).
  static final changes = ValueNotifier<int>(0);

  static final List<SearchMiss> _items = [];

  /// Pinakabago muna.
  static List<SearchMiss> get items => List.unmodifiable(_items.reversed);

  static void record(String question, {DateTime? at}) {
    final q = question.trim();
    if (q.isEmpty) return;
    _items.removeWhere((m) => m.question == q); // walang ulit
    _items.add(SearchMiss(
      question: q,
      terms: QueryTerms.parse(q).join(', '),
      at: at ?? DateTime.now(),
    ));
    if (_items.length > max) _items.removeAt(0);
    changes.value++;
  }

  static void clear() {
    _items.clear();
    changes.value++;
  }
}