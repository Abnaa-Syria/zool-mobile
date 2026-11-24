import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import 'trip_card.dart';

/// Trip detail (Figma 3074:2864): carrier + rating, class, timeline, stops, amenities, price, «اختيار المقعد».
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
              child: Row(children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MoneyText(formatSdg(t.priceMinor), size: 22),
                    const Text('للمسافر', style: TextStyle(fontSize: 12, color: ZoolColors.navInactive)),
                    Text('${seatsLabel(t.seatsAvailable)} متاحة', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ZoolColors.brand)),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PrimaryButton(
                    label: 'اختيار المقعد',
                    onPressed: t.seatsAvailable == 0 ? null : () => context.push('/seats/${isReturn ? 'return' : 'outbound'}/${t.id}'),
                  ),
                ),
              ]),
            ),
      body: AsyncBody(
        value: trip,
        onRetry: () => ref.invalidate(tripProvider(tripId)),
        data: (trip) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            CarrierHeader(
              name: trip.carrierName,
              logoUrl: trip.logoUrl,
              subtitle: trip.rating == null ? trip.legalName : null,
              trailing: StatusBadge(trip.serviceClass == 'VIP' ? 'VIP' : 'عادية', tone: BadgeTone.brand),
            ),
            if (trip.rating != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 50, top: 2),
                child: Row(children: [
                  const Icon(IconsaxPlusBold.star_1, size: 16, color: ZoolColors.warning),
                  const SizedBox(width: 4),
                  Text(trip.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  Text('  (${trip.ratingCount})', style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                ]),
              ),
            const SizedBox(height: 16),
            TripTimeline(trip: trip),
            const SizedBox(height: 8),
            Center(child: Text(formatLongDate(trip.departureAt), style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary))),
            if (!trip.cashAvailable) ...[
              const SizedBox(height: 10),
              const Center(child: StatusBadge('الدفع إلكتروني فقط لهذه الرحلة', tone: BadgeTone.info)),
            ],
            if (trip.stops.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionTitle('محطات الرحلة'),
              ZoolCard(child: StopsTimeline(stops: trip.stops)),
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
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(amenityIcon(a.str('code')), size: 20, color: ZoolColors.textStrong),
                        const SizedBox(height: 6),
                        Text(
                          a.strOrNull('value') == null ? a.str('nameAr') : '${a.str('nameAr')} ${a.str('value')}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: ZoolColors.textStrong),
                        ),
                      ]),
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

/// Vertical stops list (first stop red, then grey dots joined by a line).
class StopsTimeline extends StatelessWidget {
  const StopsTimeline({super.key, required this.stops});

  final List<TripStop> stops;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < stops.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 14,
              child: Column(children: [
                const SizedBox(height: 6),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: i == 0 ? ZoolColors.primary : ZoolColors.border, shape: BoxShape.circle)),
                if (i < stops.length - 1) Expanded(child: Container(width: 1, color: ZoolColors.border)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: i < stops.length - 1 ? 14 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(stops[i].city, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
                  Text(
                    [if (stops[i].station != null) stops[i].station!, if (stops[i].scheduledAt != null) formatTime(stops[i].scheduledAt)].join(' · '),
                    style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary),
                  ),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}
