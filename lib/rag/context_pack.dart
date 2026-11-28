import 'dart:math' as math;

import 'package:zoe_remind/ai/parser/crisis_guard.dart';
import 'package:zoe_remind/database/models/memory_item.dart';
import 'package:zoe_remind/features/companion/controllers/tone_detector.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/features/companion/models/user_tone.dart';
import 'package:zoe_remind/memory/companion_facts.dart';
import 'package:zoe_remind/memory/companion_profile.dart';
import 'package:zoe_remind/memory/memory_recall.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';
import 'package:zoe_remind/rag/search_scope.dart';
import 'package:zoe_remind/rag/snippet.dart';
import 'package:zoe_remind/rag/stemmer.dart';

/// R7 — Context Pack: ang "kodigo" na iaabot kay Qwen bago siya sumagot (Z2).
///
///   Mensahe: "pagod na ako sa trabaho, may meeting pa bukas"
///
///   [u] name: AC · style: diretso · stress: listen
///   [m1] Ayoko ng maagang meeting
///   [mood] user: tired 1 · zoe: gentle
///   [s1] reminder · Meeting kay boss · tomorrow 09:00 (unsure)
///
/// Laman lang ang TOTOONG facts mula sa phone, at bawat isa ay may id
/// (u, m1, m2, mood, s1) para masuri ng Sandbox sa Z2 kung may inimbento si
/// Qwen. English ang labels (mas naiintindihan ni Qwen); ang laman ay kung
/// ano mismo ang sinabi / sinulat ng user (EN / TL / Taglish).
///
/// Mga bahagi:
///   • u    — nickname + style (CompanionProfile). "stress" (ano'ng
///            nakakatulong) kapag down lang ang tono ng user.
///   • m1/m2 — memories na MAY KINALAMAN sa mensahe (parehong salita / ugat /
///            synonym / natutunang salita, o tugma ng Memory Recall), inaayos
///            ayon sa dami ng tumama tapos sa [memoryStrength]. Walang
///            kinalaman → walang m (hindi biglang babanggitin ang random na
///            memory). Hindi kasama ang nickname / style / stress_help (nasa u).
///            Down ang user + may "win" → isinasama ang pinakamalakas na win
///            kahit hindi tugma ang salita (paalala na kaya niya).
///   • mood — tono ng user (ToneDetector) + mood ni Zoe (MoodNow). Laging kasama.
///   • s1   — unang note / reminder / task na nahanap ng Retriever (hindi
///            memory), snippet lang. "Baka ito?" → may "(unsure)".
///
/// Budget: ≤ [maxTokens] (tantiya: letra ÷ 3). Kapag sobra, sa ganitong order:
/// paikliin ang s1 → alisin ang m2 → alisin ang stress → paikliin ang m1 →
/// (huling hakbang, halos hindi mangyari) alisin ang s1 → alisin ang m1.
/// Ang mood ay hindi kailanman inaalis.
///
/// Mga bantay:
///   • CrisisGuard tumama → [ContextPack.crisis] (blocked: walang pack, walang Qwen).
///   • OFF ang long-term memory → walang u at m.
///   • Hindi nagdadagdag ng use_count ang pack. Sa Z2 lang, kapag talagang
///     binanggit ni Zoe ang memory ([PackFact.ref] ang gagamitin).
///
/// Pure (walang database) → `flutter test test/rag/context_pack_test.dart`.
/// Ang [ContextPackBuilder] (context_pack_builder.dart) ang kumukuha sa phone.
enum PackFactKind { user, memory, mood, snippet }

/// Isang linya ng pack.
class PackFact {
  const PackFact(this.id, this.kind, this.text, {this.ref, this.sure = true});

  /// "u", "m1", "m2", "mood", "s1".
  final String id;
  final PackFactKind kind;

  /// Ang laman, walang "[id]".
  final String text;

  /// Saan galing: 'memory#5', 'note#3', 'reminder#2', 'task#7' (gaya ng
  /// RagLearning.keyOf). null sa u / mood. Para sa Z2: use_count kapag
  /// binanggit, at link pabalik sa item.
  final String? ref;

  /// s1 lang: false = "Baka ito?" (hindi sigurado ang search).
  final bool sure;

  /// "[m1] Allergic ako sa hipon" · "[s1] note · Wifi: … (unsure)".
  String get line => '[$id] $text${sure ? '' : ' (unsure)'}';

  @override
  String toString() => line;
}

class ContextPack {
  const ContextPack._(this.facts, {this.blocked = false});

  /// Pinakamalaking pack (tantiyang tokens).
  static const maxTokens = 120;

  /// Hanggang ilang memory.
  static const maxMemories = 2;

