import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_ui/zool_ui.dart';

/// Booking confirmed: open the booking (tickets with QR) or start another booking.
class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key, required this.bookingId, this.returnBookingId});

  final String bookingId;
  final String? returnBookingId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: ZoolColors.secondarySoft, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: ZoolColors.secondary, size: 56),
              ),
              const SizedBox(height: 20),
              Text('تم تأكيد الحجز', style: t.titleLarge),
              const SizedBox(height: 8),
              Text(
                returnBookingId == null
                    ? 'خُصم المبلغ من محفظة المكتب وأُضيفت العمولة لحسابك. التذاكر جاهزة.'
                    : 'تم حجز رحلتي الذهاب والعودة. التذاكر جاهزة لكل رحلة.',
                style: t.bodyMedium?.copyWith(color: ZoolColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              PrimaryButton(label: 'عرض التذاكر', onPressed: () => _open(context, bookingId)),
              if (returnBookingId != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(onPressed: () => _open(context, returnBookingId!), child: const Text('تذاكر رحلة العودة')),
              ],
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () {
                  context.go('/');
                  GoRouter.of(context).push('/book');
                }, child: const Text('حجز جديد')),
              TextButton(onPressed: () => context.go('/'), child: const Text('الرئيسية')),
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
