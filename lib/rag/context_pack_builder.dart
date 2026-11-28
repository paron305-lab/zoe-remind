import 'package:flutter/foundation.dart';
import 'package:zoe_remind/ai/parser/crisis_guard.dart';
import 'package:zoe_remind/database/models/memory_item.dart';
import 'package:zoe_remind/database/repositories/memory_repository.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/features/companion/controllers/mood_now.dart';
import 'package:zoe_remind/features/companion/controllers/tone_detector.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/rag/context_pack.dart';
import 'package:zoe_remind/rag/rag_learning.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';

/// R7 — kinukuha sa phone ang laman ng [ContextPack]:
///
///   long-term memory ON?  → SettingsRepository
///   memories (+ profile)  → MemoryRepository.getAll (kapag ON lang)
///   natutunang salita     → RagLearning snapshot (R6)
///   s1                    → Retriever.search(ContextPack.searchQuery, walang memories)
///   mood ni Zoe           → MoodNow.current
///
/// Read-only: walang sine-save (walang search_log, walang use_count) — ang
/// pack ay hindi "paggamit" ng memory.
///
/// Bawat source ay may try/catch: pumalya ang DB → mas maliit na pack, hindi
/// crash. Pumalya ang pagbasa ng memory setting → itinuturing na OFF (ligtas).
/// Crisis na mensahe → [ContextPack.crisis] agad, walang binabasa sa DB.
///
/// Sa test: ipasa ang mga fake ([memoryOn], [memories], [learned], [search],
/// [zoeMood], [clock]) — walang database.
class ContextPackBuilder {
  ContextPackBuilder({
    Future<bool> Function()? memoryOn,
    Future<List<MemoryItem>> Function()? memories,
    Future<Map<String, List<String>>> Function()? learned,
    Future<List<RetrievalHit>> Function(String query)? search,
    MoodState Function()? zoeMood,
    DateTime Function()? clock,
  })  : _memoryOn = memoryOn ?? (() => SettingsRepository().isLongTermMemoryOn()),
        _memories = memories ?? (() => MemoryRepository().getAll()),
        _learned = learned ?? (() async => (await RagLearning.instance.snapshot()).synonyms),
        _search = search ??
            ((q) => Retriever().search(q, includeMemories: false, limit: 3)),
        _zoeMood = zoeMood ?? (() => MoodNow.current),
        _clock = clock ?? DateTime.now;

  final Future<bool> Function() _memoryOn;
  final Future<List<MemoryItem>> Function() _memories;
  final Future<Map<String, List<String>>> Function() _learned;
  final Future<List<RetrievalHit>> Function(String query) _search;
  final MoodState Function() _zoeMood;
  final DateTime Function() _clock;

  Future<ContextPack> build(String message) async {
    if (CrisisGuard.matches(message)) return ContextPack.crisis;

    final on = await _safe(_memoryOn, false, 'memoryOn');
    final mems = on ? await _safe(_memories, const <MemoryItem>[], 'memories') : const <MemoryItem>[];
    final learned = await _safe(_learned, const <String, List<String>>{}, 'learned');
    final tone = ToneDetector.detect(message);
    final query = ContextPack.searchQuery(message, tone: tone);
    final hits = query.isEmpty
        ? const <RetrievalHit>[]
        : await _safe(() => _search(query), const <RetrievalHit>[], 'search');

    var mood = MoodState.content;
    try {
      mood = _zoeMood();
    } catch (e) {
      debugPrint('ContextPack mood failed: $e');
    }

    return ContextPack.build(
      message,
      now: _clock(),
      memories: mems,
      memoryOn: on,
      tone: tone,
      zoeMood: mood,
      hits: hits,
      learned: learned,
    );
  }

  static Future<T> _safe<T>(Future<T> Function() f, T fallback, String what) async {
    try {
      return await f();
    } catch (e) {
      debugPrint('ContextPack $what failed: $e');
      return fallback;
    }
  }
}