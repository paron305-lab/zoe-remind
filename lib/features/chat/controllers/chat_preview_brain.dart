import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:zoe_remind/ai/parser/crisis_guard.dart';
import 'package:zoe_remind/ai/parser/intent_classifier.dart';
import 'package:zoe_remind/ai/parser/intent_rules.dart';
import 'package:zoe_remind/ai/parser/text_normalizer.dart';
import 'package:zoe_remind/ai/parser/when_parser.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/core/utils/zoe_date.dart';
import 'package:zoe_remind/database/models/reminder_occurrence.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/reminder_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/database/repositories/task_repository.dart';
import 'package:zoe_remind/features/chat/controllers/chat_router.dart';
import 'package:zoe_remind/features/chat/models/chat_drafts.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';
import 'package:zoe_remind/features/companion/controllers/companion_lines.dart';
import 'package:zoe_remind/features/companion/controllers/mood_controller.dart';
import 'package:zoe_remind/features/companion/controllers/mood_log.dart';
import 'package:zoe_remind/features/companion/controllers/mood_now.dart';
import 'package:zoe_remind/features/companion/controllers/tone_detector.dart';
import 'package:zoe_remind/features/companion/controllers/zoe_lines.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/features/companion/models/mood_week.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';
import 'package:zoe_remind/features/reminders/models/reminder_status.dart';
import 'package:zoe_remind/features/reminders/services/reminder_alarm_service.dart';
import 'package:zoe_remind/memory/companion_facts.dart';
import 'package:zoe_remind/memory/companion_profile.dart';
import 'package:zoe_remind/memory/habit_rules.dart';
import 'package:zoe_remind/memory/memory_recall.dart';
import 'package:zoe_remind/memory/memory_rules.dart';
import 'package:zoe_remind/rag/history_query.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';
import 'package:zoe_remind/rag/search_misses.dart';
import 'package:zoe_remind/rag/snippet.dart';

/// Utak ng Zoe Chat (hybrid): code muna, si Qwen kapag hindi sigurado ang code.
///
///   0. CrisisGuard (code) → laging una; hindi dumadaan kay Qwen kailanman.
///   1. ToneDetector (code) → binabasa ang nararamdaman ng user; ipinapasa
///                            sa MoodController (pagod → gentle si Zoe).
///   2. IntentRules (code) → agad ang sagot, gumagana kahit walang model.
///   3. Walang tumamang rule? → tinatanong si Qwen kung anong INTENT (label lang).
///      B6: may kasamang detalye ang label — mga salitang hahanapin
///      ("search_notes | gamot, mama") o saklaw ("get_missed | last 3 days").
///      Code (ZoeLabel) ang nagsasala: salitang wala sa mensahe → tapon.
///   4. Date, time, title → laging code ang kumukuha (hindi si Qwen).
///   5. Lahat ng write    → confirmation card; walang nase-save hangga't
///                          hindi pinipindot ng user ang Accept.
///   6. Ang mga salita ni Zoe ay galing sa ZoeLines (code), hindi kay Qwen,
///      at pinipili ayon sa mood ni Zoe (gentle / proud / sleepy…).
///   7. Mood log (Level 2): binibilang ang tone (hindi ang mensahe) sa
///      huling 7 araw. Kapag 3+ araw nang pagod / stressed, minsan isang araw
///      sasabihin ni Zoe: "Mukhang busy ang linggo mo…" bago ang feeling script.
///   8. Mga tanong tungkol sa nakaraan ("ano na-miss ko?", "ano ginawa ko
///      kahapon?") → binabasa ang HISTORY tables (reminder_occurrences,
///      task_history, completion_history), hindi ang kasalukuyang estado.
///      Dito rin babasa ang RAG / Memory Engine.
///      Saklaw (B4): "last week", "this month", "noong Lunes", "huling 3 araw"
///      → HistoryQuery.
///   9. RAG (Phase B): "ano wifi password ko?" → Retriever (FTS4 sa notes +
///      memories). Ang sagot ay ang note / memory MISMO + ang mga source
///      ("📝 Galing sa notes mo" + hanggang 3 note). Walang iniimbento si Zoe.
///  10. Memories (B5): "tandaan mo na mas gusto ko ng morning reminders" →
///      memory card (Accept muna). OFF ang long-term memory → note card na lang.
///      Data ("tandaan mo, wifi password ay…") → note pa rin (MemoryRules).
///  11. Tanong muna (phrase bank): kapag HINDI malinaw na utos
///      ("meeting kay boss 3pm bukas", "kailangan kong magbayad…", "task",
///      "remember… i love to remind about…", hula ni Qwen) → hindi agad card:
///      "Reminder ba 'to, task, o note?" [⏰ Reminder] [✅ Task] [📝 Note] [✖ Wala].
///      Malinaw na utos ("remind me…", "add task…", "i-note mo…") → card agad.
///      Text-speak ("pls rmnd me 2mrw 8am") → TextNormalizer muna.
///
/// Level 3 Companion memory (galing sa memories, sinabi / kinumpirma ng user):
///   "call me AC"                 → memory card "Call me AC" → bati: "Hi, AC!"
///   "diretsuhin mo lang ako"     → maikli ang mga linya, walang "isa-isa lang tayo"
///   "malambing ka sa akin"       → mas malambot ang mga linya
///   "kapag stressed ako, makinig ka muna" → sa susunod na stressed: makikinig
///   Wala pang stress help + down ang user → isang beses lang magtatanong:
///   "Kapag stressed ka, ano'ng nakakatulong?" [🎧 Makinig] [💡 Payo] [😄 Pampagaan] [✖ Huwag na]
///
/// Small talk (buong mensahe lang): "wassup" → bati; "kumusta ka?" → "Okay naman
/// ako! Ikaw?"; "sino ka?" / "tao ka ba?" → tapat na AI si Zoe; "good night",
/// "bye", "ang galing mo", "love you zoe" (hindi romantic), "bored ako".
///
/// Nararamdaman (2c):
///   "pagod na ako"              → feelingTired script, magiging gentle si Zoe
///   "hi zoe, stressed ako"      → feelingStressed (hindi na bati)
///   "stressed na ako, remind me bukas 8am mag-review"
///                               → "Sige, isa-isa lang tayo." + reminder card
///   "yay natapos ko lahat!"     → masaya si Zoe (UserPositive)
///
/// Subukan (may keyword → code):
///   "Zoe, remind me tomorrow at 7 PM to review my thesis"
///   "pa remind ako ng feb 12 2028 mga 9am kakain ako"
///   "add task buy groceries on Saturday"
///   "i-note mo: wifi password ng office ay zoe123"
///   "ano gagawin ko today?" · "ano ginawa ko kahapon?" · "ano na-miss ko?"
///   "ano locker code ko?"                 → hinahanap sa Notes (code)
///   "89+9"                                → code ang nagko-compute, hindi si Qwen
/// Subukan (walang salitang "remind/task/note" pero code pa rin → agad):
///   "gisingin mo ako bukas ng 5:30am" · "kailangan kong magbayad ng kuryente"
///   "tandaan mo, ang wifi password sa bahay ay zoe2026" · "busy ba ako bukas?"
/// Subukan (walang tumamang rule → Qwen, ilang segundo):
///   "sino ang presidente ng Pilipinas?" · "ang ganda ng panahon"
///   "test error"                          → error state + Retry
class ChatPreviewBrain {
  ChatPreviewBrain({
    ReminderRepository? reminders,
    TaskRepository? tasks,
    Retriever? retriever,
    Future<bool> Function()? memoryOn,
    IntentClassifier? classifier,
    MoodState Function()? mood,
    void Function(ZoeEvent event)? onMoodEvent,
    void Function(UserTone tone)? onTone,
    Future<WeekVibe?> Function(UserTone tone)? weekNote,
    DateTime Function()? clock,
    Future<Map<int, DateTime>> Function()? activeAlarms,
    Future<CompanionProfile> Function()? profile,
    Future<bool> Function()? helpAsked,
    Future<void> Function()? markHelpAsked,
    Future<List<String>> Function()? memories,
  })  : _reminders = reminders ?? ReminderRepository(),
        _tasks = tasks ?? TaskRepository(),
        _retriever = retriever ?? Retriever(),
        _memoryOn = memoryOn ?? SettingsRepository().isLongTermMemoryOn,
        _classifier = classifier ?? IntentClassifier(),
        _moodOf = mood ?? (() => MoodNow.current),
        _report = onMoodEvent ?? MoodController.instance.add,
        _logTone = onTone ?? MoodLog.instance.record,
        _weekNote = weekNote ?? MoodLog.instance.noteFor,
        _clock = clock ?? DateTime.now,
        _activeAlarms = activeAlarms ?? ReminderAlarmService.instance.activeAlarmOccurrences,
        _profileOf = profile ?? MemoryRepository().profile,
        _helpAsked = helpAsked ??
            (() async => await SettingsRepository().getValue(helpAskedKey) == 'true'),
        _markHelpAsked = markHelpAsked ?? (() => SettingsRepository().setValue(helpAskedKey, 'true')),
        _memoriesOf = memories ??
            (() async => [for (final m in await MemoryRepository().getAll()) m.content]);

