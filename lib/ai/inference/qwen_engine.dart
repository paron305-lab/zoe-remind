import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llamadart/llamadart.dart';
import 'package:zoe_remind/ai/inference/inference_config.dart';
import 'package:zoe_remind/core/constants/model_tier.dart';
import 'package:zoe_remind/database/models/model_info.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';

/// Estado ng Zoe's Brain habang tumatakbo ang app.
enum BrainState { unloaded, loading, ready, generating, error }

/// Sino ang nagsalita sa isang mensahe papunta kay Qwen.
enum BrainRole { system, user, assistant }

/// Isang mensahe papunta kay Qwen. Sariling class natin para
/// hindi kumalat ang llamadart sa buong app (madaling palitan ang package).
class BrainMessage {
  const BrainMessage(this.role, this.text);
  const BrainMessage.system(this.text) : role = BrainRole.system;
  const BrainMessage.user(this.text) : role = BrainRole.user;
  const BrainMessage.assistant(this.text) : role = BrainRole.assistant;

  final BrainRole role;
  final String text;

  LlamaChatMessage toLlama() => LlamaChatMessage.fromText(
        role: switch (role) {
          BrainRole.system => LlamaChatRole.system,
          BrainRole.user => LlamaChatRole.user,
          BrainRole.assistant => LlamaChatRole.assistant,
        },
        text: text,
      );
}

