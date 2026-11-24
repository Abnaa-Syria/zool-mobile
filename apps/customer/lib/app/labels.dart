import 'package:zool_ui/zool_ui.dart';

import '../data/models.dart';

/// Status chip of a booking for the customer (C16).
(String, BadgeTone) bookingChip(Booking b) {
  if (b.tripCancelled) return ('أُلغيت الرحلة', BadgeTone.error);
  switch (b.status) {
    case 'CANCELLED':
      return ('ملغاة', BadgeTone.error);
    case 'CHANGED':
      return ('مُعدّلة', BadgeTone.info);
    case 'PENDING_PAYMENT':
      return ('بانتظار الدفع', BadgeTone.warning);
  }
  final active = b.activeTickets;
  if (active.isNotEmpty && active.every((t) => t.boardingStatus == 'BOARDED')) return ('صعدت', BadgeTone.success);
  if (active.any((t) => t.boardingStatus == 'NO_SHOW')) return ('لم تحضر', BadgeTone.error);
  if (b.isCash && b.cashToCollectMinor > 0) return ('ادفع للسائق', BadgeTone.warning);
  return ('مؤكدة', BadgeTone.brand);
}

(String, BadgeTone) ticketChip(Booking b, Ticket t) {
  if (!t.active) return ('ملغاة', BadgeTone.error);
  if (b.status == 'CHANGED') return ('مُعدّلة', BadgeTone.info);
  return switch (t.boardingStatus) {
    'BOARDED' => ('صعد', BadgeTone.success),
    'NO_SHOW' => ('لم يحضر', BadgeTone.error),
    _ => b.isConfirmed ? ('صالحة', BadgeTone.brand) : ('بانتظار الدفع', BadgeTone.warning),
  };
}

/// Why cash to the driver is not offered (`cashBlockedReason`).
String cashBlockedText(String? reason) => switch (reason) {
      'CASH_DISABLED' => 'الدفع نقدًا غير متاح حاليًا.',
      'CARRIER_CASH_DISABLED' => 'شركة النقل لا تقبل الدفع نقدًا لهذه الرحلة.',
      'NO_SHOW_LIMIT' => 'غير متاح بسبب تكرار عدم الحضور في رحلات سابقة.',
      'OPEN_CASH_LIMIT' => 'لديك حجوزات نقدية قادمة كثيرة. ادفعها أو ادفع هذه الرحلة إلكترونيًا.',
      'TOO_CLOSE_TO_DEPARTURE' => 'الرحلة قريبة جدًا من موعد المغادرة.',
      'TOO_MANY_SEATS' => 'عدد المقاعد أكبر من المسموح للدفع نقدًا.',
      _ => 'الدفع نقدًا غير متاح لهذا الحجز.',
    };

/// COUPON_INVALID details.reason.
String couponErrorText(Object? reason) => switch (reason) {
      'EXPIRED' => 'انتهت صلاحية كود الخصم.',
      'USED_UP' => 'تم استخدام كود الخصم بالكامل.',
      'ALREADY_USED' => 'استخدمت هذا الكود من قبل.',
      'BELOW_MINIMUM' => 'قيمة الحجز أقل من الحد الأدنى لهذا الكود.',
      'WRONG_CARRIER' => 'الكود غير صالح لشركة النقل هذه.',
      _ => 'كود الخصم غير صالح.',
    };

String serviceClass(String c) => c == 'VIP' ? 'VIP' : 'عادية';

String? legLabel(String? leg) => switch (leg) {
      'OUTBOUND' => 'ذهاب',
      'RETURN' => 'عودة',
      _ => null,
    };