  /// Settings key: naitanong na ba ang "Kapag stressed ka, ano'ng nakakatulong?"
  /// (Binubura ng "Burahin lahat".)
  static const helpAskedKey = 'companion_help_asked';

  /// true = gumagana ang chat (keywords) kahit walang naka-download na model.
  static const enabled = true;

  final ReminderRepository _reminders;
  final TaskRepository _tasks;

  /// RAG: hinahanap ang sagot sa notes + memories.
  final Retriever _retriever;

  /// ON ba ang long-term memory? OFF → hindi binabasa / sine-save ang memories.
  final Future<bool> Function() _memoryOn;
  final IntentClassifier _classifier;

  /// Mood ni Zoe ngayon (para sa salita). Sa test: pwedeng ipasa.
  final MoodState Function() _moodOf;

  /// Saan ipapasa ang event (UserFeelsDown, UserPositive). Default: MoodController.
  final void Function(ZoeEvent event) _report;

  /// Saan bibilangin ang tone (mood log, 7 araw). Default: MoodLog.
  final void Function(UserTone tone) _logTone;

  /// May sasabihin ba tungkol sa linggo? (isang beses kada araw). Default: MoodLog.
  final Future<WeekVibe?> Function(UserTone tone) _weekNote;

  /// Oras ngayon. Sa test: pwedeng ipasa ang sariling oras.
  final DateTime Function() _clock;

  /// Mga alarm na naka-snooze / nagri-ring (para hindi agad "Missed").
  /// Default: ReminderAlarmService. Sa test: pwedeng ipasa.
  final Future<Map<int, DateTime>> Function() _activeAlarms;

  /// Level 3: nickname, style, stress help, wins, routines. Default: MemoryRepository.
  final Future<CompanionProfile> Function() _profileOf;

  /// Naitanong na ba ang stress help? Default: settings.
  final Future<bool> Function() _helpAsked;
  final Future<void> Function() _markHelpAsked;

  /// Memory Recall: lahat ng memory (content lang). Default: MemoryRepository.
  final Future<List<String>> Function() _memoriesOf;

  /// Ang alam ni Zoe tungkol sa user (kinukuha isang beses kada reply).
  CompanionProfile _profile = CompanionProfile.empty;

  /// Ilang beses nang down ang user sa session na ito (para sa winCheer,
  /// tuwing ika-3 lang — hindi sa bawat mensahe).
  int _downReplies = 0;

  /// "ano na-miss ko?" = ilang araw pabalik (kasama ngayon).
  static const missedDays = 7;

  ZoeLanguage _lang = ZoeLanguage.both;

  /// Mood na gagamitin sa sagot na ito (kinukuha isang beses kada reply).
  MoodState _mood = MoodState.content;

  /// true = nasimulan na ang pag-load kay Qwen sa background.
  bool _warmStarted = false;

  /// English → [en], Tagalog / Both → [tl]. (Para sa maliliit na label lang.)
  String _t(String en, String tl) => _lang == ZoeLanguage.english ? en : tl;

  /// Linya ni Zoe mula sa ZoeLines, ayon sa language at mood ni Zoe.
  String _say(ZoeSituation s, [Map<String, String> vars = const {}]) =>
      ZoeLines.pickFor(_lang, s, _mood, vars);

  /// Linya ni Zoe ayon sa Level 3 (nickname + diretso / malambing).
  String _sayFor(CompanionSituation s, {TalkStyle? style, Map<String, String> vars = const {}}) =>
      CompanionLines.pick(_lang, s,
          style: style ?? _profile.style, name: _profile.nickname, vars: vars);

  /// Level 3 profile. Kapag pumalya (o OFF ang long-term memory) → walang alam.
  Future<CompanionProfile> _profileSafe() async {
    try {
      if (!await _memoryOnSafe()) return CompanionProfile.empty;
      return await _profileOf();
    } catch (_) {
      return CompanionProfile.empty;
    }
  }

  /// Ano ang nararamdaman ng user sa mensaheng ito? (Tingnan ang [ChatRouter.toneOf].)
  static UserTone toneOf(String text) => ChatRouter.toneOf(text);

