import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase connection ng Zoe.
/// Offline-first: kapag walang keys o walang internet,
/// tuloy pa rin ang app (reminders, tasks, notes ay nasa SQLite).
class SupabaseService {
  SupabaseService._();

  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool _ready = false;

  /// true kapag naka-initialize na ang Supabase.
  static bool get isReady => _ready;

  /// Gamitin lang kapag isReady == true.
  static SupabaseClient? get client =>
      _ready ? Supabase.instance.client : null;

  /// Tawagin sa main.dart bago ang runApp().
  static Future<void> init() async {
    if (_url.isEmpty || _publishableKey.isEmpty) {
      debugPrint('[Supabase] Walang keys (env.json) — offline mode.');
      return;
    }
    try {
      await Supabase.initialize(
        url: _url,
        publishableKey: _publishableKey,
      );
      _ready = true;
      debugPrint('[Supabase] Ready ✅');
    } catch (e) {
      debugPrint('[Supabase] Init failed: $e');
    }
  }
}