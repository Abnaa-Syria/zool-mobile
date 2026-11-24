import 'package:flutter/material.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../data/models.dart';

/// "الخميس، 15 مايو"
String shortDay(DateTime? instant) {
  if (instant == null) return '';
  final d = toSudan(instant);
  return '${kArabicWeekdays[d.weekday - 1]}، ${d.day} ${kArabicMonths[d.month - 1]}';
}

/// Results card (Figma 3074:2473): carrier, date, timeline, amenities, seats left, price, «عرض الرحلة».
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, this.onTap});

  final Trip trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final full = trip.seatsAvailable == 0;
    return ZoolCard(
      onTap: full ? null : onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CarrierHeader(
            name: trip.carrierName,
            subtitle: trip.legalName,
            logoUrl: trip.logoUrl,
            trailing: Text(shortDay(trip.departureAt), style: const TextStyle(fontSize: 12, color: ZoolColors.textStrong)),
          ),
          const SizedBox(height: 14),
          TripTimeline(trip: trip),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final a in trip.amenities.take(6))
                      Tooltip(message: a.str('nameAr', a.str('code')), child: Icon(amenityIcon(a.str('code')), size: 16, color: ZoolColors.textStrong)),
                    if (trip.serviceClass == 'VIP') const StatusBadge('VIP', tone: BadgeTone.brand),
                  ],
                ),
              ),
              Text(
                full ? 'مكتملة' : '${seatsLabel(trip.seatsAvailable)} متبقية',
                style: TextStyle(fontSize: 12, color: full ? ZoolColors.error : ZoolColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: MoneyText(formatSdg(trip.priceMinor), size: 22)),
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

/// The design timeline for a customer trip.
class TripTimeline extends StatelessWidget {
  const TripTimeline({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) => RouteTimeline(
        departureAt: trip.departureAt,
        arrivalAt: trip.arrivalAt,
        originCity: trip.origin.city,
        destinationCity: trip.destination.city,
        originStation: trip.origin.station,
        destinationStation: trip.destination.station,
        durationMinutes: trip.durationMinutes,
        middleLabel: trip.middleLabel,
      );
}

/// Compact white trip card (carrier, date, timeline) above the seat map and in the review.
class TripSummaryCard extends StatelessWidget {
  const TripSummaryCard({super.key, required this.trip, this.title});

  final Trip trip;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return ZoolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ZoolColors.brand)),
            const SizedBox(height: 8),
          ],
          CarrierHeader(
            name: trip.carrierName,
            subtitle: trip.legalName,
            logoUrl: trip.logoUrl,
            trailing: Text(shortDay(trip.departureAt), style: const TextStyle(fontSize: 12, color: ZoolColors.textStrong)),
          ),
          const SizedBox(height: 12),
          TripTimeline(trip: trip),
        ],
      ),
    );
  }
}
