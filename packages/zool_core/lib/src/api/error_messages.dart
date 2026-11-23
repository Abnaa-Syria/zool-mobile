import 'api_exception.dart';

/// Arabic text per backend error code. Screens show [errorMessage]; they never show the English
/// `message` from the API, and they branch on `code`.
const Map<String, String> kErrorMessages = {
  ApiException.networkError: 'تعذّر الاتصال بالخادم. تحقّق من الإنترنت وحاول مرة أخرى.',
  'VALIDATION_ERROR': 'البيانات المدخلة غير صحيحة.',
  'AUTHENTICATION_REQUIRED': 'انتهت الجلسة. سجّل الدخول مرة أخرى.',
  'UNAUTHORIZED': 'انتهت الجلسة. سجّل الدخول مرة أخرى.',
  'AUTH_TOKEN_EXPIRED': 'انتهت الجلسة. سجّل الدخول مرة أخرى.',
  'AUTH_TOKEN_INVALID': 'انتهت الجلسة. سجّل الدخول مرة أخرى.',
  'SESSION_EXPIRED': 'انتهت الجلسة. سجّل الدخول مرة أخرى.',
  'SESSION_REVOKED': 'تم إنهاء الجلسة. سجّل الدخول مرة أخرى.',
  'TOKEN_REUSE_DETECTED': 'تم إنهاء الجلسة لأسباب أمنية. سجّل الدخول مرة أخرى.',
  'AUTH_AUTHZ_STALE': 'تغيّرت صلاحياتك. سجّل الدخول مرة أخرى.',
  'PERMISSION_DENIED': 'ليست لديك صلاحية لتنفيذ هذا الإجراء.',
  'FORBIDDEN': 'ليست لديك صلاحية لتنفيذ هذا الإجراء.',
  'NOT_FOUND': 'العنصر المطلوب غير موجود.',
  'CONFLICT': 'تعارض مع بيانات موجودة.',
  'RATE_LIMITED': 'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.',
  'OTP_INVALID': 'رمز التحقق غير صحيح.',
  'OTP_EXPIRED': 'انتهت صلاحية رمز التحقق. اطلب رمزًا جديدًا.',
  'OTP_LOCKED': 'تم إيقاف الرمز بسبب كثرة المحاولات. اطلب رمزًا جديدًا.',
  'OTP_COOLDOWN': 'انتظر قليلًا قبل طلب رمز جديد.',
  'OTP_ATTEMPT_LIMIT': 'تجاوزت عدد المحاولات المسموح. حاول لاحقًا.',
  'INVALID_CREDENTIALS': 'هذا الرقم غير مسجّل في هذا التطبيق.',
  'INSUFFICIENT_BALANCE': 'رصيد المحفظة غير كافٍ.',
  'TOP_UP_BELOW_MINIMUM': 'مبلغ الشحن أقل من الحد الأدنى المسموح.',
  'SEAT_UNAVAILABLE': 'مقعد أو أكثر لم يعد متاحًا. اختر مقعدًا آخر.',
  'HOLD_REQUIRED': 'يجب حجز المقاعد مؤقتًا قبل التأكيد.',
  'HOLD_EXPIRED': 'انتهت مهلة الحجز المؤقت للمقاعد. أعد اختيار المقاعد.',
  'HOLD_LIMIT_REACHED': 'وصلت للحد الأقصى من المقاعد المحجوزة مؤقتًا.',
  'EXPOSURE_CEILING_EXCEEDED': 'تم تجاوز الحد اليومي المسموح للمكتب.',
  'CARRIER_NOT_ASSIGNED': 'شركة النقل غير مُسندة لهذا المكتب.',
  'BOOKING_NOT_CANCELLABLE': 'لا يمكن إلغاء هذا الحجز في حالته الحالية.',
  'WOMEN_ONLY_SEAT': 'مقعد مخصّص للسيدات: يُحجز لمسافرة فقط (الجنس «أنثى»).',
  'CASH_NOT_ALLOWED': 'الدفع نقدًا غير متاح لهذا الحجز.',
  'ROUND_TRIP_INVALID': 'رحلة العودة يجب أن تكون بين نفس المدينتين بالاتجاه المعاكس وبعد وصول رحلة الذهاب.',
  'COUPON_INVALID': 'كود الخصم غير صالح.',
  'PAYMENT_NOT_PENDING': 'عملية الدفع لم تعد بانتظار الدفع.',
  'CHANGE_NOT_ALLOWED': 'لا يمكن تعديل هذا الحجز.',
  'RATING_NOT_ALLOWED': 'لا يمكن تقييم هذه الرحلة.',
  'TRIP_STATE_INVALID': 'لا يمكن تنفيذ هذا الإجراء في حالة الرحلة الحالية.',
  'CASH_AMOUNT_MISMATCH': 'المبلغ المحصّل لا يساوي المبلغ المطلوب.',
  'NOT_ASSIGNED_DRIVER': 'هذه الرحلة غير مسندة إليك.',
  'ACCOUNT_HAS_ACTIVE_BOOKINGS': 'لديك رحلات قادمة. ألغِها أولًا ثم احذف الحساب.',
  'PLATFORM_MAINTENANCE': 'التطبيق في صيانة الآن. حاول بعد قليل.',
  'MOCK_PAYMENT_DISABLED': 'الدفع التجريبي غير متاح.',
  'INFRASTRUCTURE_UNAVAILABLE': 'الخدمة غير متاحة مؤقتًا. حاول بعد قليل.',
  'INTERNAL_SERVER_ERROR': 'حدث خطأ في الخادم. حاول مرة أخرى.',
  'INTERNAL_ERROR': 'حدث خطأ في الخادم. حاول مرة أخرى.',
};

/// Arabic message for any error thrown by the API layer.
String errorMessage(Object? error, {String fallback = 'حدث خطأ غير متوقع.'}) {
  if (error is! ApiException) return fallback;
  if (error.code == 'CHANGE_NOT_ALLOWED') return changeNotAllowedMessage(error.details);
  if (error.code == 'OTP_COOLDOWN' || error.code == 'RATE_LIMITED') {
    final wait = error.detailsMap['retryAfterSeconds'];
    if (wait is num && wait > 0) return 'انتظر ${wait.ceil()} ثانية ثم حاول مرة أخرى.';
  }
  return kErrorMessages[error.code] ?? (error.statusCode != null && error.statusCode! >= 500 ? kErrorMessages['INTERNAL_ERROR']! : fallback);
}

/// CHANGE_NOT_ALLOWED details: `{ cutoffMinutes } | { max } | { status }`.
String changeNotAllowedMessage(Object? details) {
  final d = details is Map ? details : const {};
  const base = 'لا يمكن تعديل هذا الحجز.';
  if (d['cutoffMinutes'] is num) return '$base يُغلق التعديل قبل ${d['cutoffMinutes']} دقيقة من موعد المغادرة.';
  if (d['max'] is num) return '$base بلغ الحجز الحد الأقصى لعدد التعديلات (${d['max']}).';
  if (d['status'] is String) return '$base يمكن تعديل الحجوزات المؤكدة فقط.';
  return base;
}
