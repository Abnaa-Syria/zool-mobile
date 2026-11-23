import '../config.dart';

/// Dates come as ISO UTC and are shown in Sudan time (Africa/Khartoum, fixed UTC+2). Digits are Latin.
const List<String> kArabicMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// DateTime.weekday: 1 = Monday … 7 = Sunday.
const List<String> kArabicWeekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

/// The wall-clock time in Sudan for [instant] (returned as a UTC DateTime holding Sudan fields).
DateTime toSudan(DateTime instant) => instant.toUtc().add(ZoolConfig.sudanOffset);

/// Now, in Sudan wall-clock fields.
DateTime sudanNow() => toSudan(DateTime.now());

String _two(int n) => n.toString().padLeft(2, '0');

/// "YYYY-MM-DD" Sudan day of [instant] (API `date=` parameters are Sudan days).
String sudanDay([DateTime? instant]) {
  final d = toSudan(instant ?? DateTime.now());
  return '${d.year}-${_two(d.month)}-${_two(d.day)}';
}

/// "YYYY-MM-DD" from a calendar date picked in the UI (its fields are taken as-is).
String dayKey(DateTime calendarDate) => '${calendarDate.year}-${_two(calendarDate.month)}-${_two(calendarDate.day)}';

/// Parses "YYYY-MM-DD" into a calendar date (local fields).
DateTime? parseDayKey(String? key) {
  if (key == null) return null;
  final p = key.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// "06:30 ص"
String formatTime(DateTime? instant) {
  if (instant == null) return '—';
  final d = toSudan(instant);
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_two(h12)}:${_two(d.minute)} ${d.hour < 12 ? 'ص' : 'م'}';
}

/// "22 نوفمبر"
String formatDayMonth(DateTime? instant) {
  if (instant == null) return '—';
  final d = toSudan(instant);
  return '${d.day} ${kArabicMonths[d.month - 1]}';
}

/// "الأحد، 22 نوفمبر 2026"
String formatLongDate(DateTime? instant) {
  if (instant == null) return '—';
  final d = toSudan(instant);
  return '${kArabicWeekdays[d.weekday - 1]}، ${d.day} ${kArabicMonths[d.month - 1]} ${d.year}';
}

/// Same for a calendar date picked in the UI (no timezone shift).
String formatCalendarDate(DateTime date) =>
    '${kArabicWeekdays[date.weekday - 1]}، ${date.day} ${kArabicMonths[date.month - 1]} ${date.year}';

/// "22 نوفمبر، 06:30 ص"
String formatDateTime(DateTime? instant) => instant == null ? '—' : '${formatDayMonth(instant)}، ${formatTime(instant)}';

/// "3 س 45 د"
String formatDuration(int? minutes) {
  if (minutes == null || minutes <= 0) return '—';
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m د';
  return m == 0 ? '$h س' : '$h س $m د';
}

/// "04:59" countdown text.
String formatCountdown(Duration left) {
  final s = left.inSeconds < 0 ? 0 : left.inSeconds;
  return '${_two(s ~/ 60)}:${_two(s % 60)}';
}

/// "منذ 5 دقائق" style relative time for feeds.
String formatRelative(DateTime? instant, {DateTime? now}) {
  if (instant == null) return '';
  final diff = (now ?? DateTime.now()).difference(instant);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
  return formatDayMonth(instant);
}
