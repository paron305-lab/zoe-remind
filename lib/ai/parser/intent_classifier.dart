import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zoe_remind/ai/inference/qwen_engine.dart';
import 'package:zoe_remind/ai/parser/zoe_label.dart';

export 'package:zoe_remind/ai/parser/zoe_label.dart';

/// Ano ang gusto ng user. Ito LANG ang pwedeng piliin ni Qwen (allowlist).
/// Ang date, time, at title ay kinukuha ng code — hindi ni Qwen.
enum ZoeIntent {
  createReminder('create_reminder'),
  createTask('create_task'),
  createNote('create_note'),
  searchNotes('search_notes'),
  getToday('get_today'),
  getDone('get_done'),
  getMissed('get_missed'),
  greeting('greeting'),
  unknown('unknown');

  const ZoeIntent(this.label);

  /// Ang eksaktong salitang isinusulat ni Qwen.
  final String label;
}

/// Tinatanong si Qwen: "anong klaseng request ito?" — isang label lang ang sagot.
/// Dito lang umaabot ang mga mensaheng HINDI nahulaan ng IntentRules (code).
///
/// B6: may kasamang maliit na detalye ang label ([label] → [ZoeLabel]):
///   search_notes | gamot, mama      (mga salitang hahanapin — galing sa mensahe)
///   get_missed | last 3 days        (saklaw — isa sa ZoeLabel.ranges)
/// Code pa rin ang naghahanap at sumasagot. Mabagal (~7s), kaya para lang sa
/// mga tanong na hindi nahuli ng IntentRules.
///
/// Sandbox rules:
///  • Input Guard: pinuputol ang sobrang habang input.
///  • Allowlist: tinatanggap lang ang sagot kung isa sa mga label ng [ZoeIntent].
///  • Kahit ano pang iba (walang model, error, timeout, kakaibang sagot) → null,
///    at ang tumatawag ang bahala sa safe fallback.
///  • Walang sinusulat sa database dito. Label lang ang lumalabas.
class IntentClassifier {
  IntentClassifier({QwenEngine? engine}) : _engine = engine ?? QwenEngine.instance;

  final QwenEngine _engine;

  static const maxInput = 300;
  static const timeout = Duration(seconds: 40);

  /// Label + ilang salita ("search_notes | plate number"). Maikli pa rin.
  static const maxTokens = 16;

  /// Huling resulta, bilis, at model (para sa debugging):
  /// "create_task · 2.4s · lite", "null (timeout) · 40.0s · plus", atbp.
  static String lastResult = '–';

  /// Tumatakbong (o tapos nang) paghahanda. null = hindi pa nasisimulan.
  Future<void>? _warm;

  /// Ihanda si Qwen sa background: i-load ang model at ipabasa na ang mahabang
  /// bahagi ng prompt (rules + mga halimbawa). Sa susunod na tanong, ang
  /// mensahe na lang ng user ang babasahin niya, kaya mas mabilis.
  /// Ligtas tawagin nang paulit-ulit, at hindi nagta-throw.
  Future<void> warmUp() => _warm ??= _doWarmUp();

  Future<void> _doWarmUp() async {
    try {
      await _ask('hello');
    } catch (e) {
      if (e is TimeoutException) _engine.stop();
      debugPrint('Intent warm-up failed: $e');
      _warm = null; // pwedeng subukan ulit mamaya
    }
  }

  /// Ipadala ang prompt + [input] kay Qwen; ibinabalik ang hilaw na sagot.
  Future<String> _ask(String input) async {
    final messages = [
      const BrainMessage.system(_system),
      for (final (user, answer) in _examples) ...[
        BrainMessage.user(user),
        BrainMessage.assistant(answer),
      ],
      BrainMessage.user(input),
    ];
    final out = StringBuffer();
    await for (final piece
        in _engine.generate(messages, maxTokens: maxTokens, json: true).timeout(timeout)) {
      out.write(piece);
    }
    return out.toString();
  }

