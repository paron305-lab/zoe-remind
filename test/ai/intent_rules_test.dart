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
}