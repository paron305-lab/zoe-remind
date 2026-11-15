/// Dalawang klase ng Zoe's Brain.
/// lite = Qwen3.5-0.8B (default, lahat ng phone)
/// plus = Qwen3.5-2B (optional download, 6 GB RAM pataas)
///
/// rowId = id ng row sa model_state (SQLite): 1 = lite, 2 = plus.
/// name ('lite' / 'plus') = kapareho ng `tier` column sa Supabase.
enum ModelTier {
  lite(1),
  plus(2);

  const ModelTier(this.rowId);
  final int rowId;

  ModelTier get other => this == lite ? plus : lite;

  /// null kapag hindi kilala ang value (hal. bagong tier sa server).
  static ModelTier? fromName(String? name) => values.asNameMap()[name];
}