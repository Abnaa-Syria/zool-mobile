import 'package:flutter/material.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../data/models.dart';

/// Results card (3083:2001): carrier, class, times, stations, duration, stops, seats left, price,
/// commission %.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, this.onTap});

  final BrokerTrip trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final stops = trip.intermediateStops;
    final full = trip.seatsFree == 0;
    return ZoolCard(
      onTap: full ? null : onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus_rounded, color: ZoolColors.secondary, size: 20),
              const SizedBox(width: 6),
              Expanded(child: Text(trip.companyName, style: t.titleSmall)),
              StatusBadge(serviceClass(trip.serviceClass), tone: trip.serviceClass == 'VIP' ? BadgeTone.warning : BadgeTone.brand),
            ],
          ),
          const SizedBox(height: 14),
          RouteTimeline(
            departureAt: trip.departureAt,
            arrivalAt: trip.arrivalAt,
            originCity: trip.origin.city,
            destinationCity: trip.destination.city,
            originStation: trip.origin.station,
            destinationStation: trip.destination.station,
            durationMinutes: trip.durationMinutes,
            middleLabel: stops == 0 ? 'مباشر' : '$stops توقف',
          ),
          const Divider(height: 24),
          Row(
            children: [
              Icon(Icons.event_seat_rounded, size: 18, color: full ? ZoolColors.error : ZoolColors.textSecondary),
              const SizedBox(width: 4),
              Text(full ? 'مكتملة' : '${trip.seatsFree} مقعد متاح', style: t.bodySmall?.copyWith(color: full ? ZoolColors.error : null)),
              const SizedBox(width: 12),
              StatusBadge('عمولة ${_pct(trip.commissionPercent)}%', tone: BadgeTone.success),
              const Spacer(),
              Text(formatSdg(trip.basePrice), style: t.titleMedium?.copyWith(color: ZoolColors.secondary)),
            ],
          ),
        ],
      ),
    );
  }
}

String _pct(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
