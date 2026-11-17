import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/crisis_guard.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/ai/parser/intent_rules.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';

/// Takbuhin:  flutter test test/safety/crisis_guard_test.dart
void main() {
  const crisis = [
    'gusto ko na mamatay',
    'gusto ko nang mamatay',
    'Ayoko na mabuhay',
    'ayaw ko nang mabuhay',
    'magpapakamatay na ako',
    'iniisip ko magpakamatay',
    'sana mamatay na lang ako',
    'sana patay na ako',
    'tatapusin ko na ang buhay ko',
    'gusto kong tapusin ang buhay ko',
    'sasaktan ko ang sarili ko',
    'gusto kong saktan ang sarili ko',
    'wala nang saysay ang buhay ko',
    'wala na kwenta mabuhay',
    'maglalaslas ako',
    'I want to kill myself',
    'i wanna die',
    'I want to die',
    'thinking about suicide',
    'I feel suicidal',
    'i keep hurting myself',
    'I want to end my life',
    "I don't want to live anymore",
    'i wish i was dead',
    'everyone is better off without me',
    "there's no point in living",
    'remind me to kill myself tomorrow',
    'gusto ko   na   mamatay',
    'Paano mamatay',
    'gusto kong mamatay',
    'gusto ko mamatay',
    'mamatay na lang ako',
    'how to die',
    'what are ways to die',
  ];

  const notCrisis = [
    'patayin mo ang alarm',
    'remind me to kill the mosquitoes',
    'pagod na ako',
    'ang hirap ng buhay',
    'namatay ang phone ko',
    'patay ang ilaw sa kwarto',
    'kailangan kong magbayad ng kuryente sa Biyernes',
    'gisingin mo ako bukas ng 5:30am',
    "I'm dying to see that movie",
    'deadline ko bukas',
    'tapusin ko na ang report',
    'saktan mo ako sa laro mamaya',
    'cut the cake at 5pm',
    'buhay pa ba ang halaman ko?',
    'ayoko na mag-aral',
    'gusto ko na matulog',
    'hello',
    '89+9',
    'end my subscription',
    'take my medicine at 8am',
    'mamamatay na ako sa gutom',
    'how to dye my hair',
    'paano magluto ng adobo',
  ];

  test('nahuhuli ang mga mensaheng tungkol sa pananakit sa sarili', () {
    for (final m in crisis) {
      expect(CrisisGuard.matches(m), isTrue, reason: m);
    }
  });

  test('hindi nahuhuli ang ordinaryong mensahe', () {
    for (final m in notCrisis) {
      expect(CrisisGuard.matches(m), isFalse, reason: m);
    }
  });

  test('kahit may salitang pang-reminder, crisis pa rin ang panalo', () {
    const m = 'remind me to kill myself tomorrow';
    expect(IntentRules.match(m), ZoeIntent.createReminder); // may tatamang rule…
    expect(CrisisGuard.matches(m), isTrue); // …pero crisis ang unang chine-check
  });

  test('may hotline ang sagot sa lahat ng language, walang naiwang {placeholder}', () {
    for (final lang in ZoeLanguage.values) {
      final line = ZoeLines.pick(lang, ZoeSituation.crisis, CrisisGuard.lineVars);
      expect(line, contains(CrisisGuard.landline), reason: lang.name);
      expect(line, contains(CrisisGuard.globe), reason: lang.name);
      expect(line, contains(CrisisGuard.smart), reason: lang.name);
      expect(line, contains(CrisisGuard.emergency), reason: lang.name);
      expect(line.contains('{'), isFalse, reason: lang.name);
    }
  });
}