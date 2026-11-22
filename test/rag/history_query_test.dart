import 'package:flutter_test/flutter_test.dart';
import 'package:zoe_remind/rag/history_query.dart';

/// Takbuhin:  flutter test test/rag/history_query_test.dart
///
/// B4: saklaw ng araw sa tanong tungkol sa nakaraan.
void main() {
  // Sabado, Nov 21, 2026, 8 PM. Lunes ng linggong ito = Nov 16.
  final now = DateTime(2026, 11, 21, 20, 0);

  String? span(String q, {bool strict = false, DateTime? at}) {
    final r = HistoryQuery.range(q, now: at ?? now, strict: strict);
    if (r == null) return null;
    String k(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return r.isSingleDay ? k(r.from) : '${k(r.from)}..${k(r.to)}';
  }

  group('isang araw', () {
    final cases = {
      'ano ginawa ko kahapon?': '2026-11-20',
      'what did i do yesterday': '2026-11-20',
      'ano natapos ko kamakalawa': '2026-11-19',
      'ano natapos ko ngayon?': '2026-11-21',
      'ano natapos ko noong lunes?': '2026-11-16',
      'what did i finish last friday': '2026-11-20',
      'ano ginawa ko noong sabado?': '2026-11-14', // Sabado ngayon → nakaraang Sabado
      'ano natapos ko noong nov 15?': '2026-11-15',
      'ano ginawa ko dec 25': '2025-12-25', // walang taon + hinaharap → nakaraang taon
    };
    cases.forEach((q, expected) => test('"$q" → $expected', () => expect(span(q), expected)));
  });

  group('ilang araw', () {
    final cases = {
      'ano na-miss ko last week?': '2026-11-09..2026-11-15',
      'ano na-miss ko noong isang linggo?': '2026-11-09..2026-11-15',
      // B6: "nung isang araw" = 3 araw bago ngayon hanggang kahapon
      'nakaligtaan ko ba yung bayarin nung isang araw?': '2026-11-18..2026-11-20',
      'ano natapos ko noong isang araw': '2026-11-18..2026-11-20',
      'what did i miss the other day': '2026-11-18..2026-11-20',
      'may na-miss ba ako kamakailan?': '2026-11-18..2026-11-20',
      'ano natapos ko nakaraang linggo': '2026-11-09..2026-11-15',
      'ano natapos ko this week?': '2026-11-16..2026-11-21',
      'ano na-miss ko ngayong linggo': '2026-11-16..2026-11-21',
      'what did i miss last month': '2026-10-01..2026-10-31',
      'ano natapos ko nitong buwan?': '2026-11-01..2026-11-21',
      'ano na-miss ko sa huling 3 araw?': '2026-11-19..2026-11-21',
      'what did i miss in the last 3 days': '2026-11-19..2026-11-21',
      'ano na-miss ko sa nakaraang tatlong araw': '2026-11-19..2026-11-21',
      'ano natapos ko sa huling apat na araw': '2026-11-18..2026-11-21',
      'what did i finish in the past 2 weeks': '2026-11-08..2026-11-21',
      'ano natapos ko sa huling dalawang linggo': '2026-11-08..2026-11-21',
      'ano natapos ko noong october?': '2026-10-01..2026-10-31',
      'ano na-miss ko nung disyembre': '2025-12-01..2025-12-31',
      'ano natapos ko ngayong taon': '2026-01-01..2026-11-21',
      'what did i finish last year': '2025-01-01..2025-12-31',
    };
    cases.forEach((q, expected) => test('"$q" → $expected', () => expect(span(q), expected)));
  });

  test('walang nabanggit na araw → null', () {
    expect(span('ano na-miss ko?'), isNull);
    expect(span('may na-miss ba ako?'), isNull); // "may" ≠ May (buwan)
  });

  test('last week kapag ibang buwan ang Lunes (Martes, Dec 1 / Miyerkules, Dec 2)', () {
    expect(span('last week', at: DateTime(2026, 12, 1, 9)), '2026-11-23..2026-11-29');
    expect(span('last week', at: DateTime(2026, 12, 2, 9)), '2026-11-23..2026-11-29');
    expect(span('last month', at: DateTime(2027, 1, 5)), '2026-12-01..2026-12-31');
  });

  test('hanggang ${HistoryQuery.maxDays} araw lang', () {
    expect(HistoryQuery.range('last 500 days', now: now)!.days, 500);
    final r = HistoryQuery.range('last 900 days', now: now)!;
    expect(r.days, HistoryQuery.maxDays);
    expect(r.to, DateTime(2026, 11, 21));
  });

  group('strict (para sa "ano schedule ko…"): malinaw na nakaraan lang', () {
    test('kahapon, noong Lunes, last week, huling 3 araw → oo', () {
      expect(span('ano mga tasks ko kahapon?', strict: true), '2026-11-20');
      expect(span('ano reminders ko noong lunes', strict: true), '2026-11-16');
      expect(span('anong tasks ko last week', strict: true), '2026-11-09..2026-11-15');
      expect(span('tasks ko sa huling 3 araw', strict: true), '2026-11-19..2026-11-21');
    });
    test('sa lunes, ngayon, this week, nov 25 (hinaharap) → null', () {
      expect(span('ano gagawin ko sa lunes?', strict: true), isNull);
      expect(span('ano tasks ko ngayon?', strict: true), isNull);
      expect(span('ano reminders ko this week?', strict: true), isNull);
      expect(span('ano schedule ko sa nov 25?', strict: true), isNull);
      expect(span('may meeting ba ako sa october?', strict: true), isNull);
    });
  });

  test('labels', () {
    final r = HistoryQuery.range('last week', now: now)!;
    expect((r.en, r.tl), ('Last week', 'Nakaraang linggo'));
    final d = HistoryQuery.lastDays(7, now: now);
    expect((d.en, d.tl), ('Last 7 days', 'Huling 7 araw'));
    expect(d.days, 7);
  });

  test('B6: "nung isang araw" ay malinaw na nakaraan (strict OK)', () {
    expect(span('ano mga tasks ko nung isang araw?', strict: true), '2026-11-18..2026-11-20');
  });
}