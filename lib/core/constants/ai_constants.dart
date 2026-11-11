/// Zoe's on-device AI model (Zoe's Brain).
/// Isang model para sa lahat ng phones (low-end at high-end).
class AiConstants {
  AiConstants._();

  /// Pangalang pinapakita sa Settings › Zoe's Brain.
  /// Palitan kapag final na ang pick (Qwen3.5-0.8B o 2B).
  static const modelName = 'Qwen3.5-0.8B';

  /// Tantiya lang hangga't wala pang manifest.json galing Supabase.
  /// Kapag na-download na, ang totoong size_bytes sa model_state ang ipapakita.
  static const estimatedSizeMb = 500;
}