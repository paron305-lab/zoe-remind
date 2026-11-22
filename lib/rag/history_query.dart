import 'package:zoe_remind/ai/parser/when_parser.dart';

/// Saklaw ng araw para sa tanong tungkol sa nakaraan (kasama pareho).
class HistoryRange {
  HistoryRange(DateTime from, DateTime to, {required this.en, required this.tl})
      : from = DateTime(from.year, from.month, from.day),
        to = DateTime(to.year, to.month, to.day);

  /// Isang araw lang.
  factory HistoryRange.day(DateTime day, {String en = '', String tl = ''}) =>
      HistoryRange(day, day, en: en, tl: tl);

  final DateTime from;
  final DateTime to;

  /// Pangalan ng saklaw ("Last week" / "Nakaraang linggo").
  final String en;
  final String tl;

  bool get isSingleDay => from == to;

  /// Ilang araw (kasama pareho).
  int get days =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays +
      1;

  @override
  String toString() => '$en ${from.toIso8601String().substring(0, 10)}'
      '–${to.toIso8601String().substring(0, 10)}';
}

/// "ano na-miss ko last week?", "ano natapos ko this month?",
/// "ano ginawa ko noong Lunes?" → saklaw ng araw.
///
/// Pure function (walang database; ipinapasa ang [now]), kaya nate-test sa
/// `flutter test test/rag/history_query_test.dart`.
///
///   kahapon / yesterday                    → kahapon
///   kamakalawa / day before yesterday      → 2 araw na ang nakaraan
///   nung isang araw / the other day / kamakailan → 3 araw bago ngayon – kahapon (B6)
///   ngayon / today / ngayong araw          → ngayon
///   last week / nakaraang linggo / noong isang linggo → Lunes–Linggo ng nakaraang linggo
///   this week / ngayong linggo / nitong linggo        → Lunes ngayong linggo – ngayon
///   last month / nakaraang buwan           → buong nakaraang buwan
///   this month / ngayong buwan             → ika-1 – ngayon
///   last 3 days / huling 3 araw / nakaraang tatlong araw → 3 araw hanggang ngayon
///   last 2 weeks / huling dalawang linggo  → 14 araw hanggang ngayon
///   this year / ngayong taon · last year   → buong taon (hanggang ngayon)
///   noong October / nung oktubre           → buong buwan (pinakahuling nakalipas)
///   nov 15 / noong nobyembre 15            → araw na iyon (nakaraan, hindi susunod na taon)
///   noong Lunes / last monday / sa lunes   → pinakahuling Lunes bago ngayon
///
/// [strict] = para sa tanong na pwedeng tungkol sa hinaharap ("ano schedule ko
/// sa lunes?"): malinaw na nakaraan lang ang tinatanggap (kahapon, last week,
/// noong Lunes, huling 3 araw…). Walang "ngayon", "this week", "sa lunes".
class HistoryQuery {
  HistoryQuery._();

  /// Hanggang ilang araw pabalik (2 taon — kasya ang buong "last year").
  static const maxDays = 731;

  static const _numbers = {
    'isa': 1, 'isang': 1, 'one': 1, 'a': 1,
    'dalawa': 2, 'dalawang': 2, 'two': 2,
    'tatlo': 3, 'tatlong': 3, 'three': 3,
    'apat': 4, 'four': 4,
    'lima': 5, 'limang': 5, 'five': 5,
    'anim': 6, 'six': 6,
    'pito': 7, 'pitong': 7, 'seven': 7,
    'walo': 8, 'walong': 8, 'eight': 8,
    'siyam': 9, 'nine': 9,
    'sampu': 10, 'sampung': 10, 'ten': 10,
  };

  /// Buong pangalan lang ng buwan (ang "mar", "jun" ay pwedeng salita / pangalan).
  static const _monthNames = {
    'january': 1, 'enero': 1, 'february': 2, 'pebrero': 2, 'march': 3, 'marso': 3,
    'april': 4, 'abril': 4, 'mayo': 5, 'june': 6, 'hunyo': 6, 'july': 7, 'hulyo': 7,
    'august': 8, 'agosto': 8, 'september': 9, 'setyembre': 9, 'october': 10,
    'oktubre': 10, 'november': 11, 'nobyembre': 11, 'december': 12, 'disyembre': 12,
  };

