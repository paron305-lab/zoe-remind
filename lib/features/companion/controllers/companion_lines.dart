import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/memory/companion_facts.dart';

/// Mga sitwasyon ng Level 3 Companion memory.
/// Ang pangalan ay ang key sa `assets/prompts/companion_lines.json`.
enum CompanionSituation {
  /// Bati kapag may nickname. {name}
  greet,

  /// Na-save ang nickname. {name} = ang bagong nickname.
  nickSaved,

  /// Na-save ang style. Ang bucket = ang BAGONG style.
  styleSaved,

  /// "Kapag stressed ka, ano'ng nakakatulong?" (isang beses lang).
  helpAsk,
  helpSavedListen,
  helpSavedAdvice,
  helpSavedLighten,

  /// "✖ Huwag na" sa tanong.
  helpSkip,

  /// Down ang user + makinig muna ang gusto niya.
  downListen,

  /// Down ang user + payo agad (isang maliit na tip).
  downAdvice,

  /// Down ang user + pampagaan (magaang biro).
  downLighten,
  winSaved,
  routineSaved,

  /// Ibang memory (general).
  factSaved,

  /// Paalala ng isang panalo kapag down. {win}
  winCheer,
}

/// Level 3 — ang boses ni Zoe na ayon sa user: nickname, diretso / malambing,
/// at kung ano'ng nakakatulong kapag stressed siya.
///
/// Galing ang mga linya sa `assets/prompts/companion_lines.json` (~5,500 linya,
/// EN / Tagalog / Taglish × default / diretso / malambing). Ginagawa ito ng
/// `python3 tool/companion/gen_companion_lines.py` — doon mag-edit, hindi sa JSON.
///
/// Mga patakaran:
///   • Walang nickname → hindi ginagamit ang mga linyang may {name}.
///   • Walang {win} → hindi ginagamit ang mga linyang may {win}.
///   • Walang linya sa style → default. Walang asset → maliit na fallback.
///   • Iniiwasan ang huling 8 nasabi (hindi paulit-ulit).
class CompanionLines {
  CompanionLines._();

  static const asset = 'assets/prompts/companion_lines.json';

  /// situation → language → style ('default' / 'diretso' / 'malambing') → lines
  static Map<CompanionSituation, Map<ZoeLanguage, Map<String, List<String>>>> _lines = {};
  static Future<void>? _loading;
  static final _recent = <String>[];
  static Random _random = Random();

  static bool get isLoaded => _lines.isNotEmpty;

  /// Ilang linya lahat (para sa Developer / test).
  static int get count => _lines.values
      .expand((byLang) => byLang.values)
      .expand((byStyle) => byStyle.values)
      .fold(0, (n, l) => n + l.length);

