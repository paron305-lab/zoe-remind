import 'package:flutter/material.dart';
import 'package:zoe_remind/rag/context_pack.dart';
import 'package:zoe_remind/rag/context_pack_builder.dart';

/// Developer › "Context Pack (R7)": mag-type ng mensahe → makikita ang
/// kodigo na iaabot kay Qwen sa Z2 (u, m1, m2, mood, s1), ilang tokens, at
/// saan galing ang bawat linya (memory#5, reminder#2…).
///
/// Read-only: walang sine-save (walang search_log, walang use_count).
/// Hindi pa ito ginagamit sa chat — sa Z2 pa.
class ContextPackCard extends StatefulWidget {
  const ContextPackCard({super.key});

  @override
  State<ContextPackCard> createState() => _ContextPackCardState();
}

class _ContextPackCardState extends State<ContextPackCard> {
  static const _lavender = Color(0xFF8B7FE0);
  static const _mint = Color(0xFF3FBE93);
  static const _coral = Color(0xFFF0768E);

  final _message = TextEditingController(text: 'pagod na ako sa trabaho, may meeting pa bukas');
  ContextPack? _pack;
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    final text = _message.text;
    setState(() => _busy = true);
    try {
      final pack = await ContextPackBuilder().build(text);
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _query = ContextPack.searchQuery(text);
      });
    } catch (e) {
      debugPrint('Context Pack test failed: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = _pack;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Subukan ang Context Pack', style: TextStyle(fontWeight: FontWeight.w700)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    onSubmitted: (_) => _build(),
                    decoration: const InputDecoration(isDense: true),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _build,
                  icon: const Icon(Icons.inventory_2_rounded, color: _lavender),
                ),
              ],
            ),
            if (p != null) ...[
              const SizedBox(height: 8),
              if (p.blocked)
                const Text('🛑 Crisis — walang pack (script + hotline lang, walang Qwen)',
                    style: TextStyle(fontWeight: FontWeight.w700, color: _coral))
              else ...[
                Text(
                  '${p.tokens <= ContextPack.maxTokens ? '✅' : '⚠️'} '
                  '≈ ${p.tokens} / ${ContextPack.maxTokens} tokens · ${p.facts.length} linya',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: p.tokens <= ContextPack.maxTokens ? _mint : _coral,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    p.toPrompt(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 6),
                Text('hinanap (s1): ${_query.isEmpty ? '—' : _query}',
                    style: const TextStyle(fontSize: 12)),
                for (final f in p.facts)
                  if (f.ref != null)
                    Text('${f.id} ← ${f.ref}${f.sure ? '' : ' (baka 🤔)'}',
                        style: const TextStyle(fontSize: 12)),
                if (p.fact('m1') == null)
                  const Text('walang memory na may kinalaman (o OFF ang long-term memory)',
                      style: TextStyle(fontSize: 12)),
              ],
            ],
            const SizedBox(height: 4),
            const Text(
              'Hindi pa ginagamit sa chat (Z2 pa). Walang sine-save dito.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}