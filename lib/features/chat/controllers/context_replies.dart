import 'package:zoe_remind/ai/parser/text_normalizer.dart';
import 'package:zoe_remind/ai/parser/when_parser.dart';
import 'package:zoe_remind/features/chat/models/chat_entry.dart';

/// Maiikling sagot na may kahulugan lang dahil sa NAUNANG tanong / card ni Zoe.
///
///   Card na naghihintay ng Accept:
///     "ay wag na pala", "cancel", "nvm", "huwag na"     → [isCancel] → Cancel
///     "oo", "sige", "yes pls", "go", "save mo na"       → [isYes]    → Accept
///     "mali, 8pm pala", "gawin mong 7pm", "bukas na lang" → [isCorrection] → bagong card
///   Tanong na "Reminder ba 'to, task, o note?":
///     "task", "reminder na lang", "i-note mo na lang"   → [kindFromText]
///
/// Pure functions (walang database) → `flutter test test/chat/context_replies_test.dart`.
/// Lahat ng check ay sa BUONG maikling mensahe — ang mahabang pangungusap
/// ("hindi ko na kailangan ng reminder para bukas…") ay hindi itinuturing na "cancel".
class ContextReplies {
  ContextReplies._();

  /// Text-speak → buong salita, maliit na titik, walang bantas / emoji sa dulo.
  static String clean(String text) => TextNormalizer.normalize(text)
      .toLowerCase()
      .replaceAll(RegExp(r'[!.?,~…]+'), ' ')
      .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Mga pampalambot na pwedeng nasa unahan / dulo ("ay", "po", "na lang", "zoe"…).
  static const _soft = r'(?:\s+(?:po|na|lang|na lang|nalang|muna|nga|naman|pala|ha|zoe|please'
      r'|thanks|thank you|salamat|mo na|ko na|yan|yun|na yan|na yun|ulit|talaga|din|rin'
      r'|ah|eh|oh|uy))*';
  static const _lead = r'^(?:(?:ay|ah|oh|uy|hmm+|wait|teka|sorry|zoe|actually|ahh?)\s+)*';

  static final _cancel = RegExp(
    '$_lead(?:'
    r'cancel|i-?cancel|cancel (?:mo|it|that|na)|kancel|wag|huwag|hwag|wag na|huwag na|hindi na'
    r'|di na|wag mo na|huwag mo na|wag mo nang ituloy|wag nalang|wag na lang|huwag na lang'
    r'|never ?mind|nevermind|forget it|forget that|scratch that|no|nope|nah|no need|no thanks'
    r'|hindi|ayoko|ayoko na|ayaw ko|ayaw|ekis|x|stop|skip|wala|wala na|wala lang|wala muna'
    r'|(?:wag|huwag) mo na(?:ng)? (?:ituloy|gawin|i-?save|isave)'
    r'|wag muna|huwag muna|di bale|hindi bale|okay lang wag na|ok lang wag na|delete|burahin'
    r"|don'?t|do not|not now|later na lang|mamaya na lang|next time na lang|i changed my mind"
    r'|nagbago isip ko|joke lang|charot|char|de joke|biro lang|undo'
    ')$_soft\$',
  );

  static final _yes = RegExp(
    '$_lead(?:'
    r'oo|opo|oo naman|oo nga|oo sige|o sige|osige|sige|sige po|sige na|go|go lang|g|game|gora'
    r'|ok|okay|okey|okie|oki|ok lang|ok sige|sige ok|sure|sure po|of course|yes|yes po|yep|yup'
    r'|yeah|ya|yah|yas|ye|yess+|tama|tama yan|tama yun|correct|that.?s right|that.?s correct'
    r'|right|exactly|ganun nga|ganon nga|ayan|ayun|ayos|ayos yan|goods|goods na|pwede|pwede na'
    r'|keri|push|push mo|tuloy|ituloy|ituloy mo|accept|i-?accept|save|i-?save|save mo|save it'
    r'|save na|do it|go ahead|confirm|confirmed|perfect|nice|sakto|swak|apir|g na|deal'
    r'|yes please|please do|sige save mo|sige i-save mo|oo i-save mo|oo save mo|sounds good'
    r'|looks good|all good|ok na|okay na|sige na nga'
    ')$_soft\$',
  );

  /// Mga palatandaan ng pagtatama ("mali", "pala", "na lang", "instead"…).
  static final _fixWord = RegExp(
    r'\b(?:mali|hindi|di|ay|actually|i mean|i meant|pala|na lang|nalang|instead|change|palitan'
    r'|gawin mo(?:ng)?|make it|move (?:it|to)|ilipat|i-?move|wait|teka|oops|sorry|correction'
    r'|ibig kong sabihin|dapat|switch|reschedule|i-?resched)\b',
  );

  static final _kindWords = <DraftKind, RegExp>{
    DraftKind.reminder: RegExp(
        r'\b(?:reminders?|paalala|alarm|remind(?: me)?|i-?remind|ipaalala|pa-?remind|alert)\b'),
    DraftKind.task: RegExp(r'\b(?:tasks?|to-?dos?|gawain|listahan|checklist)\b'),
    DraftKind.note: RegExp(r'\b(?:notes?|i-?note|isulat|i-?save as note|sulat|note lang)\b'),
    DraftKind.memory: RegExp(
        r'\b(?:tandaan|tandaan mo|remember|remember it|memory|alalahanin|isaisip|sa memory)\b'),
  };

  /// "cancel", "ay wag na pala", "nvm", "huwag na lang po" → true.
  static bool isCancel(String text) => _cancel.hasMatch(clean(text));

  /// "oo", "sige", "yes pls", "save mo na", "goods" → true.
  static bool isYes(String text) => _yes.hasMatch(clean(text));

  /// Sagot sa "Reminder ba 'to, task, o note?" → uri, o null kung hindi malinaw.
  /// Maikli lang (hanggang 6 na salita) at isang uri lang ang binanggit.
  ///   "task" / "task na lang po" / "gawin mong task" → task
  ///   "reminder please" / "paalala" / "alarm"        → reminder
  ///   "i-note mo na lang" / "note"                   → note
  ///   "tandaan mo lang" / "just remember it"         → memory
  static DraftKind? kindFromText(String text) {
    final t = clean(text);
    if (t.isEmpty || t.split(' ').length > 6) return null;
    DraftKind? found;
    for (final e in _kindWords.entries) {
      if (!e.value.hasMatch(t)) continue;
      if (found != null) return null; // dalawang uri → hindi malinaw
      found = e.key;
    }
    return found;
  }

  /// Pagtatama ng oras / araw sa card na naghihintay:
  ///   "mali, 8pm pala" · "gawin mong 7pm" · "bukas na lang" · "8pm" · "sa Sabado na lang"
  /// May oras o araw, AT maikli: may salitang pagtatama (hanggang 7 salita)
  /// o oras / araw lang (hanggang 4 na salita). Mahabang pangungusap → hindi.
  static bool isCorrection(String text, {required DateTime now}) {
    final t = clean(text);
    if (t.isEmpty) return false;
    final hasWhen = WhenParser.time(t) != null || WhenParser.day(t, now: now) != null;
    if (!hasWhen) return false;
    final words = t.split(' ').length;
    return (words <= 7 && _fixWord.hasMatch(t)) || words <= 4;
  }
}