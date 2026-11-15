import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zoe_remind/ai/model_manager/model_verifier.dart';
import 'package:zoe_remind/app/app_config.dart';
import 'package:zoe_remind/core/constants/model_tier.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/supabase/model_config_service.dart';

/// Saan na ang download ngayon.
enum DownloadPhase { idle, fetchingConfig, downloading, verifying, done, failed, cancelled }

/// Snapshot ng progress — pinapakinggan ng Settings › Zoe's Brain.
class DownloadProgress {
  const DownloadProgress({
    required this.phase,
    this.tier = ModelTier.lite,
    this.received = 0,
    this.total = 0,
    this.message,
  });

  final DownloadPhase phase;

  /// Aling model ang tinutukoy ng progress na ito.
  final ModelTier tier;
  final int received;
  final int total;

  /// Dahilan kapag failed (English, pinapakita sa snackbar).
  final String? message;

  static const idle = DownloadProgress(phase: DownloadPhase.idle);

  bool get isActive =>
      phase == DownloadPhase.fetchingConfig ||
      phase == DownloadPhase.downloading ||
      phase == DownloadPhase.verifying;

  /// 0.0–1.0 (null = indeterminate).
  double? get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  int get percent => ((fraction ?? 0) * 100).round();
}

/// Dina-download ang AI model (Zoe's Brain) mula sa link na nasa Supabase.
///
/// Pipeline (Master Plan §30):
///   Supabase (model_config) → HTTPS → `app/models/MODEL.gguf.part`
///   → SHA-256 check → rename → registerModel() → Local AI ready
///
/// Dalawang model (Zoe Lite / Zoe Plus), pero isang download lang
/// sa isang pagkakataon.
class ModelDownloader {
  ModelDownloader._();
  static final instance = ModelDownloader._();

  final progress = ValueNotifier<DownloadProgress>(DownloadProgress.idle);

