import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zoe_remind/ai/inference/inference_config.dart';
import 'package:zoe_remind/ai/inference/qwen_engine.dart';
import 'package:zoe_remind/features/home/widgets/home_styles.dart';

/// Developer › Brain Test: i-load si Qwen sa phone, magpadala ng isang prompt,
/// at sukatin ang bilis at RAM. Para lang sa testing (hindi pa ito ang Zoe Chat).
class BrainTestScreen extends StatefulWidget {
  const BrainTestScreen({super.key});

  @override
  State<BrainTestScreen> createState() => _BrainTestScreenState();
}

/// Dalawang klase ng test.
enum _Mode { chat, json }

class _BrainTestScreenState extends State<BrainTestScreen> {
  static const _lavender = Color(0xFF8B7FE0);
  static const _mint = Color(0xFF3FBE93);
  static const _coral = Color(0xFFF0768E);
  static Color get _ink => HomeColors.ink;
  static Color get _cream => HomeColors.cream;

  static const _chatSystem =
      'Ikaw si Zoe, isang mabait na reminder assistant sa phone. '
      'Sumagot nang maikli (1-3 pangungusap). Naiintindihan mo ang English, '
      'Tagalog, at Taglish; sumagot sa parehong wika ng user.';

  static const _jsonSystem =
      'You extract intent from the user message. Reply with ONLY one JSON object, '
      'no extra text. Keys: "action" (one of: create_reminder, create_task, '
      'create_note, get_today, unknown), "title" (string), "date_phrase" '
      '(string or null, copy the words the user used), "time_phrase" '
      '(string or null, copy the words the user used). The user may write in '
      'English, Tagalog, or Taglish.';

  final _brain = QwenEngine.instance;
  final _prompt = TextEditingController(
      text: 'Hi Zoe! Ano ang pwede mong gawin para sa akin?');
  final _out = StringBuffer();

  _Mode _mode = _Mode.chat;
  StreamSubscription<String>? _sub;
  Timer? _flush;
  String _error = '';

  // Sukat (perf)
  final _watch = Stopwatch();
  Duration? _firstToken;
  Duration? _total;
  int _chunks = 0;
  int _rssMb = 0;
  int _peakRssMb = 0;

  @override
  void initState() {
    super.initState();
    _brain.state.addListener(_onBrainChanged);
    _readRam();
  }

  @override
  void dispose() {
    _brain.state.removeListener(_onBrainChanged);
    _sub?.cancel(); // humihinto rin ang generation
    _flush?.cancel();
    _prompt.dispose();
    super.dispose();
  }

  void _onBrainChanged() {
    _readRam();
    if (mounted) setState(() {});
  }

  /// RAM ng buong app ngayon (RSS) at ang pinakamataas mula nang magbukas.
  void _readRam() {
    _rssMb = ProcessInfo.currentRss ~/ (1024 * 1024);
    _peakRssMb = ProcessInfo.maxRss ~/ (1024 * 1024);
  }

  Future<void> _load() async {
    setState(() => _error = '');
    try {
      await _brain.load();
    } catch (e) {
      if (mounted) setState(() => _error = '❌ Load failed:\n$e');
    }
  }

  Future<void> _unload() async {
    await _sub?.cancel();
    _sub = null;
    await _brain.unload();
  }

