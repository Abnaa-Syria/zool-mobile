import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../booking/trip_card.dart';
import 'share_ticket.dart';

/// «تذكرتي الرقمية» (Figma 3074:3503) with the boarding QR (not a barcode) and the C16 badges.
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
      title: 'تذكرتي الرقمية',
      action: b != null && ticket != null && b.isConfirmed && ticket.active
          ? RoundIconButton(icon: IconsaxPlusLinear.export_1, tooltip: 'مشاركة التذكرة', onTap: () => shareTicket(context, ref, b, ticket))
          : null,
      body: AsyncBody(
        value: booking,
        onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        data: (b) {
          if (ticket == null) return const EmptyView(title: 'التذكرة غير موجودة', icon: IconsaxPlusLinear.ticket);
          final trip = b.trip;
          final (label, tone) = ticketChip(b, ticket);
          final valid = b.isConfirmed && ticket.active && ticket.qrPayload != null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              TicketView(
                top: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(ticket.ticketNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ZoolColors.textStrong))),
                    StatusBadge(label, tone: tone),
                  ]),
                  const SizedBox(height: 16),
                  TripTimeline(trip: trip),
                  const SizedBox(height: 18),
                  _pair(TicketField('المسافر', ticket.passengerName), TicketField('المقعد', ticket.seatLabel)),
                  _pair(TicketField('رقم الرحلة', trip.tripNumber ?? '—'), TicketField('الدرجة', serviceClass(trip.serviceClass))),
                  _pair(TicketField('التاريخ', formatLongDate(trip.departureAt)), TicketField('الشركة', trip.carrierName)),
                  if (b.isCash && ticket.cashToCollectMinor > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: StatusBadge('ادفع ${formatSdg(ticket.cashToCollectMinor)} للسائق عند الصعود', tone: BadgeTone.warning),
                    ),
                ]),
                bottom: Column(children: [
                  Text(
                    valid ? 'اعرض هذا الرمز عند الصعود إلى الباص' : 'رمز الصعود غير متاح ($label)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (valid)
                    BoardingQr(payload: ticket.qrPayload!, size: 200, semanticLabel: 'رمز صعود التذكرة ${ticket.ticketNumber}')
                  else
                    const Icon(IconsaxPlusLinear.scan_barcode, size: 64, color: ZoolColors.divider),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pair(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]),
      );
}
