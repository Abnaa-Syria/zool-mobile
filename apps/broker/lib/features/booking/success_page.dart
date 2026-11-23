import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_ui/zool_ui.dart';

/// Booking confirmed: open the tickets or start another booking.
class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key, required this.bookingId, this.returnBookingId});

  final String bookingId;
  final String? returnBookingId;

  @override
  Widget build(BuildContext context) {
    return ZoolPage(
      bottomBar: ZoolBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(label: 'عرض التذاكر', onPressed: () => _open(context, bookingId)),
            if (returnBookingId != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => _open(context, returnBookingId!), child: const Text('تذاكر رحلة العودة')),
            ],
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () => context.go('/book'), child: const Text('حجز جديد')),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(IconsaxPlusBold.tick_circle, color: ZoolColors.brand, size: 60),
              ),
              const SizedBox(height: 20),
              const Text('تم تأكيد الحجز', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ZoolColors.textStrong)),
              const SizedBox(height: 8),
              Text(
                returnBookingId == null
                    ? 'خُصم المبلغ من محفظة المكتب وأُضيفت العمولة لحسابك. أرسل التذاكر للمسافرين من صفحة الحجز.'
                    : 'تم حجز رحلتي الذهاب والعودة. أرسل تذاكر كل رحلة للمسافرين من صفحة الحجز.',
                style: const TextStyle(fontSize: 14, color: ZoolColors.textSecondary, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bookings tab underneath, so back from the booking lands on the list.
void _open(BuildContext context, String id) {
  final router = GoRouter.of(context);
  router.go('/bookings');
  router.push('/booking/$id');
}