  void _setMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _prompt.text = mode == _Mode.chat
          ? 'Hi Zoe! Ano ang pwede mong gawin para sa akin?'
          : 'Paalala mo ako bukas ng 8am na uminom ng vitamins';
    });
  }

  void _send() {
    final text = _prompt.text.trim();
    if (text.isEmpty || _brain.isGenerating) return;
    FocusScope.of(context).unfocus();

    _out.clear();
    _error = '';
    _chunks = 0;
    _firstToken = null;
    _total = null;
    _watch
      ..reset()
      ..start();

    final messages = [
      BrainMessage.system(_mode == _Mode.chat ? _chatSystem : _jsonSystem),
      BrainMessage.user(text),
    ];

    // Hindi setState bawat token — ina-update ang screen tuwing 100 ms.
    _flush = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _readRam();
      if (mounted) setState(() {});
    });

    _sub = _brain.generate(messages, json: _mode == _Mode.json).listen(
      (piece) {
        _firstToken ??= _watch.elapsed;
        _chunks++;
        _out.write(piece);
      },
      onError: (Object e) {
        _error = '❌ Generate failed:\n$e';
        _finish();
      },
      onDone: _finish,
    );
    setState(() {});
  }

  void _finish() {
    _watch.stop();
    _total = _watch.elapsed;
    _flush?.cancel();
    _flush = null;
    _sub = null;
    _readRam();
    if (mounted) setState(() {});
  }

  void _stop() => _brain.stop();

  String _sec(Duration? d) => d == null ? '–' : '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

  /// ≈ tokens/sec (isang chunk ≈ isang token), binibilang mula sa unang token.
  String get _speed {
    final first = _firstToken;
    final end = _total ?? _watch.elapsed;
    if (first == null || _chunks < 2) return '–';
    final secs = (end - first).inMilliseconds / 1000;
    if (secs <= 0) return '–';
    return '≈ ${((_chunks - 1) / secs).toStringAsFixed(1)} tok/s';
  }

  @override
  Widget build(BuildContext context) {
    final state = _brain.state.value;
    final busy = state == BrainState.loading || state == BrainState.generating;
    final (label, color) = switch (state) {
      BrainState.unloaded => ('Not loaded', HomeColors.inkSoft),
      BrainState.loading => ('Loading… (ilang segundo)', const Color(0xFFF0AA45)),
      BrainState.ready => ('Ready ✅', _mint),
      BrainState.generating => ('Thinking…', _lavender),
      BrainState.error => ('Error', _coral),
    };

    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: Colors.transparent,
        title: Text('Brain Test',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: _ink)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section('1. Model'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                    const SizedBox(height: 6),
                    Text('Backend: ${_brain.backendName ?? '–'}'),
                    Text('Load time: ${_sec(_brain.lastLoadTime)}'),
                    Text('Context: ${InferenceConfig.contextSize} · '
                        'Threads: ${InferenceConfig.threads} · '
                        'CPU cores: ${Platform.numberOfProcessors}'),
                    Text('RAM ngayon: $_rssMb MB · Peak: $_peakRssMb MB'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: _lavender),
                            onPressed: busy || _brain.isLoaded ? null : _load,
                            icon: const Icon(Icons.memory_rounded),
                            label: const Text('Load'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _brain.isLoaded && state != BrainState.loading
                                ? _unload
                                : null,
                            icon: const Icon(Icons.eject_rounded),
                            label: const Text('Unload'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _section('2. Prompt'),
            SegmentedButton<_Mode>(
              segments: const [
                ButtonSegment(value: _Mode.chat, label: Text('Chat'), icon: Icon(Icons.chat_rounded)),
                ButtonSegment(value: _Mode.json, label: Text('JSON'), icon: Icon(Icons.data_object_rounded)),
              ],
              selected: {_mode},
              onSelectionChanged: busy ? null : (s) => _setMode(s.first),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _prompt,
              minLines: 2,
              maxLines: 5,
              enabled: !busy,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Isulat ang tanong kay Zoe…',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: state == BrainState.generating
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _coral),
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop'),
                    )
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _lavender),
                      // Kung hindi pa naka-load, ilo-load muna ng generate().
                      onPressed: state == BrainState.loading ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Send'),
                    ),
            ),
            const SizedBox(height: 24),

            _section('3. Sagot ni Zoe'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _out.isEmpty ? '…' : _out.toString(),
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unang token: ${_sec(_firstToken)} · Total: ${_sec(_total)} · '
              'Chunks: $_chunks · Bilis: $_speed',
              style: TextStyle(color: HomeColors.inkSoft, fontSize: 13),
            ),
            if (_error.isNotEmpty || _brain.lastError != null) ...[
              const SizedBox(height: 16),
              _section('4. Error'),
              SelectableText(
                _error.isNotEmpty ? _error : _brain.lastError!,
                style: const TextStyle(color: _coral),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
      );
}