  /// Haba ng memory (letra) bago paikliin / pagkatapos paikliin.
  static const memoryChars = 90;
  static const shortChars = 50;

  /// Haba ng snippet ng s1 bago paikliin.
  static const snippetChars = 100;

  /// Pinakamahabang title ng note / reminder / task sa s1.
  static const titleChars = 40;

  /// Ilang araw na "bago pa" ang memory (para sa [memoryStrength]).
  static const recentDays = 30;

  /// Crisis na mensahe — walang pack. Script + hotline lang (CrisisGuard).
  static const crisis = ContextPack._([], blocked: true);

  /// Mga linya, ganitong order: u, m1, m2, mood, s1.
  final List<PackFact> facts;

  /// true = crisis; hindi dapat tawagin si Qwen.
  final bool blocked;

  bool get isEmpty => facts.isEmpty;

  /// Mga id na nasa pack (para sa Sandbox).
  List<String> get ids => [for (final f in facts) f.id];

  /// Ang fact na may [id], o null.
  PackFact? fact(String id) {
    for (final f in facts) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Ang ibibigay kay Qwen. Walang laman kapag blocked.
  String toPrompt() => facts.map((f) => f.line).join('\n');

  /// Tantiyang tokens ng [toPrompt].
  int get tokens => estimateTokens(toPrompt());

  @override
  String toString() => blocked ? 'ContextPack.blocked' : toPrompt();

  /// Konserbatibong tantiya: letra ÷ 3 (Tagalog ay mas maraming token bawat
  /// salita kaysa English sa tokenizer ni Qwen).
  static int estimateTokens(String text) => text.isEmpty ? 0 : (text.length / 3).ceil();

  /// Lakas ng memory (R6): kahalagahan (1–5) + log(1 + use_count) + "bago pa"
  /// (0–1, mula sa last_used_at, o updated_at kung hindi pa nagamit, sa loob
  /// ng [recentDays] araw).
  static double memoryStrength(MemoryItem m, DateTime now) {
    final last = m.lastUsedAt ?? m.updatedAt;
    final days = now.difference(last).inDays.clamp(0, recentDays);
    final recent = (recentDays - days) / recentDays;
    return m.importance + math.log(1 + math.max(0, m.useCount)) + recent;
  }

  // ───────────────────────────── build ─────────────────────────────

  /// Buuin ang pack para sa [message].
  ///
  /// [memories] = lahat ng memories (MemoryRepository.getAll, pinakabago
  /// muna). [memoryOn] = false → hindi ginagamit (walang u / m).
  /// [tone] = null → ToneDetector.detect([message]).
  /// [hits] = galing sa Retriever (gamit ang [searchQuery]); ang unang hindi
  /// memory ang magiging s1.
  /// [learned] = natutunang salita (RagLearning snapshot.synonyms).
  static ContextPack build(
    String message, {
    required DateTime now,
    List<MemoryItem> memories = const [],
    bool memoryOn = true,
    ToneResult? tone,
    MoodState zoeMood = MoodState.content,
    List<RetrievalHit> hits = const [],
    Map<String, List<String>> learned = const {},
    int maxTokens = ContextPack.maxTokens,
  }) {
    if (CrisisGuard.matches(message)) return crisis;

    final t = tone ?? ToneDetector.detect(message);
    final mems = memoryOn ? memories : const <MemoryItem>[];
    final profile = CompanionProfile.from(mems);
    final picked = pickMemories(message, mems, now: now, tone: t, learned: learned);
    final memTerms = termsOf(contentWords(message), learned);
    final searchTerms = termsOf(contentWords(message, drop: toneWords(t)), learned);

    RetrievalHit? top;
    for (final h in hits) {
      if (!h.doc.isMemory) {
        top = h;
        break;
      }
    }

    var snippetMax = snippetChars;
    var memoryMax = memoryChars;
    var keepM2 = true;
    var keepStress = true;
    var keepS1 = true;
    var keepM1 = true;

    ContextPack make() {
      final facts = <PackFact>[];
      final user = _userText(profile, stress: keepStress && t.tone.isDown);
      if (user.isNotEmpty) facts.add(PackFact('u', PackFactKind.user, user));
      final use = [
        if (keepM1 && picked.isNotEmpty) picked[0],
        if (keepM1 && keepM2 && picked.length > 1) picked[1],
      ];
      for (var i = 0; i < use.length; i++) {
        final m = use[i];
        facts.add(PackFact(
          'm${i + 1}',
          PackFactKind.memory,
          _flat(Snippet.build(m.content, memTerms, max: memoryMax).text),
          ref: m.id == null ? null : 'memory#${m.id}',
        ));
      }
      facts.add(PackFact('mood', PackFactKind.mood, _moodText(t, zoeMood)));
      final h = top;
      if (keepS1 && h != null) {
        final text = _hitText(h.doc, searchTerms, now, snippetMax);
        if (text.isNotEmpty) {
          facts.add(PackFact(
            's1',
            PackFactKind.snippet,
            text,
            ref: '${h.doc.source.name}#${h.doc.id}',
            sure: h.isSure,
          ));
        }
      }
      return ContextPack._(List.unmodifiable(facts));
    }

    // Isa-isang hakbang hanggang pumasok sa budget.
    final steps = <void Function()>[
      () => snippetMax = shortChars,
      () => keepM2 = false,
      () => keepStress = false,
      () => memoryMax = shortChars,
      () => keepS1 = false,
      () => keepM1 = false,
    ];
    var pack = make();
    for (final step in steps) {
      if (pack.tokens <= maxTokens) break;
      step();
      pack = make();
    }
    return pack;
  }

  // ─────────────────────────── memories ───────────────────────────

  /// Mga kind na pwedeng maging m1 / m2 (ang nickname / style / stress_help
  /// ay nasa u na).
  static const memoryKinds = {FactKind.general, FactKind.routine, FactKind.win};

  /// Ang mga memory na isasama (hanggang [maxMemories]), pinakamahalaga muna.
  ///   1. may kinalaman: bawat salita ng mensahe na tumama (salita / ugat /
  ///      synonym / natutunang salita) = +1; walang tumama pero tugma sa
  ///      Memory Recall ("lechon" ↔ "Vegetarian ako") = 1.
  ///   2. pantay → mas malakas ([memoryStrength]) → mas bago.
  ///   3. down ang user, may puwang, at walang win na napili → ang
  ///      pinakamalakas na win.
  static List<MemoryItem> pickMemories(
    String message,
    List<MemoryItem> memories, {
    required DateTime now,
    required ToneResult tone,
    Map<String, List<String>> learned = const {},
  }) {
    if (memories.isEmpty) return const [];
    final terms = termsOf(contentWords(message), learned);
    final lower = message.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    final scored = <_Scored>[];
    for (final m in memories) {
      if (!memoryKinds.contains(m.kind)) continue;
      final tokens = QueryTerms.searchTokens(m.content);
      var hits = 0;
      for (final t in terms) {
        if (QueryTerms.groupIn(t, tokens)) hits++;
      }
      if (hits == 0 &&
          lower.isNotEmpty &&
          MemoryRecall.check(lower, [m.content], learned: learned) != null) {
        hits = 1;
      }
      if (hits == 0) continue;
      scored.add(_Scored(m, hits, memoryStrength(m, now)));
    }
    scored.sort((a, b) {
      final h = b.hits.compareTo(a.hits);
      if (h != 0) return h;
      final s = b.strength.compareTo(a.strength);
      if (s != 0) return s;
      return b.item.updatedAt.compareTo(a.item.updatedAt);
    });
    final picked = [for (final s in scored.take(maxMemories)) s.item];

    if (tone.tone.isDown &&
        picked.length < maxMemories &&
        !picked.any((m) => m.kind == FactKind.win)) {
      final wins = [
        for (final m in memories)
          if (m.kind == FactKind.win) _Scored(m, 0, memoryStrength(m, now)),
      ]..sort((a, b) {
          final s = b.strength.compareTo(a.strength);
          if (s != 0) return s;
          return b.item.updatedAt.compareTo(a.item.updatedAt);
        });
      if (wins.isNotEmpty) picked.add(wins.first.item);
    }
    return picked;
  }

  // ─────────────────────────── salita ───────────────────────────

  /// Mga salitang may laman sa [message] (walang "ano", "ko", "bukas",
  /// "gusto"…), kung paano tinype. [drop] = walang tuldik, maliit na titik.
  static List<String> contentWords(String message, {Set<String> drop = const {}}) {
    final out = <String>[];
    for (final w in QueryTerms.rawTokens(message)) {
      final key = QueryTerms.fold(w);
      if (key.length < 2 ||
          QueryTerms.stopWords.contains(key) ||
          Retriever.weakWords.contains(key) ||
          SearchScope.scheduleWords.contains(key) ||
          drop.contains(key)) {
        continue;
      }
      out.add(w);
    }
    return out;
  }

  /// Ang mga salitang tumama sa ToneDetector ("pagod", "walang tulog") —
  /// tinatanggal sa paghahanap ng s1 (nararamdaman, hindi hinahanap).
  static Set<String> toneWords(ToneResult tone) => {
        for (final m in tone.matched) ...QueryTerms.tokens(m),
      };

  /// Ang hahanapin ng Retriever para sa s1: [contentWords] na walang
  /// [toneWords]. Walang laman = walang hahanapin.
  ///   "pagod na ako sa trabaho, may meeting pa bukas" → "trabaho meeting"
  static String searchQuery(String message, {ToneResult? tone}) {
    final t = tone ?? ToneDetector.detect(message);
    return contentWords(message, drop: toneWords(t)).join(' ');
  }

  /// TermGroups ng [words], walang limit na 6 (hinahati sa tig-[QueryTerms.maxTerms])
  /// para hindi mawala ang mga salita sa dulo ng mahabang mensahe.
  static List<TermGroup> termsOf(List<String> words, Map<String, List<String>> learned) {
    final seen = <String>{};
    final out = <TermGroup>[];
    for (var i = 0; i < words.length; i += QueryTerms.maxTerms) {
      final end = math.min(words.length, i + QueryTerms.maxTerms);
      for (final g in QueryTerms.parse(words.sublist(i, end).join(' '), learned: learned)) {
        if (seen.add(Stemmer.stem(QueryTerms.fold(g.word)))) out.add(g);
      }
    }
    return out;
  }

  // ─────────────────────────── mga linya ───────────────────────────

  static String _userText(CompanionProfile p, {required bool stress}) {
    final parts = <String>[
      if (p.nickname != null) 'name: ${p.nickname}',
      if (p.style != null) 'style: ${p.style!.value}',
      if (stress && p.stressHelp != null) 'stress: ${p.stressHelp!.value}',
    ];
    return parts.join(' · ');
  }

  static String _moodText(ToneResult t, MoodState zoe) {
    final user = t.tone == UserTone.neutral || t.strength <= 0
        ? t.tone.name
        : '${t.tone.name} ${t.strength}';
    return 'user: $user · zoe: ${zoe.name}';
  }

  /// "note · Wifi: ZoeHome / pass 1234" · "reminder · Meeting kay boss · tomorrow 09:00"
  /// · "task · Bayaran ang Meralco · 2026-12-03 · done".
  static String _hitText(RetrievalDoc d, List<TermGroup> terms, DateTime now, int max) {
    if (d.isMemory) return '';
    final title = _cut(d.title.trim(), titleChars);
    if (d.isNote) {
      final snip = _flat(Snippet.build(d.text, terms, max: max).text);
      if (snip.isEmpty) return title.isEmpty ? '' : 'note · $title';
      if (title.isEmpty || snip.toLowerCase().startsWith(title.toLowerCase())) {
        return 'note · $snip';
      }
      return 'note · $title: $snip';
    }
    // reminder / task
    final when = whenOf(d, now);
    final body = d.text.trim().isEmpty ? '' : _flat(Snippet.build(d.text, terms, max: max).text);
    return [
      '${d.source.name} · ${title.isEmpty ? '—' : title}',
      if (when.isNotEmpty) when,
      if (body.isNotEmpty) body,
      if (d.done) 'done',
    ].join(' · ');
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Kailan ang reminder / task, maikli:
  ///   "today 09:00" · "tomorrow" · "yesterday 18:30" · "2026-12-03 07:00"
  ///   · "daily 07:00" · "weekly Sat 09:00" · "monthly 15". Wala → "".
  static String whenOf(RetrievalDoc d, DateTime now) {
    final time = d.time?.trim() ?? '';
    final raw = d.date?.trim() ?? '';
    final date = raw.isEmpty ? null : DateTime.tryParse(raw);
    String day;
    switch (d.repeat) {
      case 'daily':
        day = 'daily';
      case 'weekly':
        day = date == null ? 'weekly' : 'weekly ${_weekdays[date.weekday - 1]}';
      case 'monthly':
        day = date == null ? 'monthly' : 'monthly ${date.day}';
      default:
        if (date == null) {
          day = '';
        } else {
          final today = DateTime.utc(now.year, now.month, now.day);
          final that = DateTime.utc(date.year, date.month, date.day);
          day = switch (that.difference(today).inDays) {
            0 => 'today',
            1 => 'tomorrow',
            -1 => 'yesterday',
            _ => raw,
          };
        }
    }
    return [day, time].where((s) => s.isNotEmpty).join(' ');
  }

  /// Isang linya lang (walang "\n" sa pack).
  static String _flat(String s) => s.replaceAll(RegExp(r'\s*\n\s*'), ' / ').trim();

  /// Paikliin sa [max] letra, sa pagitan ng salita, may "…".
  static String _cut(String s, int max) {
    if (s.length <= max) return s;
    var end = s.lastIndexOf(' ', max);
    if (end < max ~/ 2) end = max;
    return '${s.substring(0, end).trimRight()}…';
  }
}

class _Scored {
  const _Scored(this.item, this.hits, this.strength);
  final MemoryItem item;
  final int hits;
  final double strength;
}