  static const _system =
      'You are an intent classifier for a reminder app. '
      'Read the user message (English, Tagalog, or Taglish) and answer with '
      'exactly ONE label and nothing else.\n'
      'Labels:\n'
      'create_reminder = wants to be reminded or alerted at a time\n'
      'create_task = something they need to do (a to-do)\n'
      'create_note = wants a fact or text saved\n'
      'search_notes = asks for a fact about themselves that they saved before\n'
      'get_today = asks what is scheduled or planned\n'
      'get_done = asks what they already finished\n'
      'get_missed = asks what they missed or forgot\n'
      'greeting = hello, thanks, small talk\n'
      'unknown = anything else\n'
      'For search_notes, add " | " and the key words copied from the message.\n'
      'For get_done, get_missed or get_today, only if the message mentions a time, add " | " '
      'and one of: today, yesterday, day before yesterday, the other day, last 3 days, '
      'last 7 days, this week, last week, this month, last month.';

  /// Maiikling halimbawa (user → sagot ni Qwen). Sadyang kaunti: bawat
  /// halimbawa ay binabasa ni Qwen sa bawat tanong, kaya mas marami = mas mabagal.
  /// Ang mga karaniwang pagkakasabi ay nahuhuli na ng IntentRules (code).
  static const _examples = <(String, String)>[
    ('pakiabisuhan ako 8am bukas, inom ng gamot', 'create_reminder'),
    ('bibili pa ako ng gatas sa Sabado', 'create_task'),
    ('ang locker code ko ay 4521', 'create_note'),
    ('yung plate number na binigay ko dati?', 'search_notes | plate number'),
    ('yung sinabi ko tungkol sa doktor ni lola', 'search_notes | doktor, lola'),
    ('anong meron bukas?', 'get_today'),
    ('how much have I gotten through this week?', 'get_done | this week'),
    ('may naiwan ba akong hindi nagawa nung isang araw?', 'get_missed | the other day'),
    ('nandito ka ba', 'greeting'),
    ('what is the capital of France?', 'unknown'),
    ('ang ganda ng panahon', 'unknown'),
  ];

  /// Intent lang (para sa lumang tawag). Tingnan ang [label].
  Future<ZoeIntent?> classify(String text) async => (await label(text))?.intent;

  /// Intent + detalye (mga salita / saklaw) mula kay Qwen.
  /// Returns null kapag hindi makasagot si Qwen nang maayos.
  Future<ZoeLabel?> label(String text) async {
    var input = text.trim();
    if (input.isEmpty) return null;
    if (input.length > maxInput) input = input.substring(0, maxInput);

    // Kasama sa oras ang paghihintay sa load, para totoo ang nakikita ng user.
    final watch = Stopwatch()..start();
    String took() => '${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s'
        ' · ${_engine.loadedTier?.name ?? 'walang model'}';

    // May tumatakbong paghahanda? Hintayin muna — isang generation lang
    // ang kaya ni Qwen sa isang pagkakataon.
    final warm = _warm;
    if (warm != null) await warm;

    try {
      final raw = await _ask(input);
      final said = parse(raw);
      // Code ang may huling salita: "reminder" na walang oras / araw / utos → unknown.
      final intent = checkWithCode(said, input);
      // Detalye: salitang nasa mensahe lang, saklaw na nasa allowlist lang.
      final result = intent == null ? null : ZoeLabel.from(intent, raw, input);
      final shown = said == null
          ? 'null (hindi label: "${raw.trim()}")'
          : intent == said
              ? '$result'
              : '${said.label} → ${intent?.label} (walang oras/araw/utos)';
      lastResult = '$shown · ${took()}';
      return result;
    } on TimeoutException {
      _engine.stop();
      lastResult = 'null (timeout) · ${took()}';
      return null;
    } catch (e) {
      debugPrint('Intent classify failed: $e');
      lastResult = 'null ($e) · ${took()}';
      return null;
    }
  }

  // ───────────── Code check sa sagot ni Qwen (create_reminder / create_task) ─────────────
  //
  // Ang maliit na model ay minsang nagsasabing "create_reminder" kahit hindi
  // naman (hal. "hindi ako pagod", "ano pwede gawin kapag tinatamad?") →
  // lumalabas ang "What time?". Kaya tinitingnan muna ng code kung may
  // palatandaan talaga: utos, oras / araw, o "kailangan kong…".

