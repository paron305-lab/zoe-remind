import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zoe_remind/ai/inference/qwen_engine.dart';

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
      for (final (user, intent) in _examples) ...[
        BrainMessage.user(user),
        BrainMessage.assistant(intent.label),
      ],
      BrainMessage.user(input),
    ];
    final out = StringBuffer();
    await for (final piece
        in _engine.generate(messages, maxTokens: 8, json: true).timeout(timeout)) {
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
      'unknown = anything else';

  /// Maiikling halimbawa, isa kada label. Sadyang kaunti: bawat halimbawa ay
  /// binabasa ni Qwen sa bawat tanong, kaya mas marami = mas mabagal.
  /// Ang mga karaniwang pagkakasabi ay nahuhuli na ng IntentRules (code).
  static const _examples = <(String, ZoeIntent)>[
    ('pakiabisuhan ako 8am bukas, inom ng gamot', ZoeIntent.createReminder),
    ('bibili pa ako ng gatas sa Sabado', ZoeIntent.createTask),
    ('ang locker code ko ay 4521', ZoeIntent.createNote),
    ('yung plate number na binigay ko dati?', ZoeIntent.searchNotes),
    ('anong meron bukas?', ZoeIntent.getToday),
    ('how much have I gotten through?', ZoeIntent.getDone),
    ('may naiwan ba akong hindi nagawa?', ZoeIntent.getMissed),
    ('nandito ka ba', ZoeIntent.greeting),
    ('what is the capital of France?', ZoeIntent.unknown),
    ('ang ganda ng panahon', ZoeIntent.unknown),
  ];

  /// Returns null kapag hindi makasagot si Qwen nang maayos.
  Future<ZoeIntent?> classify(String text) async {
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
      final intent = parse(raw);
      final label = intent?.label ?? 'null (hindi label: "${raw.trim()}")';
      lastResult = '$label · ${took()}';
      return intent;
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