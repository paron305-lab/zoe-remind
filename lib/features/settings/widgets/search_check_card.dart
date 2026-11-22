import 'package:flutter/material.dart';
import 'package:zoe_remind/database/database.dart';
import 'package:zoe_remind/rag/query_terms.dart';
import 'package:zoe_remind/rag/rag_models.dart';
import 'package:zoe_remind/rag/retriever.dart';
import 'package:zoe_remind/rag/search_misses.dart';

/// Developer › "Search index (RAG)": gumagana ba ang FTS4 sa phone na ito,
/// tugma ba ang bilang ng notes / memories sa index, at subukan ang Retriever
/// (makikita ang mga salitang hinanap at ang score ng bawat sagot).
/// B6: ipinapakita rin ang tokenizer (unicode61 o simple), at ang mga tanong
/// sa chat na walang nahanap (sa session na ito lang, hindi sine-save) —
/// para malaman kung anong synonyms ang idadagdag sa query_terms.dart.
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
      setState(() {
        _terms = QueryTerms.parse(q).join(', ');
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
              if (_hits!.isEmpty)
                const Text('Walang nahanap', style: TextStyle(fontSize: 13, color: _coral)),
              for (final h in _hits!)
                Text(
                  '${h.doc.isMemory ? '💜' : '📝'} ${h.doc.title} · score ${h.score} '
                  '(${h.matched} salita)',
                  style: const TextStyle(fontSize: 13),
                ),
            ],
            const Divider(height: 24),
            ValueListenableBuilder<int>(
              valueListenable: SearchMisses.changes,
              builder: (context, _, __) => _misses(),
            ),
          ],
        ),
      ),
    );
  }

  /// "Hindi nahanap sa chat" — mga tanong na walang sagot (RAM lang).
  Widget _misses() {
    final items = SearchMisses.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Hindi nahanap sa chat (${items.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (items.isNotEmpty)
              TextButton(onPressed: SearchMisses.clear, child: const Text('Clear')),
          ],
        ),
        const Text(
          'Sa session na ito lang, hindi sine-save. Idagdag sa synonyms '
          '(query_terms.dart) ang salitang dapat tumama.',
          style: TextStyle(fontSize: 12),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Wala pa — ayos!', style: TextStyle(fontSize: 13, color: _mint)),
          ),
        for (final m in items)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '❓ ${m.question}\n    salita: ${m.terms.isEmpty ? '—' : m.terms}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
    );
  }
}