  static const _short = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static final _lastN = RegExp(
      r'\b(?:(?:the\s+)?(?:last|past|previous)|nakaraang|nakalipas\s+na|huling'
      r'|nitong\s+(?:nakaraang|huling))\s+(\d{1,3}|[a-z]+)(?:\s+na)?\s+(days?|araw|weeks?|linggo)\b');
  static final _lastWeek = RegExp(r'\b(?:last|previous)\s+week\b'
      r'|\b(?:nakaraang|noong\s+isang|nung\s+isang|nakalipas\s+na)\s+linggo\b');
  static final _thisWeek = RegExp(r'\bthis\s+week\b|\b(?:ngayong|nitong)\s+linggo\b'
      r"|\blinggo\s+na\s+(?:ito|'?to)\b");
  static final _lastMonth = RegExp(r'\b(?:last|previous)\s+month\b'
      r'|\b(?:nakaraang|noong\s+isang|nung\s+isang|nakalipas\s+na)\s+buwan\b');
  static final _thisMonth = RegExp(r'\bthis\s+month\b|\b(?:ngayong|nitong)\s+buwan\b'
      r"|\bbuwan\s+na\s+(?:ito|'?to)\b");
  static final _lastYear = RegExp(r'\b(?:last|previous)\s+year\b'
      r'|\b(?:nakaraang|noong\s+isang|nung\s+isang|nakalipas\s+na)\s+taon\b');
  static final _thisYear = RegExp(r'\bthis\s+year\b|\b(?:ngayong|nitong)\s+taon\b');
  static final _dayBefore = RegExp(r'\bkamakalawa\b|\bday\s+before\s+yesterday\b');
  // B6: "nung isang araw" = ilang araw na ang nakaraan (hindi ngayon).
  static final _otherDay = RegExp(r'\b(?:nung|noong)\s+isang\s+araw\b|\bthe\s+other\s+day\b'
      r'|\bkamakailan\b|\b(?:a\s+)?few\s+days\s+ago\b');
  static final _yesterday = RegExp(r'\b(?:kahapon|yesterday)\b');
  static final _today = RegExp(r'\b(?:today|ngayong\s+araw|ngayon)\b');
  static final _month = RegExp(
      '\\b(noong|nung|in|last|sa)?\\s*(${_monthNames.keys.join('|')})\\b');
  static final _pastWeekday = RegExp(
      '\\b(?:noong|nung|last|nakaraang)\\s+(?:${WhenParser.weekdays.keys.join('|')})\\b');

  static DateTime _d(int y, int m, int d) => DateTime(y, m, d);

  /// Huling [n] araw hanggang ngayon (kasama ngayon).
  static HistoryRange lastDays(int n, {required DateTime now}) {
    final today = _d(now.year, now.month, now.day);
    return HistoryRange(_d(today.year, today.month, today.day - (n - 1)), today,
        en: 'Last $n days', tl: 'Huling $n araw');
  }

  /// Ang saklaw sa [lower] (maliit na titik), o null kung walang nabanggit.
  static HistoryRange? range(String lower, {required DateTime now, bool strict = false}) {
    final r = _range(lower, now, strict);
    if (r == null) return null;
    final today = _d(now.year, now.month, now.day);
    final oldest = _d(today.year, today.month, today.day - (maxDays - 1));
    final from = r.from.isBefore(oldest) ? oldest : r.from;
    final to = r.to.isAfter(today) ? today : r.to;
    if (to.isBefore(from)) return null;
    return HistoryRange(from, to, en: r.en, tl: r.tl);
  }

