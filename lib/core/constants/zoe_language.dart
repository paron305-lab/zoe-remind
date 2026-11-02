/// Zoe's prompt-level language mode. One model, three modes.
enum ZoeLanguage {
  english('English', "I'll reply in English.", 'assets/prompts/english.json'),
  tagalog('Tagalog', 'Sasagot ako sa Filipino.', 'assets/prompts/tagalog.json'),
  both('Both', 'Halo — English at Tagalog/Taglish.', 'assets/prompts/both.json');

  const ZoeLanguage(this.label, this.description, this.promptAsset);

  final String label;
  final String description;

  /// Used later in Phase 6 (Local AI). Not loaded during onboarding.
  final String promptAsset;
}