  Future<List<ChatEntry>> reply(String text, ZoeLanguage lang) async {
    _lang = lang;
    _mood = _moodOf();
    // Text-speak → buong salita ("pls rmnd me 2mrw" → "please remind me tomorrow").
    final lower = ChatRouter.clean(text);

    // Laging una: pananakit sa sarili → nakahandang sagot + hotline.
    // Walang card, walang Qwen, walang ibang rule na makakasapaw,
    // at hindi ito ginagawang mood event.
    if (CrisisGuard.matches(text)) {
      return [
        TextEntry(
          fromZoe: true,
          text: _say(ZoeSituation.crisis, CrisisGuard.lineVars),
        ),
      ];
    }

    if (lower == 'test error') throw StateError('UI preview error');

    // Level 3: ano'ng alam ni Zoe tungkol sa user + ang mga linya niya.
    _profile = await _profileSafe();
    await CompanionLines.ensureLoaded();

    // Saan pupunta ang mensahe — iisang patakaran (ChatRouter, pure).
    final route = ChatRouter.of(text);
    final tone = route.tone;

    // Nararamdaman ng user → ipaalam sa MoodController (pagod → gentle si Zoe).
    // Ang mensahe ay hindi sine-save dito; ang mood ni Zoe ang nagbabago.
    // Mood log (7 araw): +1 sa bilang ng tone ngayong araw (hindi ang mensahe).
    // OFF sa Settings → walang binibilang. Neutral → wala.
    // Level 3: "kapag stressed ako, makinig ka muna" ay kagustuhan, hindi
    // nararamdaman ngayon → hindi binibilang, hindi nagbabago ang mood.
    // Small talk ("good night", "bored ako") → hindi rin binibilang.
    final aboutMe = route.route == ZoeRoute.memory || route.talk != null;
    if (tone != UserTone.neutral && !aboutMe) _logTone(tone);
    final event = aboutMe ? null : ToneDetector.toMoodEvent(tone);
    if (event != null) {
      _report(event);
      // Ang SAGOT na ito ay ayon na sa bagong mood (hindi na hinihintay ang controller).
      if (tone.isDown) _mood = MoodState.gentle;
    }

    // Math → code ang sumasagot (laging tama), hindi si Qwen.
    final math = _math(lower);
    if (math != null) return [TextEntry(fromZoe: true, text: math)];

    // Pagod / stressed pero may utos → "Sige, isa-isa lang tayo." bago ang sagot.
    // Diretso (Level 3) → walang dagdag na linya, card agad.
    List<ChatEntry> gently(List<ChatEntry> answer) => tone.isDown && !aboutMe && !_profile.isDiretso
        ? [TextEntry(fromZoe: true, text: _say(ZoeSituation.feelingAck)), ...answer]
        : answer;

    // Memory Recall: may sinabi ka dati na may kinalaman dito?
    //   "ang sarap kumain ng hipon" + "Allergic ako sa hipon" → "Teka — diba allergic ka sa hipon?"
    //   "di ba sinabi ko allergic ako sa hipon?" → "Oo naman, naaalala ko…"
    // Usapan lang (feeling / bati / hindi alam) — hindi sa utos (reminder, task, note…).
    if (route.route == ZoeRoute.feeling ||
        route.route == ZoeRoute.greeting ||
        route.route == ZoeRoute.unknown) {
      final hit = await _recall(lower);
      if (hit != null) {
        final line = TextEntry(fromZoe: true, text: MemoryRecall.lineFor(hit, _lang));
        if (!tone.isDown) return [line];
        // Pagod / malungkot: malasakit muna, saka ang paalala. Paborito → hindi muna.
        if (hit.known || hit.fact.kind == RecallKind.avoid) {
          return [TextEntry(fromZoe: true, text: _say(ZoeSituation.comfort)), line];
        }
      }
    }

    switch (route.route) {
      // "patayin mo ang alarm" → tulong, hindi bagong reminder.
      case ZoeRoute.stopAlarm:
        return [TextEntry(fromZoe: true, text: _say(ZoeSituation.stopAlarmHelp))];

      // "salamat" / "thank you" (kahit may "ang galing mo") → pasasalamat.
      case ZoeRoute.thanks:
        if (event == null) _report(const UserPositive()); // isang event lang
        return [TextEntry(fromZoe: true, text: _say(ZoeSituation.thanks))];

      // "tandaan mo na mas gusto ko ng morning reminders" → memory card (B5).
      case ZoeRoute.memory:
        return gently(await _memory(text));

      // Hindi malinaw ("meeting 3pm bukas", "kailangan kong…", "task",
      // "remember… i love to remind…") → TANONG muna, hindi agad card.
      case ZoeRoute.askKind:
        return gently([askKind(text, memory: route.memoryChip)]);

      // Small talk: "kumusta ka?", "sino ka?", "tao ka ba?", "good night", "bye"…
      // ("wassup" / "hello" → karaniwang bati sa _answer.)
      case ZoeRoute.greeting when route.talk != null && CompanionLines.talkFor(route.talk!) != null:
        return [
          TextEntry(fromZoe: true, text: _sayFor(CompanionLines.talkFor(route.talk!)!)),
        ];

      // "pagod na ako", "hi zoe, stressed ako" → script para sa nararamdaman.
      case ZoeRoute.feeling:
        final feeling = ZoeLines.situationForTone(tone)!;
        final help = _profile.stressHelp;
        // Level 3: down + alam ang gusto niya (makinig / payo / pampagaan) →
        // iyon ang sagot. Kung hindi pa alam → karaniwang script.
        final reply = TextEntry(
          fromZoe: true,
          text: tone.isDown && help != null
              ? _sayFor(CompanionLines.downFor(help))
              : _say(feeling),
        );
        final extra = <ChatEntry>[];
        if (tone.isDown) {
          // Paalala ng isang panalo (tuwing ika-3 down na sagot lang).
          final win = _profile.wins.isEmpty ? null : _profile.wins[_downReplies % _profile.wins.length];
          if (help != null && win != null && _downReplies % 3 == 0) {
            extra.add(TextEntry(
              fromZoe: true,
              text: _sayFor(CompanionSituation.winCheer, vars: {'win': win}),
            ));
          }
          _downReplies++;
          // Isang beses lang: "Kapag stressed ka, ano'ng nakakatulong?"
          if (help == null) {
            final ask = await _helpQuestion();
            if (ask != null) extra.add(ask);
          }
        }
        // Level 2: ilang araw nang ganito? (isang beses lang kada araw)
        final week = await _weekLine(tone);
        if (week == null) return [reply, ...extra];
        // Pagod / stressed: "Mukhang busy ang linggo mo…" muna, saka ang script.
        // Masaya: ang script muna, saka "Ang dami mong good days…".
        return tone.isDown ? [week, reply, ...extra] : [reply, week, ...extra];

      default:
        return gently(await _answer(route.intent, text, lower));
    }
  }

  /// Linya tungkol sa linggo (mood log), o null kung wala / nasabi na ngayong araw.
  /// Kapag pumalya ang database, null lang — hindi naaapektuhan ang sagot.
  Future<TextEntry?> _weekLine(UserTone tone) async {
    WeekVibe? vibe;
    try {
      vibe = await _weekNote(tone);
    } catch (_) {
      vibe = null;
    }
    if (vibe == null) return null;
    return TextEntry(fromZoe: true, text: _say(ZoeLines.situationForWeek(vibe)));
  }