  /// Malinaw na utos: remind, paalala, alarm, add task, i-set…
  static final _createWords = RegExp(
    r'\b(remind|reminder|reminders|i-?remind|paalala|paalalahanan|ipaalala|alarm'
    r'|gisingin|wake me|abisuhan|i-?alert|alert me|sabihan mo|set|i-?set|add|i-?add'
    r'|task|to-?do|gawain|schedule|i-?schedule|i-?lista|isulat mo)\b',
  );

  /// May oras o araw: "8am", "7:30", "alas 5", "bukas", "sa Sabado", "Feb 12".
  /// (Ang "5 ampalaya" ay HINDI oras.)
  /// Walang "linggo" (pwedeng "week" o "Sunday") at walang "ngayon" (masyadong karaniwan).
  static final _when = RegExp(
    r'\b\d{1,2}(:\d{2})?\s*(am\b|pm\b|a\.m\.|p\.m\.)'
    r'|\b([01]?\d|2[0-3]):[0-5]\d\b'
    r'|\balas[\s-]*\d'
    r'|\b(umaga|tanghali|hapon|gabi|noon|tonight|mamaya|mamayang|later|bukas|tomorrow'
    r'|today|ngayong araw|next week|susunod na linggo|every|araw-?araw|tuwing'
    r'|daily|weekly)\b'
    r'|\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|lunes|martes'
    r'|miyerkules|huwebes|biyernes|sabado)\b'
    r'|\b(january|february|march|april|june|july|august|september|october|november'
    r'|december|jan|feb|mar|apr|jun|jul|aug|sept?|oct|nov|dec|enero|pebrero|marso'
    r'|abril|mayo|hunyo|hulyo|agosto|setyembre|oktubre|nobyembre|disyembre)\.?\s+\d'
    r'|\bin \d+ ?(minutes?|mins?|hours?|hrs?)\b',
  );

  /// "Kailangan kong…", "bibili pa ako…", "I need to…" — may gagawin (task).
  static final _needWords = RegExp(
    r"\b(kailangan|kelangan|need to|have to|has to|got to|gotta|must|dapat|bibili"
    r"|bumili|buy|magbabayad|magbayad|bayaran|pay|pupunta|gagawa|tatapusin|ipapasa"
    r"|submit|deadline|i should|i'll|i will)\b",
  );

  /// Tanong: "ano…", "paano…", "what…", o may "?" sa dulo.
  static final _question = RegExp(
    r"^(zoe[,\s]+)?(ano|anong|ano'ng|paano|bakit|saan|sino|pwede ba|what|how|why"
    r"|where|who|should i|is it|do you)\b|\?\s*$",
  );

  /// Tinatanggap lang ang create_reminder / create_task ni Qwen kapag may
  /// palatandaan sa mensahe. Kung wala → unknown (hindi na magtatanong ng oras).
  /// Ang ibang label ay hindi ginagalaw.
  ///
  ///  • may utos (remind, paalala, add task…)             → tanggap
  ///  • tanong na walang utos ("ano pwede gawin…?")       → unknown
  ///  • reminder: may oras o araw                          → tanggap
  ///  • task: may oras / araw o "kailangan / bibili…"      → tanggap
  ///  • wala sa itaas ("hindi ako pagod")                  → unknown
  @visibleForTesting
  static ZoeIntent? checkWithCode(ZoeIntent? intent, String text) {
    if (intent != ZoeIntent.createReminder && intent != ZoeIntent.createTask) return intent;
    final t = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (_createWords.hasMatch(t)) return intent;
    if (_question.hasMatch(t)) return ZoeIntent.unknown;
    if (_when.hasMatch(t)) return intent;
    if (intent == ZoeIntent.createTask && _needWords.hasMatch(t)) return intent;
    return ZoeIntent.unknown;
  }

  /// Allowlist check: dapat may eksaktong label sa sagot. Kung wala → null.
  @visibleForTesting
  static ZoeIntent? parse(String raw) {
    final lower = raw.toLowerCase();
    ZoeIntent? found;
    var foundAt = -1;
    for (final intent in ZoeIntent.values) {
      final at = lower.indexOf(intent.label);
      if (at >= 0 && (foundAt < 0 || at < foundAt)) {
        found = intent;
        foundAt = at;
      }
    }
    return found;
  }
}