/// Error na pwedeng ipakita sa user (Taglish).
class BrainException implements Exception {
  const BrainException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Si Qwen (Zoe's Brain) sa loob ng phone — llama.cpp sa pamamagitan ng llamadart.
///
/// Gamit:
///   await QwenEngine.instance.load();            // isang beses (ilang segundo)
///   await for (final t in QwenEngine.instance.generate([...])) { ... }
///   QwenEngine.instance.stop();                  // Stop button
///   await QwenEngine.instance.unload();          // para ma-free ang RAM
///   await QwenEngine.instance.switchTo(tier);    // lumipat ng Lite / Plus
///
/// Dalawang model (Zoe Lite / Zoe Plus) pero isa lang ang naka-load.
/// Parehong engine, parehong prompts — ang GGUF file lang ang iba.
///
/// Golden rule: Qwen interprets lang. Hindi siya nagsusulat sa DB,
/// walang network, walang file access — ang code ang nagde-decide.
class QwenEngine {
  QwenEngine._() {
    // "Gamitin" o "Delete" sa Settings → i-unload kung iba na ang dapat gamitin.
    SettingsRepository.changes.addListener(_onSettingsChanged);
  }
  static final instance = QwenEngine._();

  final state = ValueNotifier<BrainState>(BrainState.unloaded);

  /// Huling error (para sa Developer › Brain Test).
  String? lastError;

  /// Gaano katagal nag-load ang model (para sa perf test).
  Duration? lastLoadTime;

  /// Hal. "llama.cpp (CPU)" — galing sa runtime.
  String? backendName;

  /// Aling model ang naka-load ngayon. null = wala.
  ModelTier? loadedTier;

  /// Pangalan ng file ng naka-load na model (hal. Qwen3.5-2B-Q4_K_M).
  String? loadedModelName;

  final _settings = SettingsRepository();
  LlamaEngine? _engine;
  Future<void>? _loading;
  String? _loadedPath;

  /// May nagbago sa Settings habang sumasagot → i-check pagkatapos.
  bool _stale = false;

  bool get isLoaded => _engine != null;
  bool get isGenerating => state.value == BrainState.generating;

  /// I-load ang model na gamit ni Zoe (ang pinili sa Settings).
  /// Ligtas tawagin nang paulit-ulit: isang load lang ang tatakbo.
  Future<void> load() {
    if (_engine != null) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  /// Ang model na ilo-load: ang pinili kung ready at may file;
  /// kung hindi, ang isa pa. null = walang magagamit.
  Future<ModelInfo?> _pickModel() async {
    final chosen = await _settings.getActiveTier();
    for (final tier in [chosen, chosen.other]) {
      final info = await _settings.getModelInfo(tier);
      final path = info.filePath;
      if (info.isReady && path != null && await File(path).exists()) return info;
    }
    return null;
  }

  Future<void> _load() async {
    state.value = BrainState.loading;
    lastError = null;
    final watch = Stopwatch()..start();
    try {
      final info = await _pickModel();
      if (info == null) {
        throw const BrainException(
            "Wala pang model. I-download muna sa Settings › Zoe's Brain.");
      }
      final path = info.filePath!;

      final engine = await LlamaEngine.load(
        LlamaModel(ModelSource.path(path)),
        params: InferenceConfig.modelParams,
      );
      _engine = engine;
      _loadedPath = path;
      loadedTier = info.tier;
      loadedModelName = info.modelName;
      backendName = await engine.getBackendName();
      lastLoadTime = watch.elapsed;
      state.value = BrainState.ready;
    } catch (e) {
      lastError = '$e';
      _engine = null;
      _loadedPath = null;
      loadedTier = null;
      loadedModelName = null;
      state.value = BrainState.error;
      rethrow;
    }
  }

  /// Lumipat ng model: stop → unload → i-save ang pili → load.
  /// Pareho ito ng "Gamitin" sa Settings, pero nilo-load agad.
  Future<void> switchTo(ModelTier tier) async {
    final loading = _loading;
    if (loading != null) {
      try {
        await loading;
      } catch (_) {
        // Pumalya ang naunang load; itutuloy pa rin ang paglipat.
      }
    }
    stop();
    await unload();
    await _settings.setActiveTier(tier);
    await load();
  }

  /// Magpadala ng messages kay Qwen; lumalabas ang sagot nang paunti-unti.
  /// [json] = true → mas mababang temperature (para sa intent extraction).
  /// Isang generation lang sa isang pagkakataon.
  Stream<String> generate(
    List<BrainMessage> messages, {
    int? maxTokens,
    bool json = false,
  }) async* {
    await load();
    final engine = _engine;
    if (engine == null) throw const BrainException('Zoe is Loading.');
    if (isGenerating) throw const BrainException('ZOE is Generating.');

    state.value = BrainState.generating;
    try {
      final stream = engine.create(
        messages.map((m) => m.toLlama()).toList(),
        params: json
            ? InferenceConfig.json(maxTokens: maxTokens)
            : InferenceConfig.chat(maxTokens: maxTokens),
        enableThinking: false, // walang <think>, diretso sagot (mas mabilis)
      );
      await for (final chunk in stream) {
        final text = chunk.text;
        if (text.isNotEmpty) yield text;
      }
    } finally {
      if (_engine != null) state.value = BrainState.ready;
      if (_stale) {
        _stale = false;
        _onSettingsChanged();
      }
    }
  }

  /// Ihinto ang kasalukuyang sagot (Stop button).
  void stop() => _engine?.cancelGeneration();

  /// Alisin ang model sa RAM (hal. kapag matagal hindi ginagamit o na-delete).
  Future<void> unload() async {
    final engine = _engine;
    _engine = null;
    _loadedPath = null;
    loadedTier = null;
    loadedModelName = null;
    if (engine != null) {
      engine.cancelGeneration();
      try {
        await engine.dispose();
      } catch (e) {
        debugPrint('Brain unload failed: $e');
      }
    }
    state.value = BrainState.unloaded;
  }

  /// May nagbago sa Settings (pinili, na-delete, o na-update ang model).
  /// Kapag iba na ang dapat gamitin kaysa sa naka-load, i-unload.
  /// Ang tamang model ay kusang ilo-load sa susunod na generate().
  Future<void> _onSettingsChanged() async {
    if (_engine == null || state.value == BrainState.loading) return;
    if (isGenerating) {
      _stale = true; // huwag putulin ang sagot; i-check pagkatapos
      return;
    }
    try {
      final want = await _pickModel();
      if (_engine == null) return;
      if (isGenerating) {
        _stale = true;
        return;
      }
      if (want == null || want.tier != loadedTier || want.filePath != _loadedPath) {
        await unload();
      }
    } catch (e) {
      debugPrint('Brain sync failed: $e');
    }
  }
}