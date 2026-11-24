import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/ai/parser/small_talk.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/database/repositories/search_repository.dart';
import 'package:zoe_remind/features/chat/controllers/chat_preview_brain.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/companion/controllers/companion_lines.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';
import 'package:zoe_remind/memory/companion_facts.dart';
import 'package:zoe_remind/memory/companion_profile.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';

/// Takbuhin:  flutter test test/chat/companion_chat_test.dart
///
/// Level 3 sa Zoe Chat: nickname / style / stress help → memory card;
/// bati na may nickname; sagot ayon sa stress help; isang beses na tanong;
/// diretso = walang dagdag na linya; small talk ("kumusta ka?", "sino ka?"…).
/// Walang database, walang Qwen.

class _NoQwen extends IntentClassifier {
  @override
  Future<void> warmUp() async {}

  @override
  Future<ZoeLabel?> label(String text) async => null;
}

class _NoSearch extends SearchRepository {
  @override
  Future<List<RetrievalDoc>> candidates(List<TermGroup> terms, {bool includeMemories = true}) async =>
      const [];
}

void main() {
  final now = DateTime(2026, 11, 24, 10, 0);
  late List<UserTone> tones;
  late bool asked;
  late int askedMarks;

  setUpAll(() {
    CompanionLines.loadFromString(File(CompanionLines.asset).readAsStringSync());
  });

  ChatPreviewBrain brain({
    CompanionProfile profile = CompanionProfile.empty,
    bool memoryOn = true,
    bool helpAsked = false,
  }) {
    tones = [];
    asked = helpAsked;
    askedMarks = 0;
    return ChatPreviewBrain(
      retriever: Retriever(repo: _NoSearch()),
      memoryOn: () async => memoryOn,
      classifier: _NoQwen(),
      mood: () => MoodState.content,
      onMoodEvent: (_) {},
      onTone: tones.add,
      weekNote: (_) async => null,
      clock: () => now,
      activeAlarms: () async => const {},
      profile: () async => profile,
      helpAsked: () async => asked,
      markHelpAsked: () async {
        asked = true;
        askedMarks++;
      },
    );
  }

  /// Lahat ng posibleng linya (napalitan na ang {name}).
  Set<String> lines(ZoeLanguage lang, CompanionSituation s, {TalkStyle? style, String? name}) => {
        for (final l in CompanionLines.optionsFor(lang, s, style))
          if (name != null || !l.contains('{name}')) l.replaceAll('{name}', name ?? ''),
      };

  group('memory card (Level 3)', () {
    test('"call me AC" (English) → "Call me AC"', () async {
      final card = (await brain().reply('call me AC', ZoeLanguage.english)).single as ConfirmEntry;
      expect(card.kind, DraftKind.memory);
      expect(card.memory!.content, 'Call me AC');
    });

    test('"tawagin mo akong Pao" (Tagalog) → "Tawagin akong Pao"', () async {
      final card =
          (await brain().reply('tawagin mo akong Pao', ZoeLanguage.tagalog)).single as ConfirmEntry;
      expect(card.memory!.content, 'Tawagin akong Pao');
    });

    test('"diretsuhin mo lang ako" → style card', () async {
      final card =
          (await brain().reply('diretsuhin mo lang ako', ZoeLanguage.tagalog)).single as ConfirmEntry;
      expect(CompanionFacts.read(card.memory!.content),
          const FactRead(FactKind.style, 'diretso'));
    });

    test('"kapag stressed ako, makinig ka muna" → card, hindi binibilang na stressed', () async {
      final reply = await brain().reply('kapag stressed ako, makinig ka muna', ZoeLanguage.tagalog);
      final card = reply.single as ConfirmEntry;
      expect(CompanionFacts.read(card.memory!.content),
          const FactRead(FactKind.stressHelp, 'listen'));
      expect(tones, isEmpty);
    });

    test('"tandaan mo, nakapasa ako sa board exam" → win card', () async {
      final card = (await brain().reply('tandaan mo, nakapasa ako sa board exam', ZoeLanguage.tagalog))
          .single as ConfirmEntry;
      expect(CompanionFacts.read(card.memory!.content).kind, FactKind.win);
    });
  });

  group('bati na may nickname', () {
    test('"hi" + nickname AC → companion greet', () async {
      final reply = await brain(profile: const CompanionProfile(nickname: 'AC'))
          .reply('hi', ZoeLanguage.both);
      final text = (reply.single as TextEntry).text;
      expect(lines(ZoeLanguage.both, CompanionSituation.greet, name: 'AC'), contains(text));
    });

    test('"hi" na walang nickname → karaniwang bati', () async {
      final text = ((await brain().reply('hi', ZoeLanguage.english)).single as TextEntry).text;
      expect(ZoeLines.optionsFor(ZoeLanguage.english, ZoeSituation.greeting), contains(text));
    });
  });

  group('stressed + stress help', () {
    test('makinig muna → downListen (malambing)', () async {
      const profile = CompanionProfile(
          nickname: 'AC', style: TalkStyle.malambing, stressHelp: StressHelp.listen);
      final reply = await brain(profile: profile).reply('stressed na ako', ZoeLanguage.tagalog);
      final text = (reply.first as TextEntry).text;
      expect(
          lines(ZoeLanguage.tagalog, CompanionSituation.downListen,
              style: TalkStyle.malambing, name: 'AC'),
          contains(text));
      expect(reply.whereType<ClarifyEntry>(), isEmpty); // alam na, hindi na magtatanong
    });

    test('payo agad → downAdvice', () async {
      const profile = CompanionProfile(stressHelp: StressHelp.advice);
      final reply = await brain(profile: profile).reply("I'm so stressed", ZoeLanguage.english);
      expect(lines(ZoeLanguage.english, CompanionSituation.downAdvice),
          contains((reply.first as TextEntry).text));
    });

    test('may panalo → minsan ipinapaalala (unang down na sagot)', () async {
      const profile = CompanionProfile(
          stressHelp: StressHelp.lighten, wins: ['Nakapasa ako sa board exam']);
      final reply = await brain(profile: profile).reply('pagod na ako', ZoeLanguage.tagalog);
      expect(reply, hasLength(2));
      expect((reply.last as TextEntry).text, contains('Nakapasa ako sa board exam'));
    });
  });

  group('isang beses na tanong: "Kapag stressed ka, ano\'ng nakakatulong?"', () {
    test('wala pang stress help → tanong + 4 chips, minarkahan', () async {
      final b = brain();
      final reply = await b.reply('pagod na ako', ZoeLanguage.tagalog);
      final ask = reply.last as ClarifyEntry;
      expect(ask.asksHelp, isTrue);
      expect(ask.chips.map((c) => c.help), ['listen', 'advice', 'lighten', null]);
      expect(ask.chips.last.skip, isTrue);
      expect(ask.chips.every((c) => !c.isTime), isTrue);
      expect(askedMarks, 1);

      // Pangalawang beses → hindi na nagtatanong.
      final again = await b.reply('pagod pa rin ako', ZoeLanguage.tagalog);
      expect(again.whereType<ClarifyEntry>(), isEmpty);
      expect(askedMarks, 1);
    });

    test('naitanong na → walang tanong', () async {
      final reply = await brain(helpAsked: true).reply('stressed na ako', ZoeLanguage.both);
      expect(reply.whereType<ClarifyEntry>(), isEmpty);
    });

    test('OFF ang long-term memory → walang tanong', () async {
      final reply = await brain(memoryOn: false).reply('stressed na ako', ZoeLanguage.both);
      expect(reply.whereType<ClarifyEntry>(), isEmpty);
      expect(askedMarks, 0);
    });

    test('masaya → walang tanong', () async {
      final reply = await brain().reply('yay natapos ko lahat!', ZoeLanguage.both);
      expect(reply.whereType<ClarifyEntry>(), isEmpty);
    });
  });

  test('diretso + stressed + utos → card agad (walang "isa-isa lang tayo")', () async {
    const profile = CompanionProfile(style: TalkStyle.diretso);
    final reply = await brain(profile: profile)
        .reply('stressed na ako, remind me bukas ng 8am mag-review', ZoeLanguage.tagalog);
    expect(reply.single, isA<ConfirmEntry>());
  });

  group('small talk', () {
    final cases = {
      'kumusta ka?': CompanionSituation.talkHowAreYou,
      'ano ginagawa mo?': CompanionSituation.talkWhatDoing,
      'sino ka?': CompanionSituation.talkWhoAreYou,
      'tao ka ba?': CompanionSituation.talkAreYouAi,
      'good night zoe': CompanionSituation.talkGoodNight,
      'bye zoe': CompanionSituation.talkBye,
      'ang galing mo zoe': CompanionSituation.talkCompliment,
      'love you zoe': CompanionSituation.talkAffection,
      'bored ako': CompanionSituation.talkBored,
      'kumain ka na?': CompanionSituation.talkEaten,
      'tara chika': CompanionSituation.talkLetsChat,
      'wassup zoe, how u doin?': CompanionSituation.talkHowAreYou,
      'gtg bestie': CompanionSituation.talkBye,
      'slay zoe': CompanionSituation.talkCompliment,
    };
    cases.forEach((text, situation) {
      test('"$text" → ${situation.name}', () async {
        final reply = await brain().reply(text, ZoeLanguage.both);
        expect(lines(ZoeLanguage.both, situation), contains((reply.single as TextEntry).text));
        expect(tones, isEmpty); // hindi binibilang sa mood log
      });
    });

    test('"wassup zoe" → karaniwang bati', () async {
      final text = ((await brain().reply('wassup zoe', ZoeLanguage.english)).single as TextEntry).text;
      expect(ZoeLines.optionsFor(ZoeLanguage.english, ZoeSituation.greeting), contains(text));
    });

    test('"wassup" + nickname → bati na may AC', () async {
      final reply = await brain(profile: const CompanionProfile(nickname: 'AC'))
          .reply('wassup', ZoeLanguage.both);
      expect(lines(ZoeLanguage.both, CompanionSituation.greet, name: 'AC'),
          contains((reply.single as TextEntry).text));
    });

    test('"tao ka ba?" → laging AI ang sagot', () async {
      for (var i = 0; i < 20; i++) {
        final text = ((await brain().reply('tao ka ba?', ZoeLanguage.tagalog)).single as TextEntry).text;
        expect(text, contains('AI'));
      }
    });

    test('talkFor: bawat SmallTalk (maliban sa hello) ay may linya', () {
      for (final t in SmallTalk.values) {
        final s = CompanionLines.talkFor(t);
        if (t == SmallTalk.hello) {
          expect(s, isNull);
        } else {
          expect(CompanionLines.optionsFor(ZoeLanguage.both, s!), isNotEmpty);
        }
      }
    });
  });

  group('savedLine (pagkatapos ng Accept)', () {
    test('nickname → may bagong pangalan', () async {
      final line =
          await brain().savedLine(const FactRead(FactKind.nickname, 'AC'), ZoeLanguage.tagalog);
      expect(line, contains('AC'));
      expect(line, isNot(contains('{name}')));
    });

    test('style → linya ng bagong style', () async {
      final line =
          await brain().savedLine(const FactRead(FactKind.style, 'diretso'), ZoeLanguage.english);
      expect(lines(ZoeLanguage.english, CompanionSituation.styleSaved, style: TalkStyle.diretso),
          contains(line));
    });

    test('stress help → helpSaved', () async {
      final line = await brain()
          .savedLine(const FactRead(FactKind.stressHelp, 'lighten'), ZoeLanguage.both);
      expect(lines(ZoeLanguage.both, CompanionSituation.helpSavedLighten), contains(line));
    });
  });
}