  final _settings = SettingsRepository();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
  ));

  CancelToken? _cancel;

  /// Ang tier ng kasalukuyan (o huling) download.
  ModelTier _tier = ModelTier.lite;

  bool get isRunning => progress.value.isActive;

  /// Aling model ang dina-download ngayon. null = walang tumatakbo.
  ModelTier? get runningTier => isRunning ? progress.value.tier : null;

  /// Folder ng models sa loob ng app storage (hindi nakikita ng ibang apps,
  /// hindi kasama sa backup, nabubura kapag na-uninstall).
  static Future<Directory> modelsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'models'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Kinukuha ang active model config ng isang tier sa Supabase.
  /// null = offline o walang active model sa tier na iyon.
  Future<ModelConfig?> latestConfig([ModelTier tier = ModelTier.lite]) =>
      ModelConfigService.fetchTier(tier);

  /// Simulan (o ituloy) ang download ng isang tier.
  /// Kapag may tumatakbo nang download (kahit ibang tier), walang gagawin.
  Future<void> start([ModelTier tier = ModelTier.lite]) async {
    if (isRunning) return;
    _tier = tier;
    _cancel = CancelToken();
    _emit(DownloadPhase.fetchingConfig);

    try {
      // 1. Config mula sa Supabase (url, sha256, size).
      final config = await latestConfig(tier);
      if (config == null) {
        await _fail("Couldn't reach Zoe's server. Check your internet and try again.");
        return;
      }
      if (config.minAppBuild > AppConfig.build) {
        await _fail('This model needs a newer version of Zoe-Remind.');
        return;
      }

      final dir = await modelsDir();
      final finalPath = p.join(dir.path, '${config.modelName}.gguf');
      final partPath = '$finalPath.part';
      final total = config.sizeBytes;

      // 2. Baka na-download na dati (hal. na-delete lang ang DB row).
      if (await ModelVerifier.matches(
        path: finalPath,
        expectedBytes: total,
        expectedSha256: config.sha256,
      )) {
        await _register(config, finalPath);
        return;
      }

      // 3. Resume mula sa .part kung meron.
      final part = File(partPath);
      var existing = await part.exists() ? await part.length() : 0;
      if (existing > total) {
        await part.delete();
        existing = 0;
      }

      await _settings.setModelStatus(ModelStatus.downloading, tier: tier);
      _emit(DownloadPhase.downloading, received: existing, total: total);

      if (existing < total) {
        await _download(config.url, part, existing, total);
      }

      // 4. Secure Design: i-verify bago gamitin.
      _emit(DownloadPhase.verifying, received: total, total: total);
      final ok = await ModelVerifier.matches(
        path: partPath,
        expectedBytes: total,
        expectedSha256: config.sha256,
      );
      if (!ok) {
        await _safeDelete(part);
        await _fail('The downloaded file was damaged. Please try again.');
        return;
      }

      // 5. Ready.
      await part.rename(finalPath);
      await _register(config, finalPath);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        await _settings.setModelStatus(ModelStatus.skipped, tier: tier);
        _emit(DownloadPhase.cancelled);
        return;
      }
      debugPrint('[ModelDownloader] Dio error: $e');
      await _fail('Download interrupted. Connect to Wi-Fi and tap Download to resume.');
    } catch (e) {
      debugPrint('[ModelDownloader] Error: $e');
      await _fail('Something went wrong. Please try again.');
    } finally {
      _cancel = null;
    }
  }

  /// Hinihinto ang download. Iniiwan ang .part para ma-resume.
  void cancel() => _cancel?.cancel('user');

  /// Burahin ang mga naiwang .part (tinatawag ng [Delete] sa Settings).
  /// May [modelName] (hal. Qwen3.5-2B-Q4_K_M) → .part ng model na iyon lang.
  /// Wala → lahat ng .part.
  /// Walang gagawin habang may tumatakbong download.
  Future<void> clearPartials([String? modelName]) async {
    if (isRunning) return;
    try {
      final dir = await modelsDir();
      if (modelName != null) {
        await _safeDelete(File(p.join(dir.path, '$modelName.gguf.part')));
      } else {
        await for (final f in dir.list()) {
          if (f is File && f.path.endsWith('.part')) await f.delete();
        }
      }
    } catch (e) {
      debugPrint('[ModelDownloader] clearPartials failed: $e');
    }
    progress.value = DownloadProgress.idle;
  }

  // ───────────────────────── internals ─────────────────────────

  Future<void> _download(String url, File part, int existing, int total) async {
    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: _cancel,
      options: Options(
        responseType: ResponseType.stream,
        headers: existing > 0 ? {'Range': 'bytes=$existing-'} : null,
        validateStatus: (s) => s == 200 || s == 206,
      ),
    );

    // 206 = tinuloy ng server. 200 = binalewala ang Range → ulitin mula umpisa.
    var received = existing;
    if (response.statusCode == 200 && existing > 0) {
      await _safeDelete(part);
      received = 0;
    }

    final sink = part.openWrite(mode: FileMode.append);
    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        _emit(DownloadPhase.downloading, received: received, total: total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<void> _register(ModelConfig config, String path) async {
    await _settings.registerModel(
      tier: config.tier,
      modelName: config.modelName,
      version: config.version,
      filePath: path,
      sizeBytes: config.sizeBytes,
    );
    _emit(DownloadPhase.done,
        received: config.sizeBytes, total: config.sizeBytes);
  }

  Future<void> _fail(String message) async {
    await _settings.setModelStatus(ModelStatus.failed, tier: _tier);
    _emit(DownloadPhase.failed, message: message);
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('[ModelDownloader] Delete failed: $e');
    }
  }

  /// Laging may kasamang tier ang progress, para alam ng Settings
  /// kung aling card ang gagalaw.
  void _emit(
    DownloadPhase phase, {
    int received = 0,
    int total = 0,
    String? message,
  }) {
    progress.value = DownloadProgress(
      phase: phase,
      tier: _tier,
      received: received,
      total: total,
      message: message,
    );
  }
}