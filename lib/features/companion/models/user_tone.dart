/// Ang tono / nararamdaman ng USER sa isang mensahe (Personality plan, Level 1).
///
/// Iba ito sa MoodState: ang MoodState ay mood ni ZOE; ang UserTone ay
/// kung ano ang nababasa ni Zoe sa sinabi ng user ngayon.
///
/// Hindi ito diagnosis at hindi sine-save bilang "ugali" ng user.
/// Label lang ito para piliin ni Zoe ang tamang sagot (script).
enum UserTone {
  neutral,
  happy,
  tired,
  stressed,
  sad,
  upset,
  worried;

  /// Malungkot / pagod / stressed / inis / kinakabahan.
  bool get isDown => this != neutral && this != happy;
}

/// Resulta ng ToneDetector.
class ToneResult {
  final UserTone tone;

  /// 0 = neutral, 1 = mahina, 2 = halata, 3 = malakas ("sobrang pagod, puyat pa").
  final int strength;

  /// Mga salitang tumama — para sa debug at test.
  final List<String> matched;

  const ToneResult(this.tone, this.strength, [this.matched = const []]);

  static const neutral = ToneResult(UserTone.neutral, 0);

  @override
  String toString() => 'ToneResult(${tone.name}, $strength, $matched)';
}