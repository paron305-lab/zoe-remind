import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/ai/parser/intent_rules.dart';

/// Takbuhin:  flutter test test/ai/intent_rules_test.dart
/// Walang phone at walang model na kailangan — code lang ang tine-test.
void main() {
  void check(ZoeIntent want, List<String> messages) {
    for (final m in messages) {
      expect(IntentRules.match(m), want, reason: m);
    }
  }

  test('reminder', () {
    check(ZoeIntent.createReminder, [
      'gisingin mo ako bukas ng 5:30am',
      'sabihan mo ako mamayang 3pm na tawagan si mama',
      'Zoe, remind me tomorrow at 7 PM to review my thesis',
      'pa remind ako ng feb 12 2028 mga 9am kakain ako',
      'huwag mong kalimutang sabihan ako bukas 8am na uminom ng gamot',
      'wake me up at 6am',
      'meeting kay boss 3pm bukas',
      'may meeting ako 3pm bukas',
      'sunduin si mama alas 5 ng hapon',
      'tandaan mo, gisingin mo ako 6am',
      'do the laundry 5pm',
    ]);
  });

  test('task', () {
    check(ZoeIntent.createTask, [
      'kailangan kong magbayad ng kuryente sa Biyernes',
      'add task buy groceries on Saturday',
      'kailangan kong bumili ng gatas sa Sabado',
      'I need to finish my report on Friday',
      'I have to submit my timesheet by Monday',
      'dapat akong mag-gym bukas',
    ]);
  });

  test('note', () {
    check(ZoeIntent.createNote, [
      'tandaan mo, ang wifi password sa bahay ay zoe2026',
      'i-note mo: wifi password ng office ay zoe123',
      'tandaan mo na ang locker code ko ay 4521',
      'write this down: plate number ABC 123',
      'paki tandaan mo: plate number ko ay ABC 123',
      'keep this for me: my shoe size is 9',
    ]);
  });

  test('hanap sa notes', () {
    check(ZoeIntent.searchNotes, [
      'naaalala mo ba ang wifi password sa bahay?',
      'ano locker code ko?',
      "what's my wifi password?",
      'saan ko nilagay ang susi?',
      'nasaan na nga ang resibo ng laptop?',
      'do you remember the plate number I told you?',
      'natatandaan mo ba yung plate number ko?',
    ]);
  });

  test('schedule', () {
    check(ZoeIntent.getToday, [
      'busy ba ako bukas ng hapon?',
      'ano gagawin ko today?',
      'may lakad ba ako bukas?',
      "what's on my plate?",
      'may meeting ba ako bukas?',
      'am I free on Saturday?',
    ]);
  });

  test('natapos', () {
    check(ZoeIntent.getDone, [
      "anything I've already wrapped up this week?",
      'ano ginawa ko kahapon?',
      'what have I finished so far?',
      'may mga tapos na ba ako this week?',
    ]);
  });

  test('na-miss', () {
    check(ZoeIntent.getMissed, [
      'may nalampasan ba akong deadline?',
      'ano na-miss ko?',
      'may nakaligtaan ba ako?',
      'hindi ko nagawa yung labada',
    ]);
  });

  test('bati', () {
    check(ZoeIntent.greeting, [
      'uy Zoe, gising ka pa?',
      'hello',
      'good morning zoe',
      'kumusta ka na',
      'magandang gabi',
    ]);
  });

  // A2 (Nov 18): tanong tungkol sa sariling reminders / tasks → sagot, hindi bagong item.
  test('tanong tungkol sa reminders / tasks → schedule, hindi gagawa', () {
    check(ZoeIntent.getToday, [
      'ano mga reminders ko bukas?',
      'ano mga reminders ko?',
      'may alarm ba ako bukas?',
      'anong tasks ko today?',
      'ano mga tasks ko?',
      'what are my reminders for tomorrow?',
      'do I have any tasks today?',
      'ilan ang task ko bukas?',
      'anong oras ang alarm ko bukas?',
      'show my reminders',
    ]);
  });

  test('tanong tungkol sa na-miss / natapos na reminders / tasks', () {
    check(ZoeIntent.getMissed, [
      'may na-miss ba akong reminder?',
      'did i miss any reminders?',
      'anong tasks ang hindi ko nagawa?',
    ]);
    check(ZoeIntent.getDone, [
      'ano mga natapos kong tasks kahapon?',
      'what tasks have I completed?',
    ]);
  });

  test('utos pa rin kahit tanong ang anyo', () {
    check(ZoeIntent.createReminder, [
      'pwede mo ba akong i-remind bukas ng 8am?',
      'can you set a reminder for 5pm?',
      'pwede ka bang mag-set ng alarm bukas 6am?',
    ]);
    check(ZoeIntent.createTask, [
      'can you add a task to buy milk?',
    ]);
  });

  test('"na-miss kita" ay hindi listahan ng missed tasks', () {
    check(ZoeIntent.greeting, [
      'na-miss kita',
      'namiss kita zoe',
      'miss na kita',
      'I miss you Zoe',
      'did you miss me?',
    ]);
  });

  test('"i miss my mom" / "miss ko na si mama" ay hindi listahan ng na-miss', () {
    for (final m in ['i miss my mom', 'miss ko na si mama', 'miss ko na sila']) {
      expect(IntentRules.match(m), isNot(ZoeIntent.getMissed), reason: m);
    }
  });

  test('walang rule → ipapasa kay Qwen', () {
    check(ZoeIntent.unknown, [
      'sino ang presidente ng Pilipinas?',
      'what is the capital of France?',
      'ang ganda ng panahon',
      'may meeting ako bukas',
      'kailangan ko bang pumunta bukas?',
      "salamat sa'yo",
      'pagkatapos ng klase',
      'ang saya ko',
      'bakit bughaw ang langit?',
      'what time is it at 5pm?',
    ]);
  });

  test('tanong o pahayag', () {
    expect(IntentRules.isQuestion('busy ba ako bukas'), isTrue);
    expect(IntentRules.isQuestion('ano locker code ko'), isTrue);
    expect(IntentRules.isQuestion('meeting kay boss 3pm bukas'), isFalse);
    expect(IntentRules.isQuestion('do the laundry 5pm'), isFalse);
  });

  test('patayin ang alarm ay hindi bagong reminder', () {
    for (final m in [
      'Patayin mo ang alarm',
      'turn off the alarm',
      'i-off mo yung alarm ko',
      'alarm off',
    ]) {
      expect(IntentRules.isStopAlarm(m), isTrue, reason: m);
    }
    for (final m in ['set an alarm for 6am', 'mag-alarm ka ng 5am', 'stop reminding me']) {
      expect(IntentRules.isStopAlarm(m), isFalse, reason: m);
    }
  });

  test('nararamdaman', () {
    for (final m in ['Pagod na ako', "I'm so tired", 'nalulungkot ako ngayon', 'i feel sad']) {
      expect(IntentRules.isFeeling(m), isTrue, reason: m);
    }
    for (final m in ['ang ganda ng panahon', 'sad movie', 'sino ang presidente ng Pilipinas?']) {
      expect(IntentRules.isFeeling(m), isFalse, reason: m);
    }
  });

  test('nararamdaman — may "hindi / not" bago ang salita → hindi', () {
    for (final m in [
      'hindi ako pagod',
      'di naman ako stressed',
      "I'm not tired",
      'hindi naman ako malungkot',
    ]) {
      expect(IntentRules.isFeeling(m), isFalse, reason: m);
    }
    // May negation sa isa pero totoo ang isa pa → nararamdaman pa rin.
    expect(IntentRules.isFeeling('hindi ako galit, pagod lang ako'), isTrue);
  });

  // Phrase bank (Nov 22): sigurado vs hula. Hula → magtatanong muna ang chat.
  test('sigurado: malinaw na utos → card agad', () {
    for (final m in [
      'remind me tomorrow at 7 PM to review my thesis',
      'pls rmnd me 2mrw 8am to buy milk',
      'paremind nmn aq bkas 7am mag-gym',
      'gisingin mo ako bukas ng 5:30am',
      'set an alarm for 6am',
      'make a reminder mamaya to stretch',
      'paalala bukas 7am: inom gamot',
      'add task buy groceries on Saturday',
      'lagay mo sa tasks ko: magbayad ng kuryente',
      'pakilagay sa gawain ko na maglaba',
      'i-note mo: wifi password ng office ay zoe123',
    ]) {
      expect(IntentRules.matchFull(m).sure, isTrue, reason: m);
    }
  });

  test('hula: walang malinaw na utos → tanong muna', () {
    final cases = {
      'meeting kay boss 3pm bukas': ZoeIntent.createReminder,
      'sunduin si mama 6 ng gabi': ZoeIntent.createReminder,
      'kailangan kong magbayad ng kuryente sa Biyernes': ZoeIntent.createTask,
      'I need to finish my report on Friday': ZoeIntent.createTask,
      'reminder': ZoeIntent.createReminder,
      'alarm': ZoeIntent.createReminder,
      'alarm bukas': ZoeIntent.createReminder,
      'task': ZoeIntent.createTask,
    };
    cases.forEach((m, want) {
      final r = IntentRules.matchFull(m);
      expect(r.intent, want, reason: m);
      expect(r.sure, isFalse, reason: m);
    });
  });

  test('text-speak at pambungad ("uy zoe", "pls")', () {
    check(ZoeIntent.getToday, ['anu ganap ko 2day?', 'anu sched q bkas?', 'uy zoe ano gagawin ko today']);
    check(ZoeIntent.searchNotes, ['uy zoe ano nga ulit locker code ko', 'hey zoe, anu ung code ng locker ko?']);
    check(ZoeIntent.greeting, ['gm', 'gud am', 'hellooo', 'yo zoe']);
  });
}