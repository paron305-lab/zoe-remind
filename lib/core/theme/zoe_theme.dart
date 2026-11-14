import 'package:flutter/material.dart';
import 'package:zoe_remind/database/repositories/settings_repository.dart';

/// Light / dark switch para sa buong app (Settings › Appearance › Dark mode).
///
/// Lahat ng color tokens (HomeColors, NoteColors, TaskColors, ZoeColors,
/// SettingsPalette) ay getters na tumitingin sa [isDark]. Kapag pinalitan,
/// ini-rebuild ng ZoeApp ang buong widget tree para lumipat agad ang kulay
/// ng bawat screen — walang nawawalang state (naka-type, scroll, tab).
class ZoeTheme {
  ZoeTheme._();

  /// true = dark. Pinapakinggan ng ZoeApp.
  static final dark = ValueNotifier<bool>(false);

  static bool get isDark => dark.value;

  /// Light o dark na kulay, depende sa kasalukuyang mode.
  static Color pick(Color light, Color darkColor) => isDark ? darkColor : light;

  /// Basahin ang naka-save na setting. Tawagin sa main() bago ang runApp().
  static Future<void> load() async {
    try {
      dark.value = await SettingsRepository().isDarkMode();
    } catch (e) {
      debugPrint('Loading dark mode failed: $e');
    }
  }

  /// I-save at ilapat agad sa buong app.
  static Future<void> setDark(bool on) async {
    dark.value = on;
    await SettingsRepository().setDarkMode(on);
  }
}