  /// Sagot ayon sa intent (code muna; si Qwen kapag hindi alam ng code).
  Future<List<ChatEntry>> _answer(ZoeIntent codeIntent, String text, String lower) async {
    var intent = codeIntent;
    // B6: label ni Qwen (kapag siya ang tinanong) — mga salita / saklaw.
    ZoeLabel? guess;
    if (intent == ZoeIntent.unknown) {
      // Hindi nabasa ng ToneDetector pero mukhang nagkukuwento ("nahihirapan ako")
      // → maikling malasakit, agad (hindi na kay Qwen).
      if (IntentRules.isFeeling(lower)) {
        _report(const UserFeelsDown());
        _mood = MoodState.gentle;
        return [TextEntry(fromZoe: true, text: _say(ZoeSituation.comfort))];
      }
      guess = await _classifier.label(text);
      intent = guess?.intent ?? ZoeIntent.unknown;
      // Hula ni Qwen na gumawa (reminder / task / note) → tanong muna, hindi card.
      if (_isCreate(intent)) {
        return [askKind(text, memory: MemoryRules.hasTrigger(lower))];
      }
    } else if (!_warmStarted) {
      // Code ang sumagot ngayon. Habang nagbabasa ang user, ihanda na si Qwen
      // sa background para mabilis na siya kapag kinailangan mamaya.
      _warmStarted = true;
      unawaited(_classifier.warmUp());
    }

    switch (intent) {
      case ZoeIntent.createNote:
        return [_note(text)];
      case ZoeIntent.searchNotes:
        return [await _searchNotes(lower, words: guess?.words ?? const [])];
      case ZoeIntent.createReminder:
        return [_reminder(text, lower)];
      case ZoeIntent.createTask:
        return [_task(text, lower)];
      case ZoeIntent.getDone:
        // "kahapon", "last week", "this month", "noong Lunes"… (default: kahapon)
        final doneRange = HistoryQuery.range(lower, now: _now()) ??
            _guessRange(guess) ??
            HistoryRange.day(_daysAgo(1));
        return [await _doneIn(doneRange)];
      case ZoeIntent.getMissed:
        // default: huling 7 araw (kasama ngayon)
        final missedRange = HistoryQuery.range(lower, now: _now()) ??
            _guessRange(guess) ??
            HistoryQuery.lastDays(missedDays, now: _now());
        return [await _missedIn(missedRange)];
      case ZoeIntent.getToday:
        // "ano mga tasks ko kahapon?" / "last week" → history (natapos + na-miss).
        // strict: ang "sa lunes" ay susunod na Lunes pa rin (schedule).
        final past =
            HistoryQuery.range(lower, now: _now(), strict: true) ?? _guessRange(guess);
        if (past != null && past.to.isBefore(_today0)) {
          return [await _doneIn(past, withMissed: true)];
        }
        // "busy ba ako bukas?" → bukas ang titingnan, hindi today.
        return [await _scheduleOn(_day(lower) ?? _today0)];
      case ZoeIntent.greeting:
        // Level 3: may nickname at normal ang mood → "Hi, AC! …"
        if (_profile.nickname != null && _mood == MoodState.content) {
          return [TextEntry(fromZoe: true, text: _sayFor(CompanionSituation.greet))];
        }
        return [TextEntry(fromZoe: true, text: _say(ZoeSituation.greeting))];
      case ZoeIntent.unknown:
        return [
          TextEntry(
            fromZoe: true,
            text: _say(ZoeSituation.unknown),
            // Halimbawa lang para sa user. (Para sa bilis ni Qwen:
            // Developer › Brain Test — hindi na sa chat.)
            footnote: 'Try: "remind me…", "add task…", "i-note mo…"',
          ),
        ];
    }
  }

  /// Saklaw mula sa label ni Qwen ("last 3 days") → petsa (code, HistoryQuery).
  /// null kapag walang saklaw ang label.
  HistoryRange? _guessRange(ZoeLabel? guess) {
    final r = guess?.range;
    return r == null ? null : HistoryQuery.range(r, now: _now());
  }

  // ───────────────────────── Tanong muna (uri) ─────────────────────────

  static bool _isCreate(ZoeIntent i) =>
      i == ZoeIntent.createReminder || i == ZoeIntent.createTask || i == ZoeIntent.createNote;

  /// "Reminder ba 'to, task, o note?" + chips. [memory] = may 💜 Tandaan chip.
  /// Ang [text] ang gagawing card kapag pumili ang user ([draftFor]).
  ClarifyEntry askKind(String text, {bool memory = false}) => ClarifyEntry(
        question: _say(ZoeSituation.askKind),
        source: text,
        chips: [
          ClarifyChip.kind(_t('⏰ Reminder', '⏰ Paalala'), DraftKind.reminder),
          ClarifyChip.kind(_t('✅ Task', '✅ Gawain'), DraftKind.task),
          const ClarifyChip.kind('📝 Note', DraftKind.note),
          if (memory) ClarifyChip.kind(_t('💜 Remember', '💜 Tandaan'), DraftKind.memory),
          ClarifyChip.skip(_t('✖ Never mind', '✖ Wala')),
        ],
      );

  /// Pinili na ng user ang uri → gawin ang card mula sa orihinal na mensahe.
  /// (Card pa rin — walang nase-save hangga't walang Accept.)
  Future<List<ChatEntry>> draftFor(DraftKind kind, String text, ZoeLanguage lang) async {
    _lang = lang;
    _mood = _moodOf();
    final lower = ChatRouter.clean(text);
    return switch (kind) {
      DraftKind.reminder => [_reminder(text, lower)],
      DraftKind.task => [_task(text, lower)],
      DraftKind.note => [_note(text)],
      DraftKind.memory => await _memory(text),
    };
  }

  /// B6 implicit learning: "Napansin ko, 5 beses… tatandaan ko 'yan." + memory
  /// draft. Ang controller ang nag-a-auto-save (walang card na lalabas).
  List<ChatEntry> habitOffer(HabitSuggestion s, ZoeLanguage lang) {
    _lang = lang;
    _mood = _moodOf();
    final situation = switch (s.habit) {
      Habit.morning => ZoeSituation.habitMorning,
      Habit.evening => ZoeSituation.habitEvening,
    };
    return [
      TextEntry(fromZoe: true, text: _say(situation, {'count': '${s.count}'})),
      ConfirmEntry.memory(MemoryDraft(content: s.memory(lang), habit: s.habit.name)),
    ];
  }

  /// "✖ Wala" / "wag na" sa tanong → maikling sagot, walang card.
  String skipLine(ZoeLanguage lang) {
    _lang = lang;
    return _t("Okay, I won't save anything. 👍", 'Sige, wala akong ise-save. 👍');
  }

  // ───────────────────────── Level 3 Companion memory ─────────────────────────

  /// "Kapag stressed ka, ano'ng nakakatulong?" + chips — isang beses lang
  /// (kahit "✖ Huwag na" ang sagot). null = naitanong na / OFF ang memory.
  Future<ClarifyEntry?> _helpQuestion() async {
    try {
      if (!await _memoryOnSafe() || await _helpAsked()) return null;
      await _markHelpAsked();
    } catch (_) {
      return null; // pumalya ang settings → huwag nang magtanong
    }
    return ClarifyEntry(
      question: _sayFor(CompanionSituation.helpAsk),
      asksHelp: true,
      chips: [
        ClarifyChip.help(_t('🎧 Listen', '🎧 Makinig'), StressHelp.listen.value),
        ClarifyChip.help(_t('💡 Advice', '💡 Payo'), StressHelp.advice.value),
        ClarifyChip.help(_t('😄 Cheer me up', '😄 Pampagaan'), StressHelp.lighten.value),
        ClarifyChip.skip(_t('✖ Never mind', '✖ Huwag na')),
      ],
    );
  }

  /// Linya pagkatapos ma-save ang memory (Accept o chip), ayon sa uri.
  /// Nickname → "{name} na ang itatawag ko sa'yo." (ang BAGONG nickname).
  Future<String> savedLine(FactRead fact, ZoeLanguage lang) async {
    _lang = lang;
    _profile = await _profileSafe();
    await CompanionLines.ensureLoaded();
    switch (fact.kind) {
      case FactKind.nickname:
        return CompanionLines.pick(lang, CompanionSituation.nickSaved,
            style: _profile.style, name: fact.value);
      case FactKind.style:
        return _sayFor(CompanionSituation.styleSaved, style: TalkStyle.fromValue(fact.value));
      case FactKind.stressHelp:
        final help = StressHelp.fromValue(fact.value);
        return _sayFor(help == null ? CompanionSituation.factSaved : CompanionLines.savedFor(help));
      case FactKind.win:
        return _sayFor(CompanionSituation.winSaved);
      case FactKind.routine:
        return _sayFor(CompanionSituation.routineSaved);
      case FactKind.general:
        return _sayFor(CompanionSituation.factSaved);
    }
  }

