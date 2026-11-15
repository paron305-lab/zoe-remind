/// App-wide info na pinapakita sa Settings › About.
class AppConfig {
  AppConfig._();

  static const appName = 'Zoe-Remind';
  static const company = 'Brixen AI';

  /// Dapat pareho sa `version:` sa pubspec.yaml (1.0.0+2 → '1.0.0', build 2).
  /// Palitan ang dalawa nang sabay tuwing may bagong release.
  /// Build 2: may Zoe Lite / Zoe Plus (dalawang model sa Settings).
  static const version = '1.0.0';
  static const build = 2;
}