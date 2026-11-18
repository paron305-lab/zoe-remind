import 'dart:math' as math;

import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';

/// Tone Detector — binabasa ang nararamdaman ng user sa English, Tagalog, at Taglish.
///
/// CODE lang (keywords), kaya mabilis at gumagana kahit walang model.
/// Sa P3, si Qwen ay pwedeng magbigay ng label kapag neutral ang lumabas dito.
///
/// Mga rules:
///  • Hindi ito para sa crisis. Laging nauuna ang CrisisGuard.
///  • "hindi ako pagod", "I'm not tired" → neutral (may negation check).
///  • "pagooood", "yesss" → binabasa bilang "pagod", "yes".
///  • Kapag halo ("haha pagod na ako") at pantay ang bilang, ang mabigat ang nananalo.
///  • Walang sine-save dito. Label lang ang lumalabas.
class ToneDetector {
  ToneDetector._();

  // ───────────────────────────── keywords ─────────────────────────────

  static final _patterns = <UserTone, List<RegExp>>{
    UserTone.tired: [
      RegExp(r'\b(pagod|napagod|napapagod|nakakapagod|antok|inaantok|antukin|puyat'
          r'|napuyat|hapo|lowbat|low batt|lantang gulay|tired|exhausted|sleepy|drained'
          r'|worn out|burned out|burnt out|burnout)\b'),
      RegExp(r"\b(walang tulog|wala akong tulog|kulang (sa )?tulog|no sleep"
          r"|didn'?t sleep|haven'?t slept)\b"),
      // Tinatamad / walang energy — mababa ang lakas, kaya kasama sa pagod.
      RegExp(r'\b(tinatamad|tamad|katamad|nakakatamad|tinamad|tamarin|lazy'
          r'|unmotivated|walang motivation|no motivation|no energy|walang energy'
          r'|walang lakas|procrastinating|nagpo-?procrastinate)\b'),
    ],
    UserTone.stressed: [
      RegExp(r'\b(stress|stressed|stressful|na-?stress|nai-?stress|overwhelmed'
          r'|pressured|haggard|sabaw|cramming|nagka-?cram|toxic)\b'),
      RegExp(r'\b(ang dami|ang daming|sobrang dami|napakaraming|tambak|too much'
          r'|so much to do)\b'),
      RegExp(r'\b(hindi|di) ko na (alam|kaya)\b'),
      RegExp(r'\b(hays|haist|haiz|hay nako|hay naku)\b'),
    ],
    UserTone.sad: [
      RegExp(r'\b(sad|malungkot|nalulungkot|lungkot|lonely|nag-?iisa|iyak|umiiyak'
          r'|naiiyak|napaiyak|crying|cried|heartbroken|depressed|walang gana'
          r'|homesick|disappointed|nadismaya|dismayado|nasaktan|sawi|namimiss)\b'),
      RegExp(r'\b(feeling|feel|felt) down\b'),
    ],
    UserTone.upset: [
      RegExp(r'\b(inis|naiinis|nakakainis|kainis|kakainis|badtrip|bad trip|bwisit'
          r'|buwisit|bwiset|galit|nagagalit|asar|naaasar|nakakaasar|annoyed|annoying'
          r'|angry|mad|frustrated|frustrating|pissed|irritated|ugh|hassle)\b'),
    ],
    UserTone.worried: [
      RegExp(r'\b(kinakabahan|kabado|kaba|nervous|anxious|anxiety|worried|worry'
          r'|nag-?aalala|nababahala|takot|natatakot|scared|afraid|praning'
          r'|overthink|overthinking|nago-?overthink|paano kung)\b'),
    ],
    UserTone.happy: [
      RegExp(r'\b(yay|yey|woohoo|happy|masaya|saya|excited|na-?eexcite|ang galing'
          r'|great|awesome|amazing|nice|sarap|solid|finally|sa wakas|natapos ko'
          r'|nagawa ko|i did it|proud|blessed|lol)\b'),
      RegExp(r'\b(ha){2,}h?\b'), // haha, hahaha, hahah
      RegExp(r'\b(he){2,}h?\b'), // hehe, heheh
      RegExp(r'\byes!'), // "yes!" — ang "yes" lang ay sagot sa confirm, hindi saya
    ],
  };

  static const _emojis = <UserTone, List<String>>{
    UserTone.happy: ['😊', '😄', '😁', '😆', '🥳', '🎉', '😍', '🙌'],
    UserTone.sad: ['😢', '😭', '😞', '😔', '💔', '🥺'],
    UserTone.upset: ['😡', '😠', '😤', '🙄'],
    UserTone.tired: ['😴', '🥱', '😩'],
    UserTone.worried: ['😰', '😟', '😥', '😬'],
    UserTone.stressed: ['😫', '🤯'],
  };

  /// Kapag pantay ang bilang: mas mabigat ang nauuna.
  static const _tieOrder = [
    UserTone.sad,
    UserTone.worried,
    UserTone.stressed,
    UserTone.upset,
    UserTone.tired,
    UserTone.happy,
  ];

  /// "hindi ako pagod", "di naman ako stressed", "I'm not tired", "don't feel sad".
  /// Tinitingnan ang text BAGO ang salitang tumama.
  static final _negationBefore = RegExp(
    r"(^|\s)(hindi|hinde|di|'di|not|never|no|don'?t|isn'?t|wasn'?t|ain'?t)\s+"
    r"((naman|na|ako|ko|i|am|im|i'm|really|so|very|masyado|gaano|feel|feeling)\s+){0,3}$",
  );

  /// Pampalakas: "sobrang pagod", "grabe", "so tired", "!!".
  static final _booster = RegExp(
    r'\b(sobra|sobrang|grabe|super|so|very|really|talaga|napaka|too)\b',
  );

  static final _repeated = RegExp(r'(\w)\1{2,}');

  // ───────────────────────────── public ─────────────────────────────

  /// Lowercase, isang space lang, at "pagooood" → "pagod".
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(_repeated, (m) => m[1]!)
      .trim();

  /// Basahin ang tono ng [text].
  static ToneResult detect(String text) {
    final t = normalize(text);
    if (t.isEmpty) return ToneResult.neutral;

    final scores = <UserTone, int>{};
    final hits = <UserTone, List<String>>{};

    void add(UserTone tone, String word) {
      scores[tone] = (scores[tone] ?? 0) + 1;
      (hits[tone] ??= []).add(word);
    }

    _patterns.forEach((tone, regexes) {
      for (final re in regexes) {
        for (final m in re.allMatches(t)) {
          if (_negationBefore.hasMatch(t.substring(0, m.start))) continue;
          add(tone, m[0]!);
        }
      }
    });

    _emojis.forEach((tone, list) {
      for (final e in list) {
        if (t.contains(e)) add(tone, e);
      }
    });

    if (scores.isEmpty) return ToneResult.neutral;

    var best = _tieOrder.firstWhere(scores.containsKey);
    for (final tone in _tieOrder) {
      if ((scores[tone] ?? 0) > scores[best]!) best = tone;
    }

    var strength = math.min(3, scores[best]!);
    if (_booster.hasMatch(t) || t.contains('!!')) strength = math.min(3, strength + 1);

    return ToneResult(best, strength, List.unmodifiable(hits[best]!));
  }

  /// Ano ang epekto sa mood ni Zoe (MoodEngine)?
  /// Down → gentle si Zoe. Happy → happy si Zoe. Neutral → wala.
  static ZoeEvent? toMoodEvent(UserTone tone) {
    if (tone == UserTone.happy) return const UserPositive();
    if (tone.isDown) return const UserFeelsDown();
    return null;
  }
}