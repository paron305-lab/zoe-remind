/// App-wide info na pinapakita sa Settings › About.
class AppConfig {
  AppConfig._();

  static const appName = 'Zoe-Remind';
  static const company = 'Brixen AI';

  /// Dapat pareho sa `version:` sa pubspec.yaml (1.0.0+1 → '1.0.0', build 1).
  /// Palitan ang dalawa nang sabay tuwing may bagong release.
  static const version = '1.0.0';
  static const build = 1;
}