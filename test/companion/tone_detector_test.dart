import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/features/companion/controllers/tone_detector.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';

/// Takbuhin:  flutter test test/companion/tone_detector_test.dart
void main() {
  UserTone tone(String text) => ToneDetector.detect(text).tone;

  void expectTone(UserTone expected, List<String> texts) {
    for (final t in texts) {
      expect(tone(t), expected, reason: '"$t"');
    }
  }

  group('Nababasa ang tono sa English, Tagalog, at Taglish', () {
    test('pagod', () {
      expectTone(UserTone.tired, [
        'pagod na ako',
        "I'm so tired",
        'drained ako today',
        'inaantok na ako',
        'walang tulog ako kagabi',
        'puyat ako',
      ]);
    });

    test('stressed', () {
      expectTone(UserTone.stressed, [
        'ang dami ko pang gagawin',
        "I'm so stressed",
        'overwhelmed na ako sa work',
        'na-stress ako sa thesis',
        'hays',
        'di ko na alam gagawin ko',
      ]);
    });

    test('malungkot', () {
      expectTone(UserTone.sad, [
        'nalulungkot ako',
        'I feel sad',
        'sad ako today',
        'umiiyak ako',
        'feeling down lately',
        'walang gana ako',
      ]);
    });

    test('inis', () {
      expectTone(UserTone.upset, [
        'nakakainis talaga',
        'badtrip ako',
        "I'm so annoyed",
        'frustrated na ako sa project',
      ]);
    });

    test('kinakabahan', () {
      expectTone(UserTone.worried, [
        'kinakabahan ako sa exam bukas',
        "I'm nervous",
        'nag-aalala ako',
        'overthinking na naman',
      ]);
    });

    test('masaya', () {
      expectTone(UserTone.happy, [
        'natapos ko na lahat!!',
        'hahaha',
        'yay!',
        'ang saya ko today',
        'yes! nagawa ko',
        'I did it',
      ]);
    });

    test('emoji', () {
      expect(tone('😭'), UserTone.sad);
      expect(tone('😴'), UserTone.tired);
      expect(tone('🎉'), UserTone.happy);
    });
  });

  group('Walang maling basa', () {
    test('negation → neutral', () {
      expectTone(UserTone.neutral, [
        'hindi ako pagod',
        "I'm not tired",
        'di naman ako stressed',
        "don't feel sad",
        "don't worry",
      ]);
    });

    test('mga salitang mukhang feeling pero hindi', () {
      expectTone(UserTone.neutral, [
        'galing ako sa office', // "galing" = from, hindi "ang galing"
        'yes', // sagot sa confirm card
        'slow down',
        'remind me to buy milk at 5pm',
        'ano meron today',
        '',
        '   ',
      ]);
    });

    test('"pagooood", "hahahah" ay nababasa pa rin', () {
      expect(tone('pagoooood na ako'), UserTone.tired);
      expect(tone('hahahah'), UserTone.happy);
      expect(ToneDetector.normalize('Pagoooood   NA ako'), 'pagod na ako');
    });
  });

  group('Halo-halo at lakas', () {
    test('pantay ang bilang → ang mabigat ang nananalo', () {
      expect(tone('haha pagod na ako'), UserTone.tired);
    });

    test('mas marami ang masaya → masaya', () {
      expect(tone('pagod pero ang saya, natapos ko na!'), UserTone.happy);
    });

    test('negation sa isang bahagi lang', () {
      // "hindi na ako masaya" ay hindi binibilang na masaya
      expect(tone('ang pagod ko, hindi na ako masaya'), UserTone.tired);
    });

    test('strength 1 → 3', () {
      expect(ToneDetector.detect('pagod').strength, 1);
      expect(ToneDetector.detect('sobrang pagod').strength, 2);
      expect(ToneDetector.detect('sobrang pagod, puyat, walang tulog').strength, 3);
      expect(ToneDetector.detect('ano meron today').strength, 0);
    });
  });

  group('Koneksyon sa Mood Engine at Zoe Lines', () {
    test('down → UserFeelsDown; happy → UserPositive; neutral → wala', () {
      expect(ToneDetector.toMoodEvent(UserTone.tired), isA<UserFeelsDown>());
      expect(ToneDetector.toMoodEvent(UserTone.sad), isA<UserFeelsDown>());
      expect(ToneDetector.toMoodEvent(UserTone.happy), isA<UserPositive>());
      expect(ToneDetector.toMoodEvent(UserTone.neutral), isNull);
    });

    test('bawat tono (maliban sa neutral) ay may script sa tatlong language', () {
      expect(ZoeLines.situationForTone(UserTone.neutral), isNull);
      for (final t in UserTone.values.where((t) => t != UserTone.neutral)) {
        final situation = ZoeLines.situationForTone(t);
        expect(situation, isNotNull, reason: '$t');
        for (final lang in ZoeLanguage.values) {
          expect(ZoeLines.pick(lang, situation!).trim(), isNotEmpty, reason: '$t / $lang');
        }
      }
    });
  });
}