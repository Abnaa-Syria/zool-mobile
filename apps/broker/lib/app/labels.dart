import 'package:zool_ui/zool_ui.dart';

/// Arabic labels for API enums (same wording as the broker web panel).
(String, BadgeTone) bookingStatus(String status) => switch (status) {
      'CONFIRMED' => ('مؤكد', BadgeTone.success),
      'CANCELLED' => ('ملغى', BadgeTone.error),
      'PENDING_PAYMENT' => ('بانتظار الدفع', BadgeTone.warning),
      'CHANGED' => ('مُعدّل', BadgeTone.info),
      _ => (status, BadgeTone.neutral),
    };

(String, BadgeTone) boardingStatus(String status) => switch (status) {
      'BOARDED' => ('صعد الحافلة', BadgeTone.success),
      'NO_SHOW' => ('لم يحضر', BadgeTone.error),
      _ => ('لم يصعد بعد', BadgeTone.neutral),
    };

(String, BadgeTone) topUpStatus(String status) => switch (status) {
      'PENDING' => ('بانتظار تأكيد الدفع', BadgeTone.warning),
      'PENDING_REVIEW' => ('قيد مراجعة المنصة', BadgeTone.info),
      'CONFIRMED' => ('تم الشحن', BadgeTone.success),
      'FAILED' => ('مرفوض / فشل', BadgeTone.error),
      _ => (status, BadgeTone.neutral),
    };

(String, BadgeTone) accrualStatus(String status) => switch (status) {
      'UNSETTLED' => ('غير مُسوّاة', BadgeTone.warning),
      'RESERVED' => ('محجوزة لتسوية', BadgeTone.info),
      'SETTLED' => ('مُسوّاة', BadgeTone.success),
      'CLAWED_BACK' => ('مستردة (إلغاء)', BadgeTone.error),
      _ => (status, BadgeTone.neutral),
    };

String ledgerType(String type) => switch (type) {
      'CREDIT_TOPUP' => 'شحن المحفظة',
      'DEBIT_BOOKING' => 'خصم حجز',
      'CREDIT_REFUND' => 'استرداد',
      'DEBIT_COMMISSION_PAYOUT' => 'تسوية عمولة',
      _ => type,
    };

String serviceClass(String c) => c == 'VIP' ? 'VIP' : 'عادية';

String commissionStatus(String? s) => s == null ? '—' : accrualStatus(s).$1;

String roleLabel(String role) => role == 'MANAGER' ? 'مدير المكتب' : 'موظف حجز';

String? legLabel(String? leg) => switch (leg) {
      'OUTBOUND' => 'ذهاب',
      'RETURN' => 'عودة',
      _ => null,
    };
