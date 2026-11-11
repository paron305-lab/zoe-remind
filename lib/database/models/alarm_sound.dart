/// Mga tunog ng alarm na pwedeng piliin sa Settings › Reminders.
/// Para magdagdag: ilagay ang mp3 sa assets/music/ at idagdag dito.
enum AlarmSound {
  morningZoe('Morning Zoe', 'assets/music/Morning_Zoe.mp3');

  const AlarmSound(this.label, this.asset);

  final String label;
  final String asset;

  static AlarmSound fromName(String? name) =>
      AlarmSound.values.asNameMap()[name] ?? AlarmSound.morningZoe;
}