import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/ai/parser/intent_rules.dart';
import 'package:zoe_remind/ai/parser/text_normalizer.dart';
import 'package:zoe_remind/features/companion/controllers/tone_detector.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';
import 'package:zoe_remind/memory/memory_rules.dart';

/// Saan pupunta ang mensahe (pagkatapos ng CrisisGuard at math).
enum ZoeRoute {
  /// "patayin mo ang alarm" → tulong.
  stopAlarm,

  /// "salamat", "ty", "thank you zoe".
  thanks,

  /// "tandaan mo na mas gusto ko…" / "call me AC" → memory card.
  memory,

  /// Hindi malinaw na utos → "Reminder ba 'to, task, o note?"
  askKind,

  /// "pagod na ako", "yay natapos ko!" → script para sa nararamdaman.
  feeling,

  /// Malinaw na utos → card (o tanong ng oras / title).
  reminder,
  task,
  note,

  /// Tanong tungkol sa na-save ("ano wifi password ko?") → RAG.
  search,

  /// "ano gagawin ko today?", "busy ba ako bukas?"
  today,

  /// "ano natapos ko kahapon?"
  done,

  /// "ano na-miss ko?"
  missed,

  /// "hi", "gm", "kumusta"
  greeting,

  /// Walang tumamang rule → IntentRules.isFeeling (malasakit) o si Qwen.
  unknown,
}

/// Desisyon ng router para sa isang mensahe.
class ChatRoute {
  const ChatRoute(this.route, this.intent, this.tone, {this.memoryChip = false});

  final ZoeRoute route;

  /// Ang hula ng IntentRules (para sa [ChatPreviewBrain] _answer).
  final ZoeIntent intent;

  /// Nararamdaman ng user (pagod → "isa-isa lang tayo" bago ang card).
  final UserTone tone;

  /// [ZoeRoute.askKind]: may 💜 Tandaan chip ba?
  final bool memoryChip;

  @override
  String toString() => 'ChatRoute($route, $intent, $tone, memoryChip: $memoryChip)';
}

/// Ang pagkakasunod ng desisyon ng Zoe Chat — PURE (walang database, walang model).
///
///   1. stopAlarm   "patayin mo ang alarm"
///   2. thanks      walang ibang intent + "salamat / thank"
///   3. memory      "tandaan mo / remember / call me…" + tungkol sa iyo, walang oras
///                  (may "remind" din → askKind na may 💜 Tandaan)
///   4. feeling     nararamdaman + walang utos (o bati lang, o pahayag na
///                  "natapos ko lahat!" / "ang saya ko today" — hindi tanong)
///   5. askKind     hindi sigurado ang reminder / task ("meeting 3pm bukas")
///                  (pagod + "kailangan kong…" → feeling, hindi tanong)
///   6. intent      malinaw na utos / tanong → card o sagot
///
/// Ginagamit ng [ChatPreviewBrain.reply], at ng phrase-bank test
/// (`flutter test test/ai/phrase_bank_test.dart`) — kaya iisa ang patakaran.
class ChatRouter {
  ChatRouter._();

  /// Text-speak → buong salita, maliit na titik, isang space lang.
  static String clean(String text) =>
      TextNormalizer.normalize(text).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Ano ang nararamdaman ng user sa mensaheng ito?
  /// Ang "happy" sa tanong ("nice ba yung movie?") ay hindi binibilang.
  static UserTone toneOf(String text) {
    final tone = ToneDetector.detect(text).tone;
    if (tone == UserTone.happy && text.trim().endsWith('?')) return UserTone.neutral;
    return tone;
  }

  static bool _isCreate(ZoeIntent i) =>
      i == ZoeIntent.createReminder || i == ZoeIntent.createTask || i == ZoeIntent.createNote;

  static ChatRoute of(String text) {
    final lower = clean(text);
    final tone = toneOf(text);

    if (IntentRules.isStopAlarm(lower)) {
      return ChatRoute(ZoeRoute.stopAlarm, ZoeIntent.unknown, tone);
    }

    final match = IntentRules.matchFull(lower);
    final intent = match.intent;

    if (intent == ZoeIntent.unknown && (lower.contains('salamat') || lower.contains('thank'))) {
      return ChatRoute(ZoeRoute.thanks, intent, tone);
    }

    // Memory bago ang intent: ang "reminders" sa "gusto ko ng morning reminders"
    // ay tatama sa reminder rule. Tanong ("do you remember…?") → hindi.
    if (intent != ZoeIntent.searchNotes && MemoryRules.isRememberAboutMe(lower)) {
      if (MemoryRules.mentionsReminder(lower)) {
        return ChatRoute(ZoeRoute.askKind, intent, tone, memoryChip: true);
      }
      return ChatRoute(ZoeRoute.memory, intent, tone);
    }

    final feeling = ZoeLines.situationForTone(tone) != null;
    // "yay natapos ko lahat!", "ang saya ko today", "grabe pagod ko ngayon" →
    // pahayag ng nararamdaman (hindi tanong) → feeling, hindi listahan.
    final story = !IntentRules.isQuestion(lower) &&
        (intent == ZoeIntent.getToday || intent == ZoeIntent.getDone || intent == ZoeIntent.getMissed);
    if (feeling &&
        (intent == ZoeIntent.unknown || intent == ZoeIntent.greeting || story)) {
      return ChatRoute(ZoeRoute.feeling, intent, tone);
    }

    if (!match.sure && _isCreate(intent)) {
      // "pagod na ako, kailangan ko pang tapusin to" → nagkukuwento, hindi utos.
      if (feeling && tone.isDown) return ChatRoute(ZoeRoute.feeling, intent, tone);
      return ChatRoute(ZoeRoute.askKind, intent, tone, memoryChip: MemoryRules.hasTrigger(lower));
    }

    final route = switch (intent) {
      ZoeIntent.createReminder => ZoeRoute.reminder,
      ZoeIntent.createTask => ZoeRoute.task,
      ZoeIntent.createNote => ZoeRoute.note,
      ZoeIntent.searchNotes => ZoeRoute.search,
      ZoeIntent.getToday => ZoeRoute.today,
      ZoeIntent.getDone => ZoeRoute.done,
      ZoeIntent.getMissed => ZoeRoute.missed,
      ZoeIntent.greeting => ZoeRoute.greeting,
      ZoeIntent.unknown => ZoeRoute.unknown,
    };
    return ChatRoute(route, intent, tone);
  }
}