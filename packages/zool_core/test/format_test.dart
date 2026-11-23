import 'package:flutter_test/flutter_test.dart';
import 'package:zool_core/zool_core.dart';

void main() {
  group('money', () {
    test('formats minor units as SDG with Latin digits', () {
      expect(formatSdg(3500000), '35,000 ج.س');
      expect(formatSdg(150), '1.50 ج.س');
      expect(formatSdg(null), '—');
      expect(formatSignedSdg(100000, credit: false), '−1,000 ج.س');
    });

    test('parses typed pounds, including Arabic digits', () {
      expect(parseSdgToMinor('35,000'), 3500000);
      expect(parseSdgToMinor('٢٥٠'), 25000);
      expect(parseSdgToMinor('0'), isNull);
      expect(parseSdgToMinor('abc'), isNull);
    });
  });

  group('phone', () {
    test('normalizes Sudan numbers to E.164', () {
      expect(normalizeSudanPhone('912345678'), '+249912345678');
      expect(normalizeSudanPhone('0912345678'), '+249912345678');
      expect(normalizeSudanPhone('00249912345678'), '+249912345678');
      expect(normalizeSudanPhone('+249 91 234 5678'), '+249912345678');
      expect(normalizeSudanPhone('٠٩١٢٣٤٥٦٧٨'), '+249912345678');
      expect(normalizeSudanPhone('12345'), isNull);
    });

    test('formats for display', () {
      expect(formatPhone('+249912345678'), '\u2066+249 91 234 5678\u2069');
      expect(seatsLabel(1), 'مقعد واحد');
      expect(seatsLabel(5), '5 مقاعد');
      expect(seatsLabel(28), '28 مقعدًا');
    });
  });

  group('dates (Sudan time, UTC+2)', () {
    test('shows UTC instants in Khartoum time', () {
      final instant = DateTime.utc(2026, 11, 23, 5, 0); // 07:00 in Khartoum
      expect(formatTime(instant), '07:00 ص');
      expect(formatDayMonth(instant), '23 نوفمبر');
    });

    test('Sudan day rolls over at 22:00 UTC', () {
      expect(sudanDay(DateTime.utc(2026, 11, 23, 21, 59)), '2026-11-23');
      expect(sudanDay(DateTime.utc(2026, 11, 23, 22, 0)), '2026-11-24');
    });

    test('durations and countdowns', () {
      expect(formatDuration(225), '3 س 45 د');
      expect(formatDuration(60), '1 س');
      expect(formatCountdown(const Duration(seconds: 299)), '04:59');
      expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('errors', () {
    test('maps codes to Arabic and never shows the API message', () {
      expect(errorMessage(ApiException(code: 'INSUFFICIENT_BALANCE', message: 'x', statusCode: 409)), 'رصيد المحفظة غير كافٍ.');
      expect(errorMessage(ApiException.network()), contains('الإنترنت'));
      expect(
        errorMessage(ApiException(code: 'CHANGE_NOT_ALLOWED', message: 'x', details: {'cutoffMinutes': 120})),
        contains('120 دقيقة'),
      );
      expect(errorMessage(ApiException(code: 'UNKNOWN_X', message: 'English text', statusCode: 400)), 'حدث خطأ غير متوقع.');
    });
  });
}
