import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import 'share_ticket.dart';

final _tripOfBookingProvider = FutureProvider.autoDispose.family<BrokerTrip?, String>((ref, tripId) async {
  try {
    return await ref.watch(apiProvider).trip(tripId);
  } catch (_) {
    return null; // past / cancelled trips may no longer be bookable; the ticket still shows
  }
});

/// E-ticket (Figma 3083:2743): reference, status, timeline, passenger / seat / trip / class /
/// date / carrier, and the boarding QR (the design's barcode is a QR, MISSING_SCREENS §1).
class TicketPage extends ConsumerWidget {
  const TicketPage({super.key, required this.bookingId, required this.ticketNumber});

  final String bookingId;
  final String ticketNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    final b = booking.value;
    final ticket = b?.tickets.where((t) => t.ticketNumber == ticketNumber).firstOrNull;
    return ZoolPage(
      title: 'التذكرة الإلكترونية',
      action: b != null && ticket != null && b.isConfirmed && ticket.active
          ? RoundIconButton(icon: IconsaxPlusLinear.export_1, tooltip: 'إرسال التذكرة', onTap: () => shareTicket(context, ref, b, ticket))
          : null,
      body: AsyncBody(
        value: booking,
        onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        data: (b) {
          if (ticket == null) return const EmptyView(title: 'التذكرة غير موجودة', icon: IconsaxPlusLinear.ticket);
          final trip = ref.watch(_tripOfBookingProvider(b.tripId)).value;
          final (label, tone) = !ticket.active
              ? ('ملغاة', BadgeTone.error)
              : (b.isConfirmed ? boardingStatus(ticket.boardingStatus) : bookingStatus(b.status));
          final valid = b.isConfirmed && ticket.active && ticket.qrPayload != null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              TicketView(
                top: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(ticket.ticketNumber, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ZoolColors.textStrong))),
                        StatusBadge(b.isConfirmed && ticket.active && ticket.boardingStatus == 'PENDING' ? 'مؤكد' : label, tone: b.isConfirmed && ticket.active ? BadgeTone.brand : tone),
                      ],
                    ),
                    const SizedBox(height: 16),
                    RouteTimeline(
                      departureAt: trip?.departureAt ?? b.departureAt,
                      arrivalAt: trip?.arrivalAt,
                      originCity: trip?.origin.city ?? b.origin,
                      destinationCity: trip?.destination.city ?? b.destination,
                      originStation: trip?.origin.station,
                      destinationStation: trip?.destination.station,
                      durationMinutes: trip?.durationMinutes,
                      middleLabel: trip == null ? null : (trip.intermediateStops == 0 ? 'مباشر' : '${trip.intermediateStops} توقف'),
                    ),
                    const SizedBox(height: 18),
                    _Pair(TicketField('المسافر', ticket.passengerName), TicketField('المقعد', ticket.seatLabel)),
                    _Pair(TicketField('رقم الحجز', b.reference), TicketField('الدرجة', trip == null ? '—' : (trip.serviceClass == 'VIP' ? 'VIP' : 'عادية'))),
                    _Pair(TicketField('التاريخ', formatDayMonth(b.departureAt)), TicketField('الشركة', b.companyName)),
                  ],
                ),
                bottom: Column(
                  children: [
                    Text(
                      valid ? 'اعرض هذا الرمز عند الصعود إلى الباص' : 'رمز الصعود غير متاح لهذه التذكرة ($label)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    if (valid)
                      BoardingQr(payload: ticket.qrPayload!, size: 200, semanticLabel: 'رمز صعود التذكرة ${ticket.ticketNumber}')
                    else
                      const Icon(IconsaxPlusLinear.scan_barcode, size: 64, color: ZoolColors.divider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair(this.start, this.end);

  final Widget start;
  final Widget end;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: start), const SizedBox(width: 12), Expanded(child: end)]),
      );
}
