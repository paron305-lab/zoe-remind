import 'package:zoe_remind/features/companion/controllers/mood_controller.dart';
import 'package:zoe_remind/features/companion/controllers/mood_engine.dart';
import 'package:zoe_remind/features/companion/models/mood_state.dart';

/// Ano ang mood ni Zoe NGAYON — para sa pagpili ng salita (Chat at Home).
///
/// Bakit kailangan pa ito kung may `MoodController.mood`?
///  • Ang naka-save na mood ay nagbabago lang kapag may event. Kung 2 oras
///    na ang "happy", dapat "content" na — kaya dina-[decay] muna.
///  • Habang nag-iisip si Zoe (focused), ang mood BAGO mag-isip ang ginagamit
///    sa salita. Ang "focused" ay maikling status lang, hindi boses.
class MoodNow {
  MoodNow._();

  static const _engine = MoodEngine();

  /// PURE: (naka-save na mood, oras ngayon) → mood na gagamitin sa salita.
  static MoodState of(ZoeMood mood, DateTime now) {
    final m = _engine.decay(mood, now);
    if (m.state != MoodState.focused) return m.state;
    final before = m.previous;
    if (before == null) return MoodState.content;
    return of(before, now);
  }

  /// Mood ngayon mula sa MoodController. Content kapag hindi pa nagsisimula.
  static MoodState get current => of(MoodController.instance.mood.value, DateTime.now());
}