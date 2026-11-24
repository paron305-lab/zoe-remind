import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/core/constants/zoe_language.dart';
import 'package:zoe_remind/features/companion/controllers/companion_lines.dart';
import 'package:zoe_remind/memory/companion_facts.dart';

/// Takbuhin:  flutter test test/companion/companion_lines_test.dart
///
/// Level 3: assets/prompts/companion_lines.json (~5,500 linya) — kumpleto ba,
/// tama ba ang {name} / {win}, at walang "po" (built-in na ang galang).
void main() {
  setUpAll(() {
    CompanionLines.loadFromString(File(CompanionLines.asset).readAsStringSync());
    CompanionLines.seed(7);
  });

  const styles = <TalkStyle?>[null, TalkStyle.diretso, TalkStyle.malambing];

  test('3k–10k linya', () {
    expect(CompanionLines.count, inInclusiveRange(3000, 10000));
  });

  test('bawat situation × language × style ay may linya', () {
    final missing = [
      for (final s in CompanionSituation.values)
        for (final lang in ZoeLanguage.values)
          for (final st in styles)
            if (CompanionLines.optionsFor(lang, s, st).isEmpty) '${s.name}/${lang.name}/${st?.value ?? 'default'}',
    ];
    expect(missing, isEmpty);
  });

  test('may linyang walang {name} sa bawat bucket (para sa walang nickname)', () {
    final missing = [
      for (final s in CompanionSituation.values)
        if (s != CompanionSituation.nickSaved)
          for (final lang in ZoeLanguage.values)
            for (final st in styles)
              if (!CompanionLines.optionsFor(lang, s, st).any((l) => !l.contains('{name}')))
                '${s.name}/${lang.name}/${st?.value ?? 'default'}',
    ];
    expect(missing, isEmpty);
  });

  test('winCheer: laging may {win}; ibang situation: walang {win}', () {
    for (final s in CompanionSituation.values) {
      for (final lang in ZoeLanguage.values) {
        for (final st in styles) {
          for (final l in CompanionLines.optionsFor(lang, s, st)) {
            expect(l.contains('{win}'), s == CompanionSituation.winCheer, reason: l);
          }
        }
      }
    }
  });

  test('walang "po", walang ibang {placeholder}, walang dobleng {name}', () {
    final po = RegExp(r'\bpo\b', caseSensitive: false);
    final ph = RegExp(r'\{(\w+)\}');
    for (final s in CompanionSituation.values) {
      for (final lang in ZoeLanguage.values) {
        for (final st in styles) {
          for (final l in CompanionLines.optionsFor(lang, s, st)) {
            expect(po.hasMatch(l), isFalse, reason: l);
            for (final m in ph.allMatches(l)) {
              expect(['name', 'win'], contains(m.group(1)), reason: l);
            }
            expect('{name}'.allMatches(l).length, lessThanOrEqualTo(1), reason: l);
          }
        }
      }
    }
  });

  test('pick: walang nickname → walang {name} sa sagot', () {
    for (var i = 0; i < 200; i++) {
      final l = CompanionLines.pick(ZoeLanguage.both, CompanionSituation.downListen,
          style: TalkStyle.malambing);
      expect(l, isNot(contains('{name}')));
    }
  });

  test('pick: may nickname → napapalitan', () {
    for (var i = 0; i < 50; i++) {
      final l = CompanionLines.pick(ZoeLanguage.tagalog, CompanionSituation.nickSaved, name: 'AC');
      expect(l, contains('AC'));
      expect(l, isNot(contains('{name}')));
    }
  });

  test('pick: winCheer kasama ang panalo', () {
    final l = CompanionLines.pick(ZoeLanguage.english, CompanionSituation.winCheer,
        vars: {'win': 'Nakapasa ako sa board exam'});
    expect(l, contains('Nakapasa ako sa board exam'));
  });

  test('pick: hindi paulit-ulit (huling 8)', () {
    final seen = <String>[];
    for (var i = 0; i < 9; i++) {
      seen.add(CompanionLines.pick(ZoeLanguage.english, CompanionSituation.downAdvice));
    }
    expect(seen.toSet().length, seen.length);
  });

  test('diretso: mas maikli kaysa malambing (karaniwan)', () {
    double avg(List<String> l) => l.fold<int>(0, (n, x) => n + x.length) / l.length;
    for (final lang in ZoeLanguage.values) {
      final d = CompanionLines.optionsFor(lang, CompanionSituation.downListen, TalkStyle.diretso);
      final m = CompanionLines.optionsFor(lang, CompanionSituation.downListen, TalkStyle.malambing);
      expect(avg(d), lessThan(avg(m)), reason: lang.name);
    }
  });
}