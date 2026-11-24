import 'package:flutter/material.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../data/models.dart';

/// Results card (Figma 3083:2001): carrier, date, timeline, amenities, seats left, price,
/// the broker's commission, «عرض الرحلة».
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, this.onTap});

  final BrokerTrip trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stops = trip.intermediateStops;
    final full = trip.seatsFree == 0;
    return ZoolCard(
      onTap: full ? null : onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CarrierHeader(
            name: trip.companyName,
            subtitle: trip.legalName,
            logoUrl: trip.logoUrl,
            trailing: Text(shortDay(trip.departureAt), style: const TextStyle(fontSize: 12, color: ZoolColors.textStrong)),
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final a in trip.amenities.take(6))
                      Tooltip(message: a.str('nameAr'), child: Icon(amenityIcon(a.str('code')), size: 16, color: ZoolColors.textStrong)),
                    if (trip.serviceClass == 'VIP') const StatusBadge('VIP', tone: BadgeTone.brand),
                  ],
                ),
              ),
              Text(
                full ? 'مكتملة' : '${seatsLabel(trip.seatsFree)} متبقية',
                style: TextStyle(fontSize: 12, color: full ? ZoolColors.error : ZoolColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MoneyText(formatSdg(trip.basePrice), size: 22),
                    Text('عمولتك ${_pct(trip.commissionPercent)}% · ${formatSdg(trip.expectedCommissionPerSeat)} للمقعد',
                        style: const TextStyle(fontSize: 11, color: ZoolColors.brand, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                height: 40,
                child: FilledButton(
                  onPressed: full ? null : onTap,
                  style: FilledButton.styleFrom(minimumSize: const Size(120, 40), textStyle: zoolText(14, weight: FontWeight.w700)),
                  child: const Text('عرض الرحلة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "الخميس، 15 مايو"
String shortDay(DateTime? instant) {
  if (instant == null) return '';
  final d = toSudan(instant);
  return '${kArabicWeekdays[d.weekday - 1]}، ${d.day} ${kArabicMonths[d.month - 1]}';
}

String _pct(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
