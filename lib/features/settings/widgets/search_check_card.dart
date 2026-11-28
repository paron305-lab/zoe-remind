import 'package:flutter/material.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_learning.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';
import 'package:zoe_remind/rag/search_scope.dart';

/// Developer › "Search index (RAG)": gumagana ba ang FTS4 sa phone na ito,
/// tugma ba ang bilang ng notes / memories sa index, at subukan ang Retriever
/// (makikita ang mga salitang hinanap at ang score ng bawat sagot).
/// B6: ipinapakita rin ang tokenizer (unicode61 o simple), at ang mga tanong
/// sa chat na walang nahanap (sa session na ito lang, hindi sine-save) —
/// para malaman kung anong synonyms ang idadagdag sa query_terms.dart.
/// R4: kasama ang reminders (⏰) at tasks (✅) sa resulta, at ipinapakita kung
/// saan hinanap ("reminder lang" kapag binanggit sa tanong).
/// R6: "Natutunan ni Zoe" — mga natutunang salita (aktibo ✅ / naghihintay ⏳,
/// may 🗑 bawat isa), ilang item ang may feedback, at ang mga tanong na walang
/// nahanap (search_log — naka-save na sa phone, hindi na RAM lang).
class SearchCheckCard extends StatefulWidget {
  const SearchCheckCard({super.key});

  @override
  State<SearchCheckCard> createState() => _SearchCheckCardState();
}

class _SearchCheckCardState extends State<SearchCheckCard> {
  static const _lavender = Color(0xFF8B7FE0);
  static const _mint = Color(0xFF3FBE93);
  static const _coral = Color(0xFFF0768E);

  SearchIndexStatus? _status;
  bool _busy = false;
  final _query = TextEditingController(text: 'ano wifi password ko?');
  String _terms = '';
  String _scope = '';
  List<RetrievalHit>? _hits;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text;
    try {
      final hits = await Retriever().search(q, limit: 5);
      if (!mounted) return;
      // R6: kasama ang natutunang salita (gaya ng sa chat).
      final learned = (await RagLearning.instance.snapshot()).synonyms;
      if (!mounted) return;
      final scope = SearchScope.of(q, learned: learned);
      setState(() {
        _terms = QueryTerms.parse(q, learned: learned).join(', ');
        _scope = scope.isScoped ? '${scope.kinds!.map((k) => k.name).join(' + ')} muna' : 'lahat';
        _hits = hits;
      });
    } catch (e) {
      debugPrint('Retriever test failed: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ZoeDatabase.instance.searchIndexStatus();
      if (mounted) setState(() => _status = s);
    } catch (e) {
      debugPrint('Search index status failed: $e');
    }
  }

  Future<void> _rebuild() async {
    setState(() => _busy = true);
    try {
      final s = await ZoeDatabase.instance.rebuildSearchIndex();
      if (mounted) setState(() => _status = s);
    } catch (e) {
      debugPrint('Rebuild search index failed: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null) return const Card(child: ListTile(title: Text('checking…')));
    final ok = s.ready && s.inSync;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.ready ? '✅ FTS4 gumagana' : '❌ Walang FTS4 — LIKE search ang gamit',
              style: TextStyle(fontWeight: FontWeight.w700, color: ok ? _mint : _coral),
            ),
            const SizedBox(height: 4),
            Text('SQLite ${s.sqliteVersion}', style: const TextStyle(fontSize: 13)),
            if (s.tokenizer != null)
              Text(
                s.tokenizer == 'unicode61'
                    ? '✅ Tokenizer: unicode61 (Niño = nino)'
                    : 'ℹ️ Tokenizer: simple (walang unicode61 sa phone na ito)',
                style: const TextStyle(fontSize: 13),
              ),
            for (final e in s.counts.entries)
              Text(
                '${e.value.$2 == e.value.$1 ? '✅' : '⚠️'}  ${e.key}: '
                '${e.value.$1} rows · index ${e.value.$2 ?? '—'}',
                style: const TextStyle(fontSize: 13),
              ),
            if (s.error != null) ...[
              const SizedBox(height: 4),
              SelectableText(s.error!, style: const TextStyle(fontSize: 12, color: _coral)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _lavender),
                  onPressed: _busy ? null : _rebuild,
                  icon: const Icon(Icons.build_rounded),
                  label: const Text('Rebuild'),
                ),
                TextButton(onPressed: _busy ? null : _load, child: const Text('Refresh')),
              ],
            ),
            const Divider(height: 24),
            const Text('Subukan ang Retriever', style: TextStyle(fontWeight: FontWeight.w700)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
                IconButton(onPressed: _search, icon: const Icon(Icons.search_rounded)),
              ],
            ),
            if (_hits != null) ...[
              const SizedBox(height: 6),
              Text('salita: ${_terms.isEmpty ? '—' : _terms}', style: const TextStyle(fontSize: 12)),
              Text('saan: $_scope', style: const TextStyle(fontSize: 12)),
              if (_hits!.isEmpty)
                const Text('Walang nahanap', style: TextStyle(fontSize: 13, color: _coral)),
              // R2: score (BM25-style) · coverage · sigurado o "baka".
              for (final h in _hits!)
                Text(
                  '${_icon(h.doc.source)} ${h.doc.title} · '
                  'score ${h.score.toStringAsFixed(2)} · ${(h.coverage * 100).round()}% · '
                  '${h.isSure ? 'sigurado' : 'baka 🤔'} (${h.matched} salita)',
                  style: const TextStyle(fontSize: 13),
                ),
            ],
            const Divider(height: 24),
            ValueListenableBuilder<int>(
              valueListenable: RagLearning.instance.changes,
              builder: (context, version, __) => _LearningSection(version: version),
            ),
          ],
        ),
      ),
    );
  }

  static String _icon(RetrievalSource s) => switch (s) {
        RetrievalSource.note => '📝',
        RetrievalSource.memory => '💜',
        RetrievalSource.reminder => '⏰',
        RetrievalSource.task => '✅',
      };
}

