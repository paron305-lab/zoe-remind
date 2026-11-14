import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zoe_remind/ai/model_manager/model_verifier.dart';
import 'package:zoe_remind/app/app_config.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';
import 'package:zoe_remind/supabase/model_config_service.dart';

/// Saan na ang download ngayon.
enum DownloadPhase { idle, fetchingConfig, downloading, verifying, done, failed, cancelled }

/// Snapshot ng progress — pinapakinggan ng Settings › Zoe's Brain.
class DownloadProgress {
  const DownloadProgress({
    required this.phase,
    this.received = 0,
    this.total = 0,
    this.message,
  });

  final DownloadPhase phase;
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

// Dina-download ang AI model (Zoe's Brain) mula sa link na nasa Supabase.
///
/// Pipeline (Master Plan §30):
///   Supabase (model_config) → HTTPS → `app/models/MODEL.gguf.part`
///   → SHA-256 check → rename → registerModel() → Local AI ready
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

  bool get isRunning => progress.value.isActive;

  /// Folder ng models sa loob ng app storage (hindi nakikita ng ibang apps,
  /// hindi kasama sa backup, nabubura kapag na-uninstall).
  static Future<Directory> modelsDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'models'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Kinukuha ang active model config sa Supabase.
  /// null = offline o walang active model.
  Future<ModelConfig?> latestConfig() => ModelConfigService.fetchActive();

  /// Simulan (o ituloy) ang download. Ligtas tawagin kahit tumatakbo na.
  Future<void> start() async {
    if (isRunning) return;
    _cancel = CancelToken();
    _emit(const DownloadProgress(phase: DownloadPhase.fetchingConfig));

    try {
      // 1. Config mula sa Supabase (url, sha256, size).
      final config = await latestConfig();
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

      await _settings.setModelStatus(ModelStatus.downloading);
      _emit(DownloadProgress(
          phase: DownloadPhase.downloading, received: existing, total: total));

      if (existing < total) {
        await _download(config.url, part, existing, total);
      }

      // 4. Secure Design: i-verify bago gamitin.
      _emit(DownloadProgress(
          phase: DownloadPhase.verifying, received: total, total: total));
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
        await _settings.setModelStatus(ModelStatus.skipped);
        _emit(const DownloadProgress(phase: DownloadPhase.cancelled));
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
  Future<void> clearPartials() async {
    if (isRunning) return;
    try {
      final dir = await modelsDir();
      await for (final f in dir.list()) {
        if (f is File && f.path.endsWith('.part')) await f.delete();
      }
    } catch (e) {
      debugPrint('[ModelDownloader] clearPartials failed: $e');
    }
    _emit(DownloadProgress.idle);
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
        _emit(DownloadProgress(
            phase: DownloadPhase.downloading, received: received, total: total));
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<void> _register(ModelConfig config, String path) async {
    await _settings.registerModel(
      version: config.version,
      filePath: path,
      sizeBytes: config.sizeBytes,
    );
    _emit(DownloadProgress(
        phase: DownloadPhase.done, received: config.sizeBytes, total: config.sizeBytes));
  }

  Future<void> _fail(String message) async {
    await _settings.setModelStatus(ModelStatus.failed);
    _emit(DownloadProgress(phase: DownloadPhase.failed, message: message));
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('[ModelDownloader] Delete failed: $e');
    }
  }

  void _emit(DownloadProgress value) => progress.value = value;
}