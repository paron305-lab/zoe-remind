import 'package:flutter/material.dart' show TimeOfDay;

/// Pagbasa ng ARAW at ORAS mula sa mensahe (English / Tagalog / Taglish).
///
/// Pure function (walang database, walang model, walang DateTime.now() sa loob —
/// ipinapasa ang [now]), kaya nate-test sa
/// `flutter test test/ai/when_parser_test.dart`.
///
/// Laging maliit na titik ang ipinapasang text (ginagawa ng brain).
///
/// Oras:
///   "7 PM", "7:30pm", "19:00", "noon", "tanghali"
///   "alas 7 ng gabi" → 19:00      "alas-8 ng umaga" → 8:00
///   "alas 12 ng tanghali" → 12:00 "alas 12 ng gabi" → 0:00
///   "alas 1 ng tanghali" → 13:00  "alas 3 ng madaling araw" → 3:00
///   "5 ng hapon" → 17:00          "bumili ng 5 ampalaya" → walang oras
///
/// Araw:
///   "bukas", "tomorrow", "today", "ngayon", "mamaya", "feb 12 2028"
///   "sa Biyernes", "on Friday"           → susunod na Biyernes
///   "sa Linggo"                          → susunod na Linggo (Sunday)
///   "sa susunod na linggo", "next week"  → Lunes ng susunod na linggo
///   "susunod na linggo, Biyernes"        → Biyernes ng susunod na linggo
///   "ngayong linggo", "this week"        → ngayon
///   "isang linggo", "kada linggo"        → walang araw (linggo = week, hindi Sunday)
class WhenParser {
  WhenParser._();

  static const weekdays = {
    'monday': 1, 'lunes': 1,
    'tuesday': 2, 'martes': 2,
    'wednesday': 3, 'miyerkules': 3,
    'thursday': 4, 'huwebes': 4,
    'friday': 5, 'biyernes': 5,
    'saturday': 6, 'sabado': 6,
    'sunday': 7, 'linggo': 7,
  };

  /// Walang "may" (Tagalog: "may 5 akong gagawin") — "mayo" ang gamitin.
  static const months = {
    'january': 1, 'jan': 1, 'enero': 1,
    'february': 2, 'feb': 2, 'pebrero': 2,
    'march': 3, 'mar': 3, 'marso': 3,
    'april': 4, 'apr': 4, 'abril': 4,
    'mayo': 5,
    'june': 6, 'jun': 6, 'hunyo': 6,
    'july': 7, 'jul': 7, 'hulyo': 7,
    'august': 8, 'aug': 8, 'agosto': 8,
    'september': 9, 'sept': 9, 'sep': 9, 'setyembre': 9,
    'october': 10, 'oct': 10, 'oktubre': 10,
    'november': 11, 'nov': 11, 'nobyembre': 11,
    'december': 12, 'dec': 12, 'disyembre': 12,
  };

  /// "feb 12", "Feb. 12, 2028", "disyembre 5" — buwan + araw (+ taon).
  /// Ginagamit din ng brain para tanggalin ang petsa sa title.
  static final monthDatePattern =
      '\\b(${months.keys.join('|')})\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?\\b';

  // ───────────────────────── Linggo = week ─────────────────────────

  /// "sa susunod na linggo", "next week".
  static final _nextWeek = RegExp(
      r'\b(sa\s+)?(susunod|sunod|darating)\s+na\s+linggo\b|\bnext\s+week\b');

  /// "ngayong linggo", "this week", "linggo na ito".
  static final _thisWeek = RegExp(
      r"\b(ngayong|nitong)\s+linggo\b|\bthis\s+week\b|\blinggo\s+na\s+(ito|'?to)\b");

  /// Iba pang "linggo" na ang ibig sabihin ay week (walang tiyak na araw).
  static final _otherWeek = RegExp(
      r'\b(nakaraang|nakalipas\s+na|noong\s+isang|isang|dalawang|tatlong|ilang|kada|bawat'
      r'|buong|sa\s+loob\s+ng)\s+linggo\b|\blinggo-linggo\b|\blingguhan\b|\blast\s+week\b');

  /// Tinatanggal ang mga "linggo" na week, para hindi mabasang Sunday.
  static String _withoutWeekWords(String lower) => lower
      .replaceAll(_nextWeek, ' ')
      .replaceAll(_thisWeek, ' ')
      .replaceAll(_otherWeek, ' ');

  // ───────────────────────── Araw ─────────────────────────

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _plusDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  /// Unang weekday na nabanggit (1 = Monday … 7 = Sunday), o null.
  static int? _weekdayIn(String lower) {
    for (final e in weekdays.entries) {
      if (RegExp('\\b${e.key}\\b').hasMatch(lower)) return e.value;
    }
    return null;
  }

  /// "feb 12", "disyembre 5 2027". Walang taon at lumipas na → susunod na taon.
  static DateTime? monthDate(String lower, {required DateTime now}) {
    final today = _dayOnly(now);
    final m = RegExp(monthDatePattern).firstMatch(lower);
    if (m == null) return null;
    final month = months[m.group(1)!]!;
    final dayNum = int.parse(m.group(2)!);
    final year = int.tryParse(m.group(3) ?? '');
    var date = DateTime(year ?? today.year, month, dayNum);
    if (date.month != month) return null; // hal. "feb 31"
    if (year == null && date.isBefore(today)) {
      date = DateTime(today.year + 1, month, dayNum);
    }
    return date;
  }

