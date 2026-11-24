import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/database/models/memory_item.dart';
import 'package:zoe_remind/memory/companion_facts.dart';
import 'package:zoe_remind/memory/companion_profile.dart';

/// Takbuhin:  flutter test test/memory/companion_profile_test.dart
///
/// Level 3: CompanionProfile.from — ang pinakabago ang nasusunod.
void main() {
  final t = DateTime(2026, 11, 24);
  MemoryItem m(String content, FactKind kind, [String? value]) =>
      MemoryItem(content: content, kind: kind, value: value, createdAt: t, updatedAt: t);

  test('walang laman → empty', () {
    expect(CompanionProfile.from(const []).isEmpty, isTrue);
  });

  test('nickname, style, stress help, wins, routines', () {
    final p = CompanionProfile.from([
      m('Tawagin akong AC', FactKind.nickname, 'AC'),
      m('Diretsuhin mo lang ako', FactKind.style, 'diretso'),
      m('Kapag stressed ako, makinig ka muna', FactKind.stressHelp, 'listen'),
      m('Nakapasa ako sa board exam', FactKind.win),
      m('Nag-gy-gym ako tuwing MWF', FactKind.routine),
      m('Mas gusto ko ng morning reminders', FactKind.general),
    ]);
    expect(p.nickname, 'AC');
    expect(p.style, TalkStyle.diretso);
    expect(p.isDiretso, isTrue);
    expect(p.stressHelp, StressHelp.listen);
    expect(p.wins, ['Nakapasa ako sa board exam']);
    expect(p.routines, ['Nag-gy-gym ako tuwing MWF']);
  });

  test('pinakabago muna (unang row ang nasusunod)', () {
    final p = CompanionProfile.from([
      m('Tawagin akong Pao', FactKind.nickname, 'Pao'),
      m('Tawagin akong AC', FactKind.nickname, 'AC'),
    ]);
    expect(p.nickname, 'Pao');
  });

  test('sirang value → hindi ginagamit', () {
    final p = CompanionProfile.from([
      m('?', FactKind.style, 'ewan'),
      m('?', FactKind.nickname, '  '),
    ]);
    expect(p.style, isNull);
    expect(p.nickname, isNull);
  });
}