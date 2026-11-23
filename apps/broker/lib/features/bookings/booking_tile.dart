import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../data/models.dart';

/// Booking row: route, departure, seats, total, status.
class BookingTile extends StatelessWidget {
  const BookingTile({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (label, tone) = bookingStatus(booking.status);
    final leg = legLabel(booking.leg);
    final seats = booking.activeTickets.map((x) => x.seatLabel).join('، ');
    return ZoolCard(
      onTap: () => context.push('/booking/${booking.id}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${booking.origin} ← ${booking.destination}', style: t.titleSmall)),
              if (leg != null) ...[StatusBadge(leg, tone: BadgeTone.brand), const SizedBox(width: 6)],
              StatusBadge(label, tone: tone),
            ],
          ),
          const SizedBox(height: 6),
          Text('${formatLongDate(booking.departureAt)} · ${formatTime(booking.departureAt)}', style: t.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${booking.reference} · ${booking.companyName}${seats.isEmpty ? '' : ' · مقاعد $seats'}',
                  style: t.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(formatSdg(booking.totalMinor), style: t.titleSmall?.copyWith(color: ZoolColors.secondary)),
            ],
          ),
        ],
      ),
    );
  }
}
