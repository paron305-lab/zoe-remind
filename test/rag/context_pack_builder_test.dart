import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/database/models/memory_item.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';
import 'package:zoe_remind/memory/companion_facts.dart';
import 'package:zoe_remind/rag/context_pack.dart';
import 'package:zoe_remind/rag/context_pack_builder.dart';
import 'package:zoe_remind/rag/rag_models.dart';

/// Takbuhin:  flutter test test/rag/context_pack_builder_test.dart
///
/// R7 — ContextPackBuilder gamit ang mga fake (walang database): tamang
/// hinahanap, memory OFF, crisis (walang binabasa), at pumalyang source →
/// mas maliit na pack, hindi crash.
void main() {
  final now = DateTime(2026, 11, 28, 16, 0);

  MemoryItem mem(int id, String content, {FactKind kind = FactKind.general, String? value}) =>
      MemoryItem(
        id: id,
        content: content,
        kind: kind,
        value: value,
        createdAt: now,
        updatedAt: now,
      );

  final memories = [
    mem(1, 'Tawagin akong AC', kind: FactKind.nickname, value: 'AC'),
    mem(4, 'Ayoko ng maagang meeting'),
  ];

  final meeting = RetrievalHit(
    doc: RetrievalDoc(
      source: RetrievalSource.reminder,
      id: 9,
      title: 'Meeting kay boss',
      text: '',
      date: '2026-11-29',
      time: '09:00',
      repeat: 'none',
      updatedAt: now,
    ),
    score: 1,
    matched: 1,
    matchedInTitle: 0,
  );

  test('kinukuha lahat → u, m1, mood, s1; hinanap ang "trabaho meeting"', () async {
    final queries = <String>[];
    final b = ContextPackBuilder(
      memoryOn: () async => true,
      memories: () async => memories,
      learned: () async => const {},
      search: (q) async {
        queries.add(q);
        return [meeting];
      },
      zoeMood: () => MoodState.gentle,
      clock: () => now,
    );
    final pack = await b.build('pagod na ako sa trabaho, may meeting pa bukas');
    expect(queries, ['trabaho meeting']);
    expect(pack.ids, ['u', 'm1', 'mood', 's1']);
    expect(pack.fact('mood')!.text, 'user: tired 1 · zoe: gentle');
    expect(pack.fact('s1')!.text, 'reminder · Meeting kay boss · tomorrow 09:00');
  });

  test('OFF ang long-term memory → hindi binabasa ang memories', () async {
    var read = false;
    final b = ContextPackBuilder(
      memoryOn: () async => false,
      memories: () async {
        read = true;
        return memories;
      },
      learned: () async => const {},
      search: (q) async => const [],
      zoeMood: () => MoodState.content,
      clock: () => now,
    );
    final pack = await b.build('may meeting ako');
    expect(read, isFalse);
    expect(pack.ids, ['mood']);
  });

  test('crisis → ContextPack.crisis, walang binabasa', () async {
    var touched = false;
    final b = ContextPackBuilder(
      memoryOn: () async {
        touched = true;
        return true;
      },
      memories: () async {
        touched = true;
        return memories;
      },
      learned: () async {
        touched = true;
        return const {};
      },
      search: (q) async {
        touched = true;
        return [meeting];
      },
      zoeMood: () {
        touched = true;
        return MoodState.content;
      },
      clock: () => now,
    );
    final pack = await b.build('gusto ko nang mamatay');
    expect(pack.blocked, isTrue);
    expect(identical(pack, ContextPack.crisis), isTrue);
    expect(touched, isFalse);
  });

  test('pumalya ang memories / search / mood → mood na lang, hindi crash', () async {
    final b = ContextPackBuilder(
      memoryOn: () async => true,
      memories: () async => throw StateError('db closed'),
      learned: () async => throw StateError('db closed'),
      search: (q) async => throw StateError('db closed'),
      zoeMood: () => throw StateError('no mood'),
      clock: () => now,
    );
    final pack = await b.build('pagod na ako sa trabaho, may meeting pa bukas');
    expect(pack.blocked, isFalse);
    expect(pack.ids, ['mood']);
    expect(pack.fact('mood')!.text, 'user: tired 1 · zoe: content');
  });

  test('pumalya ang pagbasa ng memory setting → itinuturing na OFF', () async {
    var read = false;
    final b = ContextPackBuilder(
      memoryOn: () async => throw StateError('db closed'),
      memories: () async {
        read = true;
        return memories;
      },
      learned: () async => const {},
      search: (q) async => const [],
      zoeMood: () => MoodState.content,
      clock: () => now,
    );
    final pack = await b.build('may meeting ako');
    expect(read, isFalse);
    expect(pack.fact('u'), isNull);
    expect(pack.fact('m1'), isNull);
  });

  test('walang hahanapin (pakiramdam lang) → hindi tinatawag ang earch', () async {
    var searched = false;
    final b = ContextPackBuilder(
      memoryOn: () async => true,
      memories: () async => memories,
      learned: () async => const {},
      search: (q) async {
        searched = true;
        return [meeting];
      },
      zoeMood: () => MoodState.gentle,
      clock: () => now,
    );
    final pack = await b.build('pagod na ako');
    expect(searched, isFalse);
    expect(pack.fact('s1'), isNull);
    expect(pack.fact('u')!.text, 'name: AC');
  });
}