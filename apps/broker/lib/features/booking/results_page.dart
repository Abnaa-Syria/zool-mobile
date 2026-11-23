import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import 'flow.dart';
import 'trip_card.dart';

typedef _Search = ({String from, String to, String date});

final _resultsProvider = FutureProvider.autoDispose.family<List<BrokerTrip>, _Search>(
  (ref, s) => ref.watch(apiProvider).searchTrips(fromCityId: s.from, toCityId: s.to, date: s.date),
);

/// Results (3083:2001) for the outbound leg, or the return leg (B6 / C4: swapped cities on the
/// return date, only trips leaving after the outbound arrives).
class ResultsPage extends ConsumerWidget {
  const ResultsPage({super.key, required this.isReturn});

  final bool isReturn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(bookingFlowProvider);
    final t = Theme.of(context).textTheme;
    if (flow.fromCity == null || flow.toCity == null || flow.date == null || (isReturn && flow.outbound == null)) {
      return Scaffold(appBar: AppBar(), body: const EmptyView(title: 'ابدأ البحث من جديد', icon: Icons.search_off_rounded));
    }
    final from = isReturn ? flow.toCity! : flow.fromCity!;
    final to = isReturn ? flow.fromCity! : flow.toCity!;
    final date = isReturn ? (flow.returnDate ?? flow.date!) : flow.date!;
    final search = (from: from.id, to: to.id, date: dayKey(date));
    final results = ref.watch(_resultsProvider(search));
    final out = flow.outbound;
    final notBefore = isReturn ? (out!.trip.arrivalAt ?? out.trip.departureAt) : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(isReturn ? 'رحلة العودة' : '${from.name} ← ${to.name}'),
            Text('${formatCalendarDate(date)} · ${flow.passengerCount} راكب', style: t.bodySmall),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_resultsProvider(search).future),
        child: AsyncBody(
          value: results,
          onRetry: () => ref.invalidate(_resultsProvider(search)),
          data: (trips) {
            final fits = trips.where((tr) => tr.seatsFree >= flow.passengerCount || tr.seatsFree == 0).toList();
            final valid = notBefore == null ? fits : fits.where((tr) => tr.departureAt != null && !tr.departureAt!.isBefore(notBefore)).toList();
            final hidden = fits.length - valid.length;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isReturn) ...[
                  _OutboundSummary(leg: out!),
                  const SizedBox(height: 12),
                ],
                if (valid.isEmpty)
                  EmptyView(
                    title: 'لا توجد رحلات متاحة',
                    message: hidden > 0
                        ? 'توجد $hidden رحلة تغادر قبل وصول رحلة الذهاب. جرّب تاريخ عودة لاحقًا.'
                        : 'جرّب تاريخًا آخر أو مدينة أخرى. تظهر فقط رحلات الشركات المُسندة لمكتبك.',
                    icon: Icons.directions_bus_outlined,
                    action: OutlinedButton(
                      onPressed: () => context.pop(),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(180, 44)),
                      child: const Text('تعديل البحث'),
                    ),
                  )
                else
                  for (final trip in valid) ...[
                    TripCard(
                      trip: trip,
                      onTap: () => context.push('/book/seats/${isReturn ? 'return' : 'outbound'}/${trip.id}'),
                    ),
                    const SizedBox(height: 12),
                  ],
                if (valid.isNotEmpty && hidden > 0)
                  Text('أُخفيت $hidden رحلة تغادر قبل وصول رحلة الذهاب.', style: t.bodySmall, textAlign: TextAlign.center),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OutboundSummary extends StatelessWidget {
  const _OutboundSummary({required this.leg});

  final LegSelection leg;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ZoolCard(
      color: ZoolColors.secondarySoft,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: ZoolColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الذهاب: ${leg.trip.origin.city} ← ${leg.trip.destination.city} · ${formatDateTime(leg.trip.departureAt)} · مقاعد ${leg.seatLabels}',
              style: t.bodySmall?.copyWith(color: ZoolColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}
