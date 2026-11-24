import 'package:flutter/material.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../data/models.dart';

/// Current-trip card (Home «الرحلة الحالية» and the trips list, Figma 3043:2004 / 3652):
/// route title + status dot, the timeline with duration and stops, vehicle and seats.
/// [highlight] draws the green border used for the live trip.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, this.onTap, this.highlight = false});

  final DriverTrip trip;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final (label, color) = tripStatusLabel(trip);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(ZoolRadii.bigCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: highlight
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(ZoolRadii.bigCard),
                  border: Border.all(color: ZoolColors.brand, width: 1),
                )
              : null,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text(
                  trip.routeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ZoolColors.brand),
                ),
              ),
              DotStatus(label, color),
            ]),
            const SizedBox(height: 14),
            RouteTimeline(
              departureAt: trip.departureAt,
              arrivalAt: trip.arrivalAt,
              originCity: trip.originCity,
              destinationCity: trip.destinationCity,
              durationMinutes: trip.durationMinutes,
              middleLabel: trip.stopsSummary,
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: ZoolColors.divider)),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _Labeled(label: 'المركبة المعينة', value: trip.vehicleModel ?? '—')),
              _Labeled(label: 'المقاعد المحجوزة', value: trip.seatsTotal > 0 ? '${trip.booked} / ${trip.seatsTotal} مقعد' : seatsLabel(trip.booked), end: true),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.value, this.end = false});

  final String label;
  final String value;
  final bool end;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
    ]);
  }
}

/// Compact today-trip card (Home «رحلات اليوم»): route + status, departure, registered passengers.
class TodayTripCard extends StatelessWidget {
  const TodayTripCard({super.key, required this.trip, this.onTap});

  final DriverTrip trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = tripStatusLabel(trip);
    return ZoolCard(
      radius: ZoolRadii.bigCard,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(trip.routeLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ZoolColors.textStrong))),
          DotStatus(label, color),
        ]),
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: ZoolColors.divider)),
        InfoRow('توقيت المغادرة', relativeDeparture(trip.departureAt)),
        InfoRow('الركاب المسجلين', trip.seatsTotal > 0 ? '${trip.booked} من أصل ${trip.seatsTotal} مقعد' : passengersLabel(trip.booked)),
      ]),
    );
  }
}