  /// Ang araw na tinutukoy (para sa bagong reminder / task / "busy ba ako…").
  /// null = walang nabanggit na araw.
  static DateTime? day(String lower, {required DateTime now}) {
    final today = _dayOnly(now);

    final exact = monthDate(lower, now: now);
    if (exact != null) return exact;

    if (RegExp(r'\b(tomorrow|bukas|kinabukasan)\b').hasMatch(lower)) {
      return _plusDays(today, 1);
    }

    final plain = _withoutWeekWords(lower);
    final weekday = _weekdayIn(plain);

    // "sa susunod na linggo" → Lunes ng susunod na linggo (+ weekday kung meron).
    if (_nextWeek.hasMatch(lower)) {
      final nextMonday = _plusDays(today, 8 - today.weekday);
      return _plusDays(nextMonday, (weekday ?? 1) - 1);
    }

    // "ngayong Biyernes", "this Friday" → Biyernes ngayong linggo (ngayon kung Biyernes ngayon).
    final thisDay =
        RegExp('\\b(ngayong|this)\\s+(${weekdays.keys.join('|')})\\b').firstMatch(plain);
    if (thisDay != null) {
      final w = weekdays[thisDay.group(2)!]!;
      return _plusDays(today, (w - today.weekday + 7) % 7);
    }

    // "ngayong linggo" na walang weekday → ngayon.
    if (_thisWeek.hasMatch(lower) && weekday == null) return today;

    if (RegExp(r'\b(today|ngayon|ngayong|mamaya|mamayang|tonight|later)\b').hasMatch(plain)) {
      return today;
    }

    if (weekday != null) {
      var ahead = (weekday - today.weekday + 7) % 7;
      if (ahead == 0) ahead = 7; // "on Monday" = susunod na Monday
      return _plusDays(today, ahead);
    }
    return null;
  }

  /// "last Monday" / "noong Lunes" → pinakahuling Monday bago ngayon.
  /// Ang "nakaraang linggo" (last week) ay HINDI Sunday → null.
  static DateTime? pastDay(String lower, {required DateTime now}) {
    final today = _dayOnly(now);
    final weekday = _weekdayIn(_withoutWeekWords(lower));
    if (weekday == null) return null;
    var back = (today.weekday - weekday + 7) % 7;
    if (back == 0) back = 7;
    return _plusDays(today, -back);
  }

  // ───────────────────────── Oras ─────────────────────────

  /// "7pm", "7:30 p.m." — may word boundary, kaya ang "5 ampalaya" ay hindi 5 AM.
  static final _ampm =
      RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am\b|pm\b|a\.m\.|p\.m\.)');

  /// "5 ng hapon", "7:30 ng gabi", "alas 3 ng madaling araw".
  static final _numberPeriod = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s+(?:ng|sa)\s+(umaga|tanghali|hapon|gabi|madaling[\s-]?araw)\b');

  /// "alas 7", "alas-8:30".
  static final _alas = RegExp(r'\balas[\s-]*(\d{1,2})(?::(\d{2}))?');

  /// Bahagi ng araw kahit saan sa mensahe ("bukas ng gabi alas 8").
  static final _periodWord = RegExp(
      r'\b(madaling[\s-]?araw|umaga|tanghali|hapon|gabi|morning|afternoon|evening|tonight|night)\b');

  static final _h24 = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b');

  /// Oras sa mensahe, o null kung wala.
  static TimeOfDay? time(String lower) {
    final ampm = _ampm.firstMatch(lower);
    if (ampm != null) {
      final h = int.parse(ampm.group(1)!);
      final m = int.tryParse(ampm.group(2) ?? '') ?? 0;
      if (h < 1 || h > 12 || m > 59) return null;
      final pm = ampm.group(3)!.startsWith('p');
      return TimeOfDay(hour: h % 12 + (pm ? 12 : 0), minute: m);
    }

    final numberPeriod = _numberPeriod.firstMatch(lower);
    if (numberPeriod != null) {
      final t = _withPeriod(numberPeriod.group(1)!, numberPeriod.group(2), numberPeriod.group(3));
      if (t != null) return t;
    }

    final alas = _alas.firstMatch(lower);
    if (alas != null) {
      return _withPeriod(alas.group(1)!, alas.group(2), _periodWord.firstMatch(lower)?.group(1));
    }

    final h24 = _h24.firstMatch(lower);
    if (h24 != null) {
      return TimeOfDay(hour: int.parse(h24.group(1)!), minute: int.parse(h24.group(2)!));
    }
    if (RegExp(r'\b(noon|tanghali)\b').hasMatch(lower)) {
      return const TimeOfDay(hour: 12, minute: 0);
    }
    if (RegExp(r'\b(midnight|hatinggabi|hating-gabi)\b').hasMatch(lower)) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
    return null;
  }

  /// Oras na 1–12 + bahagi ng araw → 24h.
  static TimeOfDay? _withPeriod(String hour, String? minute, String? period) {
    final h = int.parse(hour);
    final m = int.tryParse(minute ?? '') ?? 0;
    if (h < 1 || h > 12 || m > 59) return null;
    final p = (period ?? '').replaceAll(RegExp(r'[\s-]'), '');
    final int h24;
    switch (p) {
      case 'madalingaraw':
      case 'umaga':
      case 'morning':
        h24 = h == 12 ? 0 : h; // alas 3 ng madaling araw = 3:00
      case 'tanghali':
        // alas 12 ng tanghali = 12:00, alas 1 ng tanghali = 13:00, alas 11 = 11:00
        h24 = h == 12 || h >= 11 ? h : (h <= 4 ? h + 12 : h);
      case 'hapon':
      case 'afternoon':
        h24 = h == 12 ? 12 : h + 12;
      case 'gabi':
      case 'evening':
      case 'tonight':
      case 'night':
        h24 = h == 12 ? 0 : h + 12; // alas 12 ng gabi = 0:00 (hatinggabi)
      default:
        h24 = h == 12 ? 12 : h; // "alas 12" lang → tanghali
    }
    return TimeOfDay(hour: h24, minute: m);
  }
}