  /// I-load ang JSON (isang beses). Kapag pumalya → fallback lang, walang crash.
  static Future<void> ensureLoaded() {
    if (isLoaded) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      loadFromString(await rootBundle.loadString(asset));
    } catch (e) {
      debugPrint('CompanionLines: hindi ma-load ang $asset: $e');
    }
  }

  /// Para sa test (o kapag nabasa na ang file).
  static void loadFromString(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final lines = json['lines'] as Map<String, dynamic>;
    final out = <CompanionSituation, Map<ZoeLanguage, Map<String, List<String>>>>{};
    for (final s in CompanionSituation.values) {
      final byLang = lines[s.name] as Map<String, dynamic>?;
      if (byLang == null) continue;
      out[s] = {
        for (final lang in ZoeLanguage.values)
          if (byLang[lang.name] is Map<String, dynamic>)
            lang: {
              for (final e in (byLang[lang.name] as Map<String, dynamic>).entries)
                e.key: List<String>.unmodifiable((e.value as List).cast<String>()),
            },
      };
    }
    _lines = out;
    _recent.clear();
  }

  /// Para sa test: ulitin ang random.
  @visibleForTesting
  static void seed(int seed) => _random = Random(seed);

  /// Lahat ng linya ng isang bucket (hindi pa napapalitan ang {vars}).
  static List<String> optionsFor(ZoeLanguage lang, CompanionSituation s, [TalkStyle? style]) =>
      _lines[s]?[lang]?[style?.value ?? 'default'] ?? const [];

  /// Pumili ng linya. [name] = nickname (null = walang {name} na linya).
  /// [vars] = iba pa, hal. {'win': 'Nakapasa ako sa board exam'}.
  static String pick(
    ZoeLanguage lang,
    CompanionSituation s, {
    TalkStyle? style,
    String? name,
    Map<String, String> vars = const {},
  }) {
    final hasName = name != null && name.trim().isNotEmpty;
    bool usable(String line) =>
        (hasName || !line.contains('{name}')) && (vars.containsKey('win') || !line.contains('{win}'));

    var pool = optionsFor(lang, s, style).where(usable).toList();
    if (pool.isEmpty && style != null) pool = optionsFor(lang, s).where(usable).toList();
    if (pool.isEmpty) pool = [_fallback(lang, s)];

    final fresh = pool.where((l) => !_recent.contains(l)).toList();
    final from = fresh.isEmpty ? pool : fresh;
    final chosen = from[_random.nextInt(from.length)];
    _recent.add(chosen);
    if (_recent.length > 8) _recent.removeAt(0);

    var out = chosen;
    if (hasName) out = out.replaceAll('{name}', name.trim());
    for (final e in vars.entries) {
      out = out.replaceAll('{${e.key}}', e.value);
    }
    return out;
  }

  /// Linya kapag na-save ang stress help.
  static CompanionSituation savedFor(StressHelp help) => switch (help) {
        StressHelp.listen => CompanionSituation.helpSavedListen,
        StressHelp.advice => CompanionSituation.helpSavedAdvice,
        StressHelp.lighten => CompanionSituation.helpSavedLighten,
      };

  /// Sagot kapag down ang user, ayon sa gusto niya.
  static CompanionSituation downFor(StressHelp help) => switch (help) {
        StressHelp.listen => CompanionSituation.downListen,
        StressHelp.advice => CompanionSituation.downAdvice,
        StressHelp.lighten => CompanionSituation.downLighten,
      };

  /// Kapag walang asset (hal. sa unit test na walang JSON). Walang {name}.
  static String _fallback(ZoeLanguage lang, CompanionSituation s) {
    final en = lang == ZoeLanguage.english;
    return switch (s) {
      CompanionSituation.greet => en ? 'Hi! What can I help you with today?' : "Hi! Ano'ng maitutulong ko?",
      CompanionSituation.nickSaved => en ? "Got it, I'll call you that." : 'Sige, iyan na ang itatawag ko sa\'yo.',
      CompanionSituation.styleSaved => en ? "Okay, I'll adjust how I talk." : 'Sige, aayusin ko ang pananalita ko.',
      CompanionSituation.helpAsk =>
        en ? "When you're stressed, what helps you most?" : "Kapag stressed ka, ano'ng pinakanakakatulong?",
      CompanionSituation.helpSavedListen => en ? "I'll listen first." : 'Makikinig muna ako.',
      CompanionSituation.helpSavedAdvice => en ? "I'll give you a small tip." : 'Bibigyan kita ng maliit na tip.',
      CompanionSituation.helpSavedLighten => en ? "I'll try to make you smile." : 'Susubukan kitang pangitiin.',
      CompanionSituation.helpSkip => en ? "That's okay. I'm here." : 'Okay lang. Nandito lang ako.',
      CompanionSituation.downListen => en ? "I'm listening." : 'Nakikinig ako.',
      CompanionSituation.downAdvice =>
        en ? 'Pick one small task and do only that for 5 minutes.' : 'Pumili ng isang maliit na gawain at iyon lang muna nang 5 minuto.',
      CompanionSituation.downLighten =>
        en ? "You've survived every hard day so far. Perfect record." : 'Nakaraos ka na sa lahat ng mahirap na araw. Perfect record.',
      CompanionSituation.winSaved => en ? "Congrats! I'll remember this win." : 'Congrats! Tatandaan ko ang panalong ito.',
      CompanionSituation.routineSaved => en ? 'Got your routine.' : 'Noted ang routine mo.',
      CompanionSituation.factSaved => en ? "I'll remember that." : "Tatandaan ko 'yan.",
      CompanionSituation.winCheer => en ? "You've done hard things before." : 'Nakaya mo na dati, kaya mo ulit.',
    };
  }
}