  /// "✖ Huwag na" sa stress-help na tanong.
  Future<String> helpSkipLine(ZoeLanguage lang) async {
    _lang = lang;
    _profile = await _profileSafe();
    await CompanionLines.ensureLoaded();
    return _sayFor(CompanionSituation.helpSkip);
  }

  // ───────────────────────── Writes (cards) ─────────────────────────

  ChatEntry _reminder(String text, String lower) {
    final time = parseTime(lower);
    var day = _day(lower);
    // May oras pero walang araw → today, o bukas kung lumipas na ang oras.
    if (day == null && time != null) {
      final later = ZoeDate.combine(_today0, time).isAfter(_now());
      day = later ? _today0 : _daysAgo(-1);
    }
    var title = _cleanTitle(text);
    // "wake me up at 6am" → walang natirang title, pero malinaw ang ibig sabihin.
    if (title.isEmpty && lower.contains('wake me')) title = 'Wake up';
    if (title.isEmpty && lower.contains('gising')) title = _t('Wake up', 'Gumising');
    return completeReminder(ReminderDraft(title: title, date: day, time: time));
  }

  /// Kulang ang title → itanong. Kulang ang oras → chips. Kumpleto → card.
  ChatEntry completeReminder(ReminderDraft d) {
    if (d.title.isEmpty) {
      return ClarifyEntry(
        question: _say(ZoeSituation.askReminderTitle),
        reminder: d,
      );
    }
    if (d.time == null) {
      return ClarifyEntry(
        question: _say(ZoeSituation.askTime),
        reminder: d.copyWith(date: d.date ?? _daysAgo(-1)),
        chips: [
          const ClarifyChip('8 AM', TimeOfDay(hour: 8, minute: 0)),
          const ClarifyChip('12 PM', TimeOfDay(hour: 12, minute: 0)),
          const ClarifyChip('7 PM', TimeOfDay(hour: 19, minute: 0)),
          ClarifyChip(_t('Other', 'Iba pa'), null),
        ],
      );
    }
    return ConfirmEntry.reminder(d.copyWith(date: d.date ?? _today0));
  }

  ChatEntry _task(String text, String lower) {
    final time = parseTime(lower);
    final draft = TaskDraft(
      title: _cleanTitle(text),
      date: _day(lower) ?? (time == null ? null : _today0), // may oras → today
      time: time,
    );
    if (draft.title.isEmpty) {
      return ClarifyEntry(
        question: _say(ZoeSituation.askTaskTitle),
        task: draft,
      );
    }
    return ConfirmEntry.task(draft);
  }

  /// Memory card. OFF ang long-term memory → paliwanag + note card na lang.
  Future<List<ChatEntry>> _memory(String text) async {
    final display = TextNormalizer.normalize(text, forDisplay: true);
    // Level 3: nickname / style / stress help → malinaw na salita sa card
    // ("Tawagin akong AC"). Iba pa → ang sinabi ng user.
    final fact = CompanionFacts.read(display);
    final content = CompanionFacts.cardText(fact, tagalog: _lang != ZoeLanguage.english) ??
        MemoryRules.extract(display);
    if (content.isEmpty) return [_note(text)];
    if (!await _memoryOnSafe()) {
      return [
        TextEntry(fromZoe: true, text: _say(ZoeSituation.memoryOff)),
        ConfirmEntry.note(NoteDraft(content: content)),
      ];
    }
    return [ConfirmEntry.memory(MemoryDraft(content: content))];
  }

  ChatEntry _note(String text) {
    // "i-note mo: abc" → kunin ang nasa likod ng ":" kung meron.
    // Hindi kasama ang ":" ng oras ("5:30").
    final colon = text.indexOf(RegExp(r':(?!\d\d)'));
    var content = colon >= 0 ? text.substring(colon + 1) : text;
    if (colon < 0) {
      for (final p in [
        r'\bzoe\b[,]?',
        r'^\s*((hey|hi|hello|uy|oy|yo|beh|ok|okay|sige|please|pls)[\s,!.]+)+',
        r'\b(pa-?|paki-?)?(i-?save|i-?note|save|note)\s+(mo|nga)(\s+(nga|ito|to|lang|this))*(\s+as\s+(a\s+)?note)?\b',
        r'\b(pa|paki)-?(note|save)\b(\s+(nga|mo|lang))*',
        r'\b(save|add)\s+(this\s+|it\s+)?(as\s+)?(a\s+)?(new\s+)?note\b',
        r'\bnote\s+(this|it)\b',
        r'\bnew\s+note\b',
        r'\b(paki[\s-]?)?tandaan\s+mo(\s+(ito|to))?(\s+na)?\b',
        r'\b(write|jot)\s+(this|it|that)\s+down\b',
        r'\bremember\s+(that|this)\b',
        r'\b(keep|save)\s+(this|it)(\s+for\s+me)?\b',
        r'\btake\s+note(\s+(that|of))?\b',
        r'\b(isulat|i-?lista)\s+mo(\s+(nga|ito|to))*(\s+na)?\b',
      ]) {
        content = content.replaceAll(RegExp(p, caseSensitive: false), ' ');
      }
    }
    content = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    content = content.replaceAll(RegExp(r'^[\s,.:;-]+'), '');

    final draft = NoteDraft(content: content);
    if (content.isEmpty) {
      return ClarifyEntry(
        question: _say(ZoeSituation.askNote),
        note: draft,
      );
    }
    return ConfirmEntry.note(draft);
  }

  // ───────────────────────── Reads (answer cards) ─────────────────────────
  // Deterministic code ang nagbabasa ng SQLite — ganito rin sa Memory Engine.

  /// "ano locker code ko?" → Retriever (notes + memories, FTS4).
  /// Ang note / memory mismo ang ipinapakita — walang iniimbento si Zoe.
  /// Rows = mga source (hanggang 3), napipindot para buksan.
  ///
  /// R2: sigurado → "Ito ang nakita ko…" · hindi sigurado → "Baka ito? 🤔 …"
  /// (parehong source at rows; ang linya lang ang nag-iiba) · wala → tapat
  /// na "wala akong nakita".
  ///
  /// [words] (B6) = mga salitang pinili ni Qwen MULA sa mensahe ("gamot, mama").
  /// Iyon ang hahanapin; kapag wala, ang buong tanong ulit.
  Future<ChatEntry> _searchNotes(String lower, {List<String> words = const []}) async {
    final useMemories = await _memoryOnSafe();
    Future<List<RetrievalHit>> find(String q) async {
      try {
        return await _retriever.search(q, includeMemories: useMemories, limit: 3);
      } catch (_) {
        return const [];
      }
    }

    var query = words.isEmpty ? lower : words.join(' ');
    var hits = await find(query);
    if (hits.isEmpty && words.isNotEmpty) {
      query = lower;
      hits = await find(lower);
    }

    if (hits.isEmpty) {
      // B6: para makita sa Developer kung anong tanong ang pumapalya (RAM lang).
      SearchMisses.record(lower);
      return AnswerEntry(
        assumption: words.isEmpty
            ? _t('Searched your notes', 'Hinanap sa notes mo')
            : _t('Searched your notes for: ${words.join(', ')}',
                'Hinanap sa notes mo: ${words.join(', ')}'),
        text: _say(ZoeSituation.noteNotFound),
      );
    }

    final top = hits.first;
    final best = top.doc;
    // R3: ang linyang tumama lang (naka-bold ang mga salita ng tanong),
    // hindi na ang unang 300 letra ng buong note.
    final snip = Snippet.of(best.text, query);
    final ZoeSituation line;
    if (best.isMemory) {
      line = top.isSure ? ZoeSituation.memoryFound : ZoeSituation.memoryMaybe;
    } else {
      line = top.isSure ? ZoeSituation.noteFound : ZoeSituation.noteMaybe;
    }
    final text = _say(line, best.isMemory ? {'memory': snip.text} : {'note': snip.text});
    // Nasa dulo ng linya ang {note} / {memory} → doon ang bold.
    final at = snip.isEmpty ? -1 : text.lastIndexOf(snip.text);
    return AnswerEntry(
      assumption: best.isMemory
          ? _t('From what you told me', 'Galing sa sinabi mo sa akin')
          : _t('From your notes', 'Galing sa notes mo'),
      text: text,
      bold: at < 0 ? const [] : snip.shift(at).bold,
      more: snip.partial && !best.isMemory
          ? AnswerLink(_t('Full note →', 'Buong note →'), '/notes/edit/${best.id}')
          : null,
      rows: [for (final h in hits) _sourceRow(h.doc)],
    );
  }