/// R6: "Natutunan ni Zoe" — binabasa ang search_log, learned_terms at
/// search_feedback (RagLearning.instance). Nire-refresh tuwing may bago.
class _LearningSection extends StatefulWidget {
  const _LearningSection({required this.version});

  /// RagLearning.changes — nagbabago → load ulit.
  final int version;

  @override
  State<_LearningSection> createState() => _LearningSectionState();
}

class _LearningSectionState extends State<_LearningSection> {
  static const _mint = Color(0xFF3FBE93);
  static const _coral = Color(0xFFF0768E);

  late Future<_LearningData> _data = _LearningData.load();

  @override
  void didUpdateWidget(covariant _LearningSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.version != widget.version) _data = _LearningData.load();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Burahin ang natutunan?'),
        content: const Text(
          'Mabubura ang search log, mga natutunang salita at feedback. '
          'Hindi gagalawin ang notes at memories.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huwag')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Burahin')),
        ],
      ),
    );
    if (ok == true) await RagLearning.instance.clearLearning();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LearningData>(
      future: _data,
      builder: (context, snap) {
        final d = snap.data;
        if (d == null) return const Text('checking…', style: TextStyle(fontSize: 13));
        final active = d.terms.where((t) => t.active).toList();
        final waiting = d.terms.where((t) => !t.active).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Natutunan ni Zoe (R6)', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (!d.isEmpty) TextButton(onPressed: _clearAll, child: const Text('Clear')),
              ],
            ),
            const Text(
              'Sa phone lang. Ang salita ay ginagamit pagkatapos ng '
              '${RagLearning.minCount} beses. Nabubura rin sa "Burahin lahat".',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              'Salita: ${active.length} aktibo · ${waiting.length} naghihintay  ·  '
              'Feedback: ${d.feedback.length} item',
              style: const TextStyle(fontSize: 13),
            ),
            for (final t in [...active, ...waiting])
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${t.active ? '✅' : '⏳'} ${t.term} ↔ ${t.alt}  ×${t.count}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Burahin',
                    onPressed: () => RagLearning.instance.forget(t.term, t.alt),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _coral),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Text(
              'Hindi nahanap sa chat (${d.misses.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text(
              'Idagdag sa synonyms (query_terms.dart) ang salitang dapat tumama — '
              'o hayaang matutunan ni Zoe kapag nag-rephrase ka.',
              style: TextStyle(fontSize: 12),
            ),
            if (d.misses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Wala pa — ayos!', style: TextStyle(fontSize: 13, color: _mint)),
              ),
            for (final m in d.misses)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '❓ ${m.question}\n    salita: ${_termsOf(m.query)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _termsOf(String query) {
    final t = QueryTerms.parse(query).join(', ');
    return t.isEmpty ? '—' : t;
  }
}

class _LearningData {
  const _LearningData(this.terms, this.feedback, this.misses);

  final List<LearnedTerm> terms;
  final Map<String, DocFeedback> feedback;
  final List<SearchLogEntry> misses;

  bool get isEmpty => terms.isEmpty && feedback.isEmpty && misses.isEmpty;

  static Future<_LearningData> load() async {
    final l = RagLearning.instance;
    return _LearningData(await l.learnedTerms(), await l.feedback(), await l.recentMisses());
  }
}