  static HistoryRange? _range(String lower, DateTime now, bool strict) {
    final today = _d(now.year, now.month, now.day);
    final y = today.year, m = today.month, d = today.day;
    final monday = _d(y, m, d - (today.weekday - 1));

    // "nov 15", "noong nobyembre 15" → nakaraang araw na iyon.
    final exact = RegExp(WhenParser.monthDatePattern).firstMatch(lower);
    if (exact != null) {
      final month = WhenParser.months[exact.group(1)!]!;
      final day = int.parse(exact.group(2)!);
      final year = int.tryParse(exact.group(3) ?? '');
      var date = _d(year ?? y, month, day);
      if (date.month != month) return null; // "feb 31"
      if (year == null && date.isAfter(today)) {
        if (strict) return null; // "ano schedule ko sa nov 25?" → hinaharap
        date = _d(y - 1, month, day);
      }
      if (strict && !date.isBefore(today)) return null;
      return HistoryRange.day(date);
    }

    final n = _lastN.firstMatch(lower);
    if (n != null) {
      final count = int.tryParse(n.group(1)!) ?? _numbers[n.group(1)!];
      if (count != null && count > 0) {
        final weeks = n.group(2)!.startsWith('week') || n.group(2) == 'linggo';
        final days = weeks ? count * 7 : count;
        final r = lastDays(days > maxDays ? maxDays : days, now: now);
        return weeks
            ? HistoryRange(r.from, r.to,
                en: 'Last $count ${count == 1 ? 'week' : 'weeks'}', tl: 'Huling $count linggo')
            : r;
      }
    }

    if (_lastWeek.hasMatch(lower)) {
      final mon = monday.month, my = monday.year;
      return HistoryRange(_d(my, mon, monday.day - 7), _d(my, mon, monday.day - 1),
          en: 'Last week', tl: 'Nakaraang linggo');
    }
    if (_lastMonth.hasMatch(lower)) {
      return HistoryRange(_d(y, m - 1, 1), _d(y, m, 0), en: 'Last month', tl: 'Nakaraang buwan');
    }
    if (_lastYear.hasMatch(lower)) {
      return HistoryRange(_d(y - 1, 1, 1), _d(y - 1, 12, 31), en: 'Last year', tl: 'Nakaraang taon');
    }
    if (_dayBefore.hasMatch(lower)) return HistoryRange.day(_d(y, m, d - 2));
    if (_otherDay.hasMatch(lower)) {
      return HistoryRange(_d(y, m, d - 3), _d(y, m, d - 1),
          en: 'The other day', tl: 'Nung isang araw');
    }
    if (_yesterday.hasMatch(lower)) return HistoryRange.day(_d(y, m, d - 1));

    if (!strict) {
      if (_thisWeek.hasMatch(lower)) {
        return HistoryRange(monday, today, en: 'This week', tl: 'Ngayong linggo');
      }
      if (_thisMonth.hasMatch(lower)) {
        return HistoryRange(_d(y, m, 1), today, en: 'This month', tl: 'Ngayong buwan');
      }
      if (_thisYear.hasMatch(lower)) {
        return HistoryRange(_d(y, 1, 1), today, en: 'This year', tl: 'Ngayong taon');
      }
    }

    // "noong October" → buong buwan (pinakahuling nakalipas o ngayong buwan).
    final month = _month.firstMatch(lower);
    if (month != null && (!strict || {'noong', 'nung', 'last'}.contains(month.group(1)))) {
      final mm = _monthNames[month.group(2)!]!;
      final yy = mm > m ? y - 1 : y;
      final label = '${_short[mm - 1]} $yy';
      return HistoryRange(_d(yy, mm, 1), _d(yy, mm + 1, 0), en: label, tl: label);
    }

    if (!strict && _today.hasMatch(lower)) return HistoryRange.day(today);

    // "noong Lunes", "last monday" (strict) · "sa lunes", "lunes" (hindi strict)
    if (strict && !_pastWeekday.hasMatch(lower)) return null;
    final past = WhenParser.pastDay(lower, now: now);
    return past == null ? null : HistoryRange.day(past);
  }
}