  /// "📝 Wifi · Nov 18" → bubukas ang note. "💜 Mas gusto ko… · Nov 2" → hindi
  /// napipindot (walang listahan ng memories sa app — ON/OFF lang sa Settings).
  AnswerRow _sourceRow(RetrievalDoc d) => AnswerRow(
        d.isMemory ? AnswerTone.memory : AnswerTone.note,
        '${d.title} · ${ZoeDate.short(d.updatedAt)}',
        route: d.isMemory ? null : '/notes/edit/${d.id}',
      );

  /// Memory Recall (code, walang Qwen). OFF ang long-term memory / pumalya → null.
  Future<RecallHit?> _recall(String lower) async {
    try {
      if (!await _memoryOnSafe()) return null;
      return MemoryRecall.check(lower, await _memoriesOf());
    } catch (_) {
      return null;
    }
  }

  /// Long-term memory ON? Kapag pumalya ang database → OFF (ligtas).
  Future<bool> _memoryOnSafe() async {
    try {
      return await _memoryOn();
    } catch (_) {
      return false;
    }
  }

  /// "89+9", "what is 12 x 3?", "100 / 8" → "100 ÷ 8 = 12.5". null = hindi math.
  String? _math(String lower) {
    final m = RegExp(
      r"^(?:(?:what is|what's|ano ang|magkano ang|ilan ang)\s+)?"
      r'(-?\d+(?:\.\d+)?)\s*([+\-*/x×÷])\s*(-?\d+(?:\.\d+)?)\s*[=?]*$',
    ).firstMatch(lower);
    if (m == null) return null;

    final a = double.parse(m.group(1)!);
    final b = double.parse(m.group(3)!);
    final op = m.group(2)!;
    double result;
    String sign;
    if (op == '+') {
      result = a + b;
      sign = '+';
    } else if (op == '-') {
      result = a - b;
      sign = '−';
    } else if (op == '/' || op == '÷') {
      if (b == 0) return _say(ZoeSituation.mathDivideByZero);
      result = a / b;
      sign = '÷';
    } else {
      result = a * b; // *, x, ×
      sign = '×';
    }
    return '${_num(a)} $sign ${_num(b)} = ${_num(result)}';
  }

  /// 98.0 → "98", 12.5 → "12.5", 0.333333 → "0.3333".
  String _num(double n) {
    if (n == n.roundToDouble() && n.abs() < 1e15) return n.round().toString();
    return n.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');
  }

  /// Ano ang naka-schedule sa [day] (today, bukas, o "sa Sabado").
  Future<ChatEntry> _scheduleOn(DateTime day) async {
    final isToday = ZoeDate.sameDay(day, _today0);
    final label = ZoeDate.pretty(day);
    final reminders = await _reminders.getForDay(day);
    final tasks = (await _tasks.getAll()).where((t) => t.date == ZoeDate.key(day)).toList();
    final pending = tasks.where((t) => !t.isDone).toList();
    final done = tasks.length - pending.length;

    final names = [
      ...pending.take(3).map((t) => t.title),
      ...reminders.take(2).map((r) => r.title),
    ];
    final items = names.join(', ');
    final String text;
    if (isToday) {
      text = names.isEmpty
          ? _say(ZoeSituation.todayFree)
          : _say(ZoeSituation.todayList, {'items': items});
    } else {
      text = names.isEmpty
          ? _say(ZoeSituation.dayFree, {'day': label})
          : _say(ZoeSituation.dayList, {'day': label, 'items': items});
    }

    return AnswerEntry(
      assumption: isToday ? 'Assuming today, $label' : 'Assuming $label',
      text: text,
      rows: [
        if (pending.isNotEmpty)
          AnswerRow(AnswerTone.event, '${pending.length} ${_plural(pending.length, 'task')} to do'),
        if (done > 0) AnswerRow(AnswerTone.done, '$done ${_plural(done, 'task')} completed'),
        if (reminders.isNotEmpty)
          AnswerRow(
            AnswerTone.reminder,
            '${reminders.length} ${_plural(reminders.length, 'reminder')}'
            ' · ${ZoeDate.prettyTime(ZoeDate.parseTime(reminders.first.time))}',
          ),
      ],
    );
  }

  /// "ano ginawa ko kahapon / last week / this month?" — galing sa HISTORY:
  ///   tasks     → completion_history (kasama ang na-delete na task)
  ///   reminders → reminder_occurrences na 'done' sa saklaw
  ///               (kaya kasama pa rin ang daily reminder kahit na-done ulit ngayon)
  /// [withMissed] = "ano mga tasks ko kahapon?" → may rows din ng na-miss.
  Future<ChatEntry> _doneIn(HistoryRange range, {bool withMissed = false}) async {
    final tasks = await _tasks.getCompleted(from: range.from, to: range.to);
    final reminders = await _reminders.getOccurrences(
      from: range.from,
      to: range.to,
      status: OccurrenceStatus.done,
    );
    final items = <(String, String)>[
      for (final t in tasks) (ZoeDate.key(t.completedAt), t.title),
      for (final o in reminders) (o.day, o.title),
    ];
    final names = _unique(_newestFirst(items));

    var missedTasks = 0;
    var missedReminders = 0;
    if (withMissed) {
      missedTasks = (await _tasks.getMissed(
              from: ZoeDate.key(range.from), to: ZoeDate.key(range.to)))
          .length;
      missedReminders = (await _reminders.getOccurrences(
              from: range.from, to: range.to, status: OccurrenceStatus.missed))
          .length;
    }

    final String text;
    if (range.isSingleDay) {
      text = names.isEmpty
          ? _say(ZoeSituation.doneNone)
          : _say(ZoeSituation.doneList, {'items': _listOf(names)});
    } else {
      final span = _span(range);
      text = names.isEmpty
          ? _say(ZoeSituation.doneRangeNone, {'range': span})
          : _say(ZoeSituation.doneRangeList, {'range': span, 'items': _listOf(names)});
    }

    return AnswerEntry(
      assumption: _rangeChip(range),
      text: text,
      rows: [
        if (tasks.isNotEmpty)
          AnswerRow(AnswerTone.done, '${tasks.length} ${_plural(tasks.length, 'task')} completed'),
        if (reminders.isNotEmpty)
          AnswerRow(AnswerTone.reminder,
              '${reminders.length} ${_plural(reminders.length, 'reminder')} done'),
        if (missedTasks > 0)
          AnswerRow(AnswerTone.missed, '$missedTasks missed ${_plural(missedTasks, 'task')}'),
        if (missedReminders > 0)
          AnswerRow(AnswerTone.missed,
              '$missedReminders missed ${_plural(missedReminders, 'reminder')}'),
      ],
    );
  }

