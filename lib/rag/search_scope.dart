import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/stemmer.dart';

/// R4 — saan hahanapin ang sagot: lahat (notes, memories, reminders, tasks),
/// o isang uri lang kapag sinabi ng user.
///
///   "may reminder ba ako tungkol sa dentist?"  → reminders lang, salita: dentist
///   "anong task ko sa sales report?"           → tasks lang, salita: sales, report
///   "hanapin mo yung note ko about wifi"       → notes lang, salita: wifi
///   "dentist?"                                 → lahat
///
/// Ang salitang uri ("reminder", "task", "paalala", "gawain"…) ay hindi
/// hinahanap sa loob ng mga item — tinatanggal sa [topic]. Kapag walang
/// nahanap sa uring iyon, lahat ang hahanapin gamit ang [all] (kasama ang
/// salitang uri), kaya ang "anong reminders gusto ko?" ay tatama pa rin sa
/// memory na "Mas gusto ko ng morning reminders".
///
/// Pure (walang database) — nate-test sa test/rag/search_scope_test.dart.
class SearchScope {
  const SearchScope._(this.all, this.topic, this.kinds);

  /// Lahat ng salita ng tanong (QueryTerms.parse), kasama ang salitang uri.
  final List<TermGroup> all;

  /// [all] na walang salitang uri.
  final List<TermGroup> topic;

  /// Ang mga uring binanggit. null = walang binanggit (lahat).
  final Set<RetrievalSource>? kinds;

  /// May binanggit na uri AT may hahanapin pa ("reminder sa basura").
  /// "reminders?" lang → false (lahat ang hahanapin).
  bool get isScoped => kinds != null && topic.isNotEmpty;

  /// Salita → uri. Maliit na titik, walang tuldik.
  /// ("note" / "notes" ay stopword din sa QueryTerms, kaya wala sa [all].)
  static const kindWords = <String, RetrievalSource>{
    'reminder': RetrievalSource.reminder,
    'reminders': RetrievalSource.reminder,
    'paalala': RetrievalSource.reminder,
    'alarm': RetrievalSource.reminder,
    'alarms': RetrievalSource.reminder,
    'alarma': RetrievalSource.reminder,
    'task': RetrievalSource.task,
    'tasks': RetrievalSource.task,
    'todo': RetrievalSource.task,
    'todos': RetrievalSource.task,
    'gawain': RetrievalSource.task,
    'note': RetrievalSource.note,
    'notes': RetrievalSource.note,
  };

  /// "to-do", "to do" → task.
  static final _toDo = RegExp(r'\bto-?dos?\b');

  static final _digit = RegExp(r'\d');

  /// Mga salita tungkol sa ORAS / LISTAHAN, hindi sa laman. Para sa
  /// [asksAboutItem]: "ano mga reminders ko bukas?" ay schedule pa rin,
  /// hindi paghahanap. (Kasama ang pambungad na "hey", "uy", "beh"…)
  static const scheduleWords = {
    'today', 'tomorrow', 'tonight', 'later', 'now', 'ngayon', 'ngayong', 'bukas', 'mamaya',
    'mamayang', 'kahapon', 'yesterday',
    'lunes', 'martes', 'miyerkules', 'huwebes', 'biyernes', 'sabado', 'linggo',
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
    'umaga', 'tanghali', 'hapon', 'gabi', 'morning', 'afternoon', 'evening', 'night',
    'week', 'weekend', 'month', 'year', 'buwan', 'taon', 'araw', 'day', 'days',
    'next', 'susunod', 'this', 'coming', 'upcoming', 'sched', 'schedule', 'iskedyul', 'agenda',
    'plano', 'plan', 'plans', 'lahat', 'all', 'list', 'listahan', 'ilan', 'many', 'much', 'how',
    'any', 'anything', 'some', 'pending', 'natitira', 'remaining', 'left',
    'gagawin', 'gawin', 'need', 'kailangan', 'dapat', 'should', 'will', 'first', 'una',
    'set', 'nakaset', 'nakatakda', 'scheduled', 'planned', 'due',
    'important', 'importante', 'importanteng', 'urgent',
    'hey', 'hi', 'hello', 'uy', 'oy', 'yo', 'beh', 'sige', 'ok', 'okay', 'hoy', 'teka',
    'bes', 'besh', 'sis', 'bro', 'pre', 'tol', 'pls',
  };

  /// [learned] (R6) = natutunang salita ni Zoe (tingnan ang QueryTerms.parse).
  factory SearchScope.of(String question, {Map<String, List<String>> learned = const {}}) {
    final all = QueryTerms.parse(question, learned: learned);
    final kinds = <RetrievalSource>{};
    for (final w in QueryTerms.rawTokens(question)) {
      final k = kindWords[QueryTerms.fold(w)];
      if (k != null) kinds.add(k);
    }
    if (_toDo.hasMatch(question.toLowerCase())) kinds.add(RetrievalSource.task);
    return SearchScope._(
      all,
      [for (final t in all) if (!_isKind(t)) t],
      kinds.isEmpty ? null : Set.unmodifiable(kinds),
    );
  }

  static bool _isKind(TermGroup t) {
    final key = QueryTerms.fold(t.word);
    return kindWords.containsKey(key) || kindWords.containsKey(Stemmer.stem(key));
  }

  /// Para sa ChatRouter: tanong tungkol sa reminder / task NA MAY PAKSA?
  ///   "may reminder ba ako tungkol sa dentist?" → true  (hahanapin)
  ///   "may task ba akong maglinis ng kwarto?"  → true
  ///   "ano mga reminders ko bukas?"            → false (schedule)
  ///   "may alarm ba ako mamayang gabi?"        → false
  ///   "ilan ang tasks ko?"                     → false
  /// Hindi tinitingnan dito kung tanong ba — nasa ChatRouter iyon.
  static bool asksAboutItem(String lower) {
    final s = SearchScope.of(lower);
    final kinds = s.kinds;
    if (kinds == null ||
        !(kinds.contains(RetrievalSource.reminder) || kinds.contains(RetrievalSource.task))) {
      return false;
    }
    for (final t in s.topic) {
      final key = QueryTerms.fold(t.word);
      if (scheduleWords.contains(key) || scheduleWords.contains(Stemmer.stem(key))) continue;
      if (_digit.hasMatch(key)) continue; // "3pm", "15"
      return true;
    }
    return false;
  }

  @override
  String toString() => 'SearchScope(kinds: ${kinds?.map((k) => k.name).join('+') ?? 'lahat'}, '
      'topic: ${topic.join(', ')})';
}