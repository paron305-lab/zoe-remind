import 'package:flutter/foundation.dart';
import 'package:zoe_remind/core/constants/model_tier.dart';
import 'package:zoe_remind/supabase/supabase_service.dart';

/// Info ng AI model na galing sa Supabase (table: model_config).
class ModelConfig {
  final String modelName;
  final String version;
  final String url;
  final String sha256;
  final int sizeBytes;
  final int minAppBuild;
  final ModelTier tier;

  /// Pangalang pinapakita sa user (hal. "Zoe Lite"). Galing sa server,
  /// kaya pwedeng palitan nang walang app update.
  final String displayName;
  final String? description;

  /// Pinakamababang RAM ng phone (MB). 0 = walang limit.
  final int minRamMb;
  final int sortOrder;

  const ModelConfig({
    required this.modelName,
    required this.version,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.minAppBuild,
    this.tier = ModelTier.lite,
    String? displayName,
    this.description,
    this.minRamMb = 0,
    this.sortOrder = 0,
  }) : displayName = displayName ?? modelName;

  factory ModelConfig.fromMap(Map<String, dynamic> m) => ModelConfig(
        modelName: m['model_name'] as String,
        version: m['version'] as String,
        url: m['url'] as String,
        sha256: (m['sha256'] as String).toLowerCase(),
        sizeBytes: (m['size_bytes'] as num).toInt(),
        minAppBuild: (m['min_app_build'] as num).toInt(),
        tier: ModelTier.fromName(m['tier'] as String?) ?? ModelTier.lite,
        displayName: m['display_name'] as String?,
        description: m['description'] as String?,
        minRamMb: (m['min_ram_mb'] as num?)?.toInt() ?? 0,
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
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

  static const _columns =
      'model_name, version, url, sha256, size_bytes, min_app_build, '
      'tier, display_name, description, min_ram_mb, sort_order';

  /// Lahat ng active na model (isa kada tier), ayon sa sort_order.
  /// Walang laman kapag offline o walang active row.
  /// Hindi kasama ang row na hindi pumasa sa safety check
  /// o may tier na hindi kilala ng app na ito.
  static Future<List<ModelConfig>> fetchAll() async {
    final client = SupabaseService.client;
    if (client == null) return const [];

    try {
      final rows = await client
          .from('model_config')
          .select(_columns)
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .timeout(const Duration(seconds: 10));

      final configs = <ModelConfig>[];
      final seen = <ModelTier>{};
      for (final row in rows) {
        if (ModelTier.fromName(row['tier'] as String?) == null) {
          debugPrint('[ModelConfig] Skipped: hindi kilalang tier.');
          continue;
        }
        final config = ModelConfig.fromMap(row);
        if (!config.isSafe) {
          debugPrint('[ModelConfig] Rejected: hindi pumasa sa safety check.');
          continue;
        }
        if (!seen.add(config.tier)) continue; // isa lang kada tier
        configs.add(config);
      }
      if (configs.isEmpty) debugPrint('[ModelConfig] Walang active model.');
      return configs;
    } catch (e) {
      debugPrint('[ModelConfig] Fetch failed: $e');
      return const [];
    }
  }

  /// Ang active na model ng isang tier. null kapag offline,
  /// walang active row, o hindi pumasa sa safety check.
  static Future<ModelConfig?> fetchTier(ModelTier tier) async {
    final all = await fetchAll();
    return all.where((c) => c.tier == tier).firstOrNull;
  }

  /// Zoe Lite (default). Nandito pa para sa lumang tawag ng downloader.
  static Future<ModelConfig?> fetchActive() => fetchTier(ModelTier.lite);
}