import 'package:zoe_remind/core/constants/model_tier.dart';

/// Zoe's on-device AI models (Zoe's Brain).
/// Dalawa: Zoe Lite (lahat ng phone) at Zoe Plus (optional, 6 GB RAM pataas).
/// Ang totoong pangalan, size at link ay galing sa Supabase (model_config).
/// Ang mga nandito ay fallback lang kapag offline.
class AiConstants {
  AiConstants._();

  /// Pangalan ng Lite model file (fallback).
  static const modelName = 'Qwen3.5-0.8B';

  /// Tantiyang size ng Zoe Lite kapag hindi pa alam ang totoo.
  /// Kapag na-download na, ang totoong size_bytes sa model_state ang ipapakita.
  static const estimatedSizeMb = 500;

  /// Pangalang ipapakita kapag walang display_name galing sa server.
  static String fallbackName(ModelTier tier) =>
      tier == ModelTier.lite ? 'Zoe Lite' : 'Zoe Plus';
}