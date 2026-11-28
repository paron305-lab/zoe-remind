import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/features/chat/controllers/chat_router.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/search_scope.dart';

/// Takbuhin:  flutter test test/rag/search_scope_test.dart
///
/// R4: saan hahanapin — lahat, o isang uri lang kapag binanggit
/// ("may reminder ba ako tungkol sa dentist?" → reminders, salita: dentist).
/// At ang ruta ng chat: tanong tungkol sa reminder / task NA MAY PAKSA →
/// search; walang paksa ("ano mga reminders ko bukas?") → schedule pa rin.
void main() {
  List<String> words(List<TermGroup> terms) => [for (final t in terms) t.word];

  group('SearchScope.of', () {
    test('"may reminder ba ako tungkol sa dentist?" → reminders lang, salita: dentist', () {
      final s = SearchScope.of('may reminder ba ako tungkol sa dentist?');
      expect(s.kinds, {RetrievalSource.reminder});
      expect(words(s.topic), ['dentist']); // "tungkol" = stopword (R4)
      expect(words(s.all), ['reminder', 'dentist']);
      expect(s.isScoped, isTrue);
    });

    test('"anong task ko sa sales report?" → tasks lang', () {
      final s = SearchScope.of('anong task ko sa sales report?');
      expect(s.kinds, {RetrievalSource.task});
      expect(words(s.topic), ['sales', 'report']);
    });

    test('"what tasks do I have for the cebu trip?" → "tasks" (plural) ay uri pa rin', () {
      final s = SearchScope.of('what tasks do I have for the cebu trip?');
      expect(s.kinds, {RetrievalSource.task});
      expect(words(s.topic), ['cebu', 'trip']);
    });

    test('paalala / alarm → reminder · gawain / to-do → task', () {
      expect(SearchScope.of('may paalala ba ako sa gamot?').kinds, {RetrievalSource.reminder});
      expect(SearchScope.of('may alarm ba ako para sa gamot?').kinds, {RetrievalSource.reminder});
      expect(SearchScope.of('anong gawain ko sa bahay?').kinds, {RetrievalSource.task});
      final todo = SearchScope.of('ano mga to-do ko para sa cebu?');
      expect(todo.kinds, {RetrievalSource.task});
      expect(words(todo.topic), ['cebu']);
    });

    test('"hanapin mo yung note ko about wifi" → notes lang', () {
      final s = SearchScope.of('hanapin mo yung note ko about wifi');
      expect(s.kinds, {RetrievalSource.note});
      expect(words(s.topic), ['wifi']);
      expect(s.isScoped, isTrue);
    });

    test('walang binanggit na uri → lahat', () {
      final s = SearchScope.of('kailan ang dentist appointment ko?');
      expect(s.kinds, isNull);
      expect(s.isScoped, isFalse);
      expect(words(s.topic), words(s.all));
    });

    test('"reminders?" lang → walang hahanapin sa loob ng uri (hindi scoped)', () {
      final s = SearchScope.of('reminders?');
      expect(s.kinds, {RetrievalSource.reminder});
      expect(s.topic, isEmpty);
      expect(s.isScoped, isFalse);
    });
  });

  group('SearchScope.asksAboutItem (para sa ChatRouter)', () {
    for (final q in [
      'may reminder ba ako tungkol sa dentist?',
      'anong task ko tungkol sa resume?',
      'may task ba akong maglinis ng kwarto?',
      'may reminder ba akong tawagan si mama?',
      'what tasks do I have for the cebu trip?',
      'do i have a reminder about the dentist?',
      'may alarm ba ako para sa gamot?',
    ]) {
      test('"$q" → true (may paksa)', () => expect(SearchScope.asksAboutItem(q), isTrue));
    }

    for (final q in [
      'ano mga reminders ko bukas?',
      'may alarm ba ako bukas?',
      'anong tasks ko today?',
      'ilan ang tasks ko?',
      'may reminder ba ako mamayang gabi?',
      'what reminders do i have this week?',
      'anong tasks ko sa sabado?',
      'may reminder ba ako sa 3pm?',
      'hey zoe, ano mga reminders ko? 🙏',
      'ano ang mga importanteng tasks ko?',
      'kailan ang dentist appointment ko?', // walang salitang reminder / task
      'hanapin mo yung note ko about wifi', // note, hindi reminder / task
    ]) {
      test('"$q" → false', () => expect(SearchScope.asksAboutItem(q), isFalse));
    }
  });

  group('ChatRouter (R4)', () {
    for (final q in [
      'may reminder ba ako tungkol sa dentist?',
      'may task ba akong maglinis ng kwarto?',
      'anong task ko sa sales report?',
      'do i have a reminder about the dentist?',
      'is there a task for my resume?',
      'may alarm ba ako para sa gamot?',
    ]) {
      test('"$q" → search', () {
        final r = ChatRouter.of(q);
        expect(r.route, ZoeRoute.search);
        expect(r.intent, ZoeIntent.searchNotes);
      });
    }

    // Galing sa phrase bank ('today') — hindi dapat lumipat.
    for (final q in [
      'what reminders do i have tomorrow?',
      'anong tasks ko today?',
      'ano mga paalala ko today?',
      'hey zoe, ano mga reminders ko? 🙏',
      'uy zoe may alarm ba ako bukas? nga',
      'hi zoe, ano mga gawain ko ngayong araw? po',
    ]) {
      test('"$q" → today pa rin', () => expect(ChatRouter.of(q).route, ZoeRoute.today));
    }

    test('hindi tanong ("show my reminders") → today pa rin', () {
      expect(ChatRouter.of('show my reminders').route, ZoeRoute.today);
    });
  });
}