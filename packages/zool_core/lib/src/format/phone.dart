import 'money.dart' show latinDigits;

/// Sudan numbers: the user types the local part (9XXXXXXXX or 09XXXXXXXX); the API takes E.164.
const String kSudanDialCode = '+249';

/// "0912345678" / "912345678" / "+249912345678" / "00249912345678" → "+249912345678"; null when invalid.
String? normalizeSudanPhone(String input) {
  var s = latinDigits(input).replaceAll(RegExp(r'[\s\-()]'), '');
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (s.startsWith('+')) {
    return RegExp(r'^\+\d{9,15}$').hasMatch(s) ? s : null;
  }
  if (s.startsWith('249') && s.length == 12) return '+$s';
  if (s.startsWith('0')) s = s.substring(1);
  return RegExp(r'^\d{9}$').hasMatch(s) ? '$kSudanDialCode$s' : null;
}

/// "+249912345678" → "+249 91 234 5678" for display, isolated left-to-right so it never reads
/// reversed inside Arabic text.
String formatPhone(String? e164) {
  if (e164 == null || e164.isEmpty) return '—';
  var text = e164;
  if (e164.startsWith(kSudanDialCode) && e164.length == 13) {
    final n = e164.substring(4);
    text = '$kSudanDialCode ${n.substring(0, 2)} ${n.substring(2, 5)} ${n.substring(5)}';
  }
  return '\u2066$text\u2069'; // left-to-right isolate
}
