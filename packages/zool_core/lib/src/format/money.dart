import 'package:intl/intl.dart';

/// Money is always integer minor units from the API (100 = 1 ج.س). Never compute prices in the
/// app; only display what the server returns.
final NumberFormat _whole = NumberFormat('#,##0', 'en_US');
final NumberFormat _fraction = NumberFormat('#,##0.00', 'en_US');

/// "35,000 ج.س" — decimals only when there are piasters.
String formatSdg(int? minor, {bool withCurrency = true}) {
  if (minor == null) return '—';
  final text = minor % 100 == 0 ? _whole.format(minor ~/ 100) : _fraction.format(minor / 100);
  return withCurrency ? '$text ج.س' : text;
}

/// "+35,000 ج.س" / "−35,000 ج.س" for ledger movements.
String formatSignedSdg(int minor, {required bool credit}) => '${credit ? '+' : '−'}${formatSdg(minor)}';

/// Parses an amount typed in pounds ("35000", "35,000.5") to minor units; null when invalid.
int? parseSdgToMinor(String input) {
  final cleaned = input.replaceAll(',', '').trim();
  final value = double.tryParse(_latinDigits(cleaned));
  if (value == null || value <= 0) return null;
  return (value * 100).round();
}

String _latinDigits(String s) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = arabic.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString();
}

/// Arabic-Indic / Persian digits → Latin (users type with Arabic keyboards).
String latinDigits(String s) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in _latinDigits(s).split('')) {
    final i = persian.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString();
}

/// Arabic counted noun: 1 → "مقعد واحد", 2 → "مقعدان", 3–10 → "5 مقاعد", 11+ → "12 مقعدًا".
String countLabel(int n, {required String one, required String two, required String few, required String many}) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n >= 3 && n <= 10) return '$n $few';
  return '$n $many';
}

String seatsLabel(int n) => n == 0 ? 'لا مقاعد' : countLabel(n, one: 'مقعد واحد', two: 'مقعدان', few: 'مقاعد', many: 'مقعدًا');

String ticketsLabel(int n) => n == 0 ? '0 تذاكر' : countLabel(n, one: 'تذكرة واحدة', two: 'تذكرتان', few: 'تذاكر', many: 'تذكرة');

/// "اختر مقعدًا" / "اختر مقعدين" / "اختر 3 مقاعد".
String pickSeatsLabel(int n) => n == 1 ? 'اختر مقعدًا' : (n == 2 ? 'اختر مقعدين' : 'اختر ${seatsLabel(n)}');

String travellersLabel(int n) => countLabel(n, one: 'مسافر واحد', two: 'مسافران', few: 'مسافرين', many: 'مسافرًا');
