import 'package:flutter/foundation.dart';
import 'package:zoe_remind/supabase/supabase_service.dart';

/// Info ng AI model na galing sa Supabase (table: model_config).
class ModelConfig {
  final String modelName;
  final String version;
  final String url;
  final String sha256;
  final int sizeBytes;
  final int minAppBuild;

  const ModelConfig({
    required this.modelName,
    required this.version,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.minAppBuild,
  });

  factory ModelConfig.fromMap(Map<String, dynamic> m) => ModelConfig(
        modelName: m['model_name'] as String,
        version: m['version'] as String,
        url: m['url'] as String,
        sha256: (m['sha256'] as String).toLowerCase(),
        sizeBytes: (m['size_bytes'] as num).toInt(),
        minAppBuild: (m['min_app_build'] as num).toInt(),
      );

  /// Secure Design: huggingface.co lang ang pinapayagan,
  /// HTTPS lang, at dapat tamang SHA-256 format.
  static const _allowedHosts = {'huggingface.co'};

  bool get isSafe {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        _allowedHosts.contains(uri.host) &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) &&
        sizeBytes > 0;
  }
}

class ModelConfigService {
  ModelConfigService._();

  /// Kinukuha ang active na model. null kapag offline,
  /// walang active row, o hindi pumasa sa safety check.
  static Future<ModelConfig?> fetchActive() async {
    final client = SupabaseService.client;
    if (client == null) return null;

    try {
      final row = await client
          .from('model_config')
          .select('model_name, version, url, sha256, size_bytes, min_app_build')
          .eq('is_active', true)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (row == null) {
        debugPrint('[ModelConfig] Walang active model.');
        return null;
      }

      final config = ModelConfig.fromMap(row);
      if (!config.isSafe) {
        debugPrint('[ModelConfig] Rejected: hindi pumasa sa safety check.');
        return null;
      }
      return config;
    } catch (e) {
      debugPrint('[ModelConfig] Fetch failed: $e');
      return null;
    }
  }
}