import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// Trip details (Figma 3083:2246): carrier + rating, timeline, stops, amenities, price, «اختيار المقعد».
class TripDetailPage extends ConsumerWidget {
  const TripDetailPage({super.key, required this.tripId, required this.isReturn});

  final String tripId;
  final bool isReturn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider(tripId));
    final t = trip.value;
    return ZoolPage(
      title: isReturn ? 'تفاصيل رحلة العودة' : 'تفاصيل الرحلة',
      bottomBar: t == null
          ? null
          : ZoolBottomBar(
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MoneyText(formatSdg(t.basePrice), size: 22),
                      const Text('للمسافر', style: TextStyle(fontSize: 12, color: ZoolColors.navInactive)),
                      Text('${seatsLabel(t.seatsFree)} متاحة', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ZoolColors.brand)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrimaryButton(
                      label: 'اختيار المقعد',
                      onPressed: t.seatsFree == 0 ? null : () => context.push('/book/seats/${isReturn ? 'return' : 'outbound'}/${t.id}'),
                    ),
                  ),
                ],
              ),
            ),
      body: AsyncBody(
        value: trip,
        onRetry: () => ref.invalidate(tripProvider(tripId)),
        data: (trip) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            CarrierHeader(
              name: trip.companyName,
              logoUrl: trip.logoUrl,
              subtitle: trip.rating == null ? trip.legalName : null,
              trailing: StatusBadge(trip.serviceClass == 'VIP' ? 'VIP' : 'عادية', tone: BadgeTone.brand),
            ),
            if (trip.rating != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 50, top: 2),
                child: Row(
                  children: [
                    const Icon(IconsaxPlusBold.star_1, size: 16, color: ZoolColors.warning),
                    const SizedBox(width: 4),
                    Text(trip.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    if (trip.ratingCount != null) Text('  (${trip.ratingCount})', style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            RouteTimeline(
              departureAt: trip.departureAt,
              arrivalAt: trip.arrivalAt,
              originCity: trip.origin.city,
              destinationCity: trip.destination.city,
              originStation: trip.origin.station,
              destinationStation: trip.destination.station,
              durationMinutes: trip.durationMinutes,
              middleLabel: trip.intermediateStops == 0 ? 'مباشر' : '${trip.intermediateStops} توقف',
            ),
            const SizedBox(height: 8),
            Center(child: Text(formatLongDate(trip.departureAt), style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary))),
            if (trip.stops.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionTitle('محطات الرحلة'),
              ZoolCard(child: _Stops(stops: trip.stops)),
            ],
            if (trip.amenities.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionTitle('المرافق والخدمات'),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  for (final a in trip.amenities)
                    ZoolCard(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(amenityIcon(a.str('code')), size: 20, color: ZoolColors.textStrong),
                          const SizedBox(height: 6),
                          Text(
                            a.strOrNull('value') == null ? a.str('nameAr') : '${a.str('nameAr')} ${a.str('value')}',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: ZoolColors.textStrong),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (trip.vehicleModel != null) ...[
              const SizedBox(height: 12),
              Text('الحافلة: ${trip.vehicleModel}', style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stops extends StatelessWidget {
  const _Stops({required this.stops});

  final List<TripStop> stops;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < stops.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 14,
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: i == 0 ? ZoolColors.primary : ZoolColors.border, shape: BoxShape.circle),
                      ),
                      if (i < stops.length - 1) Expanded(child: Container(width: 1, color: ZoolColors.border)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < stops.length - 1 ? 14 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stops[i].city, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
                        Text(
                          [if (stops[i].station != null) stops[i].station!, if (stops[i].scheduledAt != null) formatTime(stops[i].scheduledAt)].join(' · '),
                          style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
