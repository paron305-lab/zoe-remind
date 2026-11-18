import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/ai/parser/when_parser.dart';

/// Takbuhin:  flutter test test/ai/when_parser_test.dart
/// Pure code — walang phone, walang database, walang model.
void main() {
  // Miyerkules, Nov 18, 2026, 3:00 PM (para pare-pareho ang sagot kahit kailan i-run).
  final now = DateTime(2026, 11, 18, 15, 0);

  String? hm(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void time(Map<String, String?> cases) {
    cases.forEach((text, want) {
      expect(hm(WhenParser.time(text)), want, reason: text);
    });
  }

  void day(Map<String, DateTime?> cases) {
    cases.forEach((text, want) {
      expect(WhenParser.day(text, now: now), want, reason: text);
    });
  }

  test('oras — am / pm / 24h', () {
    time({
      '7 pm': '19:00',
      '7:30pm': '19:30',
      'at 7 p.m.': '19:00',
      'gisingin mo ako bukas ng 5:30am': '05:30',
      '12am': '00:00',
      '12pm': '12:00',
      'at 19:00': '19:00',
      'noon': '12:00',
      'mamayang tanghali': '12:00',
      'hatinggabi': '00:00',
    });
  });

  test('oras — alas at bahagi ng araw', () {
    time({
      'alas 7 ng gabi': '19:00',
      'alas-8 ng umaga': '08:00',
      'alas 12 ng tanghali': '12:00',
      'alas 12 ng gabi': '00:00',
      'alas 12': '12:00',
      'alas 1 ng tanghali': '13:00',
      'alas 11 ng tanghali': '11:00',
      'alas 3 ng madaling araw': '03:00',
      'alas 5 ng hapon': '17:00',
      'alas 12 ng hapon': '12:00',
      'alas 7': '07:00',
      'bukas ng gabi alas 8': '20:00',
      'alas 7:30 ng gabi': '19:30',
      '5 ng hapon': '17:00',
      'sunduin si mama 6 ng gabi': '18:00',
    });
  });

  test('oras — hindi oras ang "5 ampalaya" at iba pa', () {
    time({
      'bumili ng 5 ampalaya': null,
      'kailangan kong bumili ng 2 pmasa': null,
      'magbayad ng kuryente': null,
      'alas 13 ng hapon': null,
    });
  });

  test('araw — karaniwan', () {
    day({
      'bukas': DateTime(2026, 11, 19),
      'remind me tomorrow at 7 pm': DateTime(2026, 11, 19),
      'ngayon': DateTime(2026, 11, 18),
      'mamayang gabi': DateTime(2026, 11, 18),
      'sa biyernes': DateTime(2026, 11, 20),
      'on wednesday': DateTime(2026, 11, 25), // Miyerkules ngayon → susunod na linggo
      'ngayong biyernes': DateTime(2026, 11, 20),
      'this wednesday': DateTime(2026, 11, 18),
      'feb 12 2028': DateTime(2028, 2, 12),
      'jan 5': DateTime(2027, 1, 5), // lumipas na ngayong taon
      'disyembre 25': DateTime(2026, 12, 25),
      'feb 31': null,
      'magbayad ng kuryente': null,
    });
  });

  test('araw — "linggo" bilang Sunday o week', () {
    day({
      'sa linggo': DateTime(2026, 11, 22), // Sunday
      'this sunday': DateTime(2026, 11, 22),
      'sa susunod na linggo': DateTime(2026, 11, 23), // Lunes ng susunod na linggo
      'next week': DateTime(2026, 11, 23),
      'sa susunod na linggo, biyernes': DateTime(2026, 11, 27),
      'next week friday': DateTime(2026, 11, 27),
      'ngayong linggo': DateTime(2026, 11, 18), // this week → ngayon
      'this week': DateTime(2026, 11, 18),
      'isang linggo': null,
      'kada linggo': null,
      'linggo-linggo': null,
    });
  });

  test('nakaraang araw', () {
    DateTime? past(String s) => WhenParser.pastDay(s, now: now);
    expect(past('noong lunes'), DateTime(2026, 11, 16));
    expect(past('last sunday'), DateTime(2026, 11, 15));
    expect(past('noong miyerkules'), DateTime(2026, 11, 11)); // isang linggo bago
    expect(past('nakaraang linggo'), isNull); // last week, hindi Sunday
    expect(past('kahapon'), isNull);
  });
}