  /// "ano na-miss ko (last week)?" — tasks + reminders sa saklaw.
  /// Default: huling [missedDays] araw (kasama ngayon). Galing sa HISTORY:
  ///   tasks     → task_history na 'missed'
  ///   reminders → reminder_occurrences na 'missed' (mga lumipas na araw)
  ///               + ngayong araw (kung kasama sa saklaw): lumipas na ang oras,
  ///               walang Done / Dismiss / Snooze (parehong patakaran ng Home)
  Future<ChatEntry> _missedIn(HistoryRange range) async {
    final now = _now();
    final today = _today0;
    final yesterday = _daysAgo(1);

    var active = const <int, DateTime>{};
    try {
      active = await _activeAlarms();
    } catch (_) {
      active = const {};
    }
    // I-record muna ang mga bagong missed (gaya ng Home / History screen).
    // Kapag pumalya, tuloy pa rin — babasahin ang naka-record na.
    try {
      await _reminders.recordMissed(pending: active, now: now);
      await _tasks.recordMissed(now: now);
    } catch (_) {}

    // (araw, title) — para maayos mula pinakabago.
    final items = <(String, String)>[];

    final tasks =
        await _tasks.getMissed(from: ZoeDate.key(range.from), to: ZoeDate.key(range.to));
    for (final row in tasks) {
      items.add((row['day'] as String, row['title'] as String));
    }

    var reminderCount = 0;
    final pastTo = range.to.isBefore(yesterday) ? range.to : yesterday;
    if (!pastTo.isBefore(range.from)) {
      final past = await _reminders.getOccurrences(
        from: range.from,
        to: pastTo,
        status: OccurrenceStatus.missed,
      );
      reminderCount += past.length;
      for (final o in past) {
        items.add((o.day, o.title));
      }
    }

    if (!range.to.isBefore(today) && !range.from.isAfter(today)) {
      for (final r in await _reminders.getForDay(today)) {
        final at = ReminderStatusRules.occurrenceTime(r, today);
        final pendingAt = active[r.id];
        final alarmPending = pendingAt != null && _sameMinute(pendingAt, at);
        final status =
            ReminderStatusRules.statusOn(r, today, now: now, alarmPending: alarmPending);
        if (status == ReminderStatus.missed) {
          reminderCount++;
          items.add((ZoeDate.key(today), r.title));
        }
      }
    }

    // Pinakabago muna. Isang beses lang bawat title sa text.
    final names = _unique(_newestFirst(items));

    return AnswerEntry(
      assumption: _rangeChip(range),
      text: names.isEmpty
          ? _say(ZoeSituation.missedNone)
          : _say(ZoeSituation.missedList, {'items': _listOf(names)}),
      rows: [
        if (tasks.isNotEmpty)
          AnswerRow(AnswerTone.missed, '${tasks.length} missed ${_plural(tasks.length, 'task')}'),
        if (reminderCount > 0)
          AnswerRow(AnswerTone.missed,
              '$reminderCount missed ${_plural(reminderCount, 'reminder')}'),
      ],
    );
  }

  /// Isang araw → "Assuming Nov 17, 2026".
  /// Ilang araw → "Huling 7 araw (Nov 12–Nov 18)" / "Last week (Nov 9–Nov 15)".
  String _rangeChip(HistoryRange r) {
    if (r.isSingleDay) return 'Assuming ${ZoeDate.pretty(r.from)}';
    return '${_t(r.en, r.tl)} (${_span(r)})';
  }

  /// "Nov 9–Nov 15"
  static String _span(HistoryRange r) => '${ZoeDate.short(r.from)}–${ZoeDate.short(r.to)}';

  /// Hanggang 4 na pangalan; ang iba ay "at 3 pa" / "and 3 more".
  String _listOf(List<String> names) {
    final shown = names.take(4).join(', ');
    final more = names.length - 4;
    if (more <= 0) return shown;
    return '$shown${_t(' and $more more', ' at $more pa')}';
  }

  /// Pinakabagong araw muna; pareho ang araw → pareho ang dating ayos.
  static List<String> _newestFirst(List<(String, String)> items) {
    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
    indexed.sort((a, b) {
      final byDay = b.$2.$1.compareTo(a.$2.$1);
      return byDay != 0 ? byDay : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2.$2];
  }

  // ───────────────────────── Helpers ─────────────────────────

  DateTime _now() => _clock();
  DateTime get _today0 => ZoeDate.dayOnly(_now());

  /// [n] araw bago ngayon (negative = mga araw pagkatapos: -1 = bukas).
  DateTime _daysAgo(int n) => DateTime(_today0.year, _today0.month, _today0.day - n);
  String _plural(int n, String word) => n == 1 ? word : '${word}s';

  /// Walang ulit, pareho ang pagkakasunod.
  static List<String> _unique(Iterable<String> names) => names.toSet().toList();

  static bool _sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  /// Araw sa mensahe ("bukas", "sa Biyernes", "sa susunod na linggo"…). Tingnan ang WhenParser.
  DateTime? _day(String lower) => WhenParser.day(lower, now: _now());

  /// "7 PM", "7:30pm", "alas 7 ng gabi", "19:00", "noon" → TimeOfDay.
  /// (Ginagamit din ng ZoeChatController sa chips na "Iba pa".)
  TimeOfDay? parseTime(String lower) => WhenParser.time(lower);

  /// Araw sa sagot ng user ("bukas na lang", "sa Sabado") — para sa pagtatama.
  DateTime? parseDay(String lower) => _day(lower);

  /// Ngayon (para sa ContextReplies sa controller).
  DateTime get now => _now();

  /// "Zoe, remind me tomorrow at 7 PM to review my thesis" → "Review my thesis"
  String _cleanTitle(String text) {
    // "pls rmnd me 2mrw" → "please remind me tomorrow" bago tanggalin ang mga utos.
    var s = TextNormalizer.normalize(text, forDisplay: true)
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]|[:;]-?[)(DP]', unicode: true), ' ');
    for (final p in [
      r'\bzoe\b[,:!]?',
      r'\b(paki[\s-]?)?tandaan\s+mo\b[,:]?',
      // Pambungad: "uy", "hey", "can you", "pwede mo bang", "i want you to"…
      r'^\s*((hey|hi|hello|uy|oy|yo|beh|ok|okay|sige|please)[\s,!.]+)+',
      r'\b(can|could|would|will)\s+(you|u)(\s+please)?\b',
      r'\b(pwede|puwede)\s+(mo|ka)\s+ba(ng)?(\s+(akong|ako))?\b',
      r"\b(i\s+(want|need)\s+you\s+to|need\s+you\s+to)\b",
      r'\b(paki[\s-]?|ipa[\s-]?|pa[\s-]?|i[\s-]?)?remind(\s+(mo|naman|nga|nmn|po))*\s+(me|ako|ko|us|kami)\b',
      r'\bremind\s+mo\b',
      r'\bparemind(\s+(naman|nga|po))*(\s+(ako|me|kami))?\b',
      r'\b(make|create|add|new|gumawa|gawa)(\s+(ka|mo|nga|naman))*(\s+(an?|the|ng))?\s+(reminder|alarm|paalala)\b',
      r'\b(set|mag-?set|i-?set|pa-?set|paki[\s-]?set)(\s+(ka|mo|naman|po|nga))*(\s+(ng|an?|the|my))?\s+(alarm|reminder|paalala)\b',
      r'\b(mag|i)-?alarm(\s+ka)?\b',
      r'\b(magtakda|itakda)\s+(ng|ang)\s+(pampagising|hudyat|alarm|paalala)(\s+para\s+sa)?\b',
      r'\b(paki[\s-]?)?gising(in)?\s+mo\s+(ako|ko|kami)\b',
      r'\b(alert)\s+me\b',
      r'^\s*(paalala|reminder|remind)\b[:]?',
      r'\b(please\s+)?wake\s+me(\s+up)?\b',
      r'\b(paki[\s-]?)?gisingin\s+mo\s+(ako|ko)\b',
      r'\b(paki[\s-]?)?(sabihan|abisuhan|i-?alert)\s+mo\s+(ako|ko)\b',
      r"\bdon'?t\s+let\s+me\s+forget\b",
      r'\b(huwag|wag)\s+mo(ng)?\s+(ko(ng)?\s+|akong\s+)?kalimutan(g)?'
          r'(\s+(sabihan|paalalahanan|ipaalala|i-?remind))?(\s+(ako|ko))?\b',
      r"\b(i\s+need\s+to|i\s+have\s+to|i\s+got\s+to|i'?ve\s+got\s+to|i\s+must|i\s+should|i\s+gotta)\b",
      r'\b(kailangan|kelangan|need)\s+ko(ng)?\b',
      r'\bdapat\s+(ko(ng)?|akong)\b',
      r'\b(pa)?gawan\s+mo\s+(ako|ko)(\s+ng)?\b',
      r'\b(ang\s+)?title\s*(ay|is|:)?',
      r'\b(time|oras)\s*(ay|is|:)?\s*(?=\d)',
      '\\b(on|sa|ng|noong)?\\s*${WhenParser.monthDatePattern}',
      r'\b(pa)?paalala(han|hanan)?\s+mo(\s+(naman|nga|po))*\s+(ako|ko|kami|sakin|sa\s+akin)\b',
      // "ngayong gabi", "mamayang hapon" (bago ang "ngayon" / "mamaya")
      r'\b(ngayong|mamayang|nitong)\s+(gabi|umaga|hapon|tanghali)\b',
      r'\bipaalala\s+mo(\s+sa\s+akin)?\b',
      r'\bset\s+(an?\s+)?(alarm|reminder)\b',
      r'\b(add|create|new)\s+(an?\s+)?(task|todo|to-do)\b',
      // "add X to my tasks", "lagay mo sa tasks ko: X", "pakilagay sa gawain ko na X"
      r'\b(to|in|on)\s+(my|the)\s+(tasks?|to-?dos?|to-?do\s+list|list)\b',
      r'\b(sa|ng)\s+(listahan\s+ng\s+)?(tasks?|to-?dos?|gawain|listahan)(\s+(ko|natin))?\b',
      r'\b(add|i-?add|pa-?add|paki-?add|isama|(paki-?)?lagay|ilagay|(paki-?)?dagdag|idagdag)'
          r'(\s+(mo|nga|naman|po|this|it))*\b',
      r'\b(task|tasks|todo|to-do|gawain)\b[:]?',
      // "\b" pagkatapos ng am/pm: ang "5 ampalaya" ay hindi oras.
      r'\b((at|by|sa|ng|mga)\s+)*\d{1,2}(:\d{2})?\s*(am\b|pm\b|a\.m\.|p\.m\.)',
      // "5 ng hapon", "alas 3 ng madaling araw"
      r'\b((at|sa|mga)\s+)?(alas[\s-]*)?\d{1,2}(:\d{2})?\s+(ng|sa)\s+(umaga|tanghali|hapon|gabi|madaling[\s-]?araw)\b',
      r'\b(at|sa)?\s*alas[\s-]*\d{1,2}(:\d{2})?',
      r'\b(at|by)?\s*([01]?\d|2[0-3]):[0-5]\d\b',
      r'\bng\s+(umaga|gabi|hapon|tanghali|madaling[\s-]?araw)\b',
      r'\b(at\s+)?(midnight|hatinggabi|hating-gabi)\b',
      r'\b(at\s+)?(noon|tanghali)\b',
      // "sa susunod na linggo" / "next week" — linggo = week, hindi Sunday
      r'\b(sa\s+)?(susunod|sunod|darating)\s+na\s+linggo\b',
      r'\b(ngayong|nitong)\s+linggo\b',
      r'\b(next|this)\s+week\b',
      r'\b(tomorrow|bukas|kinabukasan|today|ngayon|ngayong|mamaya|mamayang|tonight|later)\b',
      r'\b(on|by|sa|this|next)?\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday|lunes|martes|miyerkules|huwebes|biyernes|sabado|linggo)\b',
    ]) {
      s = s.replaceAll(RegExp(p, caseSensitive: false), ' ');
    }
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // pampalambot sa hulihan: "please", "po", "naman", "ha", "thanks", "asap"…
    final tail = RegExp(
        r'[\s,]*\b(please|po|naman|nga|ha|lang|thanks|thank you|salamat|asap|for me|sa akin|sakin)\b[\s.!?]*$',
        caseSensitive: false);
    while (tail.hasMatch(s)) {
      s = s.replaceFirst(tail, '');
    }
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // tanggalin ang "to", "na", "ng", "mga", "para", bantas sa unahan / hulihan
    s = s.replaceFirst(
        RegExp(r'^[\s,.:;!?-]*((to|na|ng|mga|para|that|about|yung|ang|sa|for|po|naman|nga|please|ako|me)\s+)+',
            caseSensitive: false),
        '');
    s = s.replaceAll(RegExp(r'^[\s,.:;!?-]+|[\s,.:;!?-]+$'), '');
    if (s.isEmpty) return '';
    final title = s[0].toUpperCase() + s.substring(1);
    return title.length > 100 ? title.substring(0, 100) : title;
  }
}

/// Emoji sa card (display lang, hindi sine-save sa title).
String draftEmoji(String title, DraftKind kind) {
  final l = title.toLowerCase();
  bool has(List<String> w) => w.any(l.contains);
  if (has(['thesis', 'study', 'aral', 'review', 'exam', 'chapter'])) return '📚';
  if (has(['gamot', 'medicine', 'vitamin', 'pill'])) return '💊';
  if (has(['grocery', 'groceries', 'palengke', 'buy', 'bili'])) return '🛒';
  if (has(['meeting', 'call', 'tawag', 'zoom'])) return '📞';
  if (has(['workout', 'gym', 'run', 'exercise', 'takbo'])) return '🏃';
  if (has(['bayad', 'pay', 'bill', 'rent'])) return '💳';
  if (has(['birthday', 'bday', 'kaarawan'])) return '🎂';
  return switch (kind) {
    DraftKind.reminder => '🔔',
    DraftKind.task => '✅',
    DraftKind.note => '📝',
    DraftKind.memory => '💜',
  };
}