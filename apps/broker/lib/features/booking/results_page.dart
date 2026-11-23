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

enum _Sort { best, earliest, cheapest, shortest }

const _sortLabels = {_Sort.best: 'الأنسب', _Sort.earliest: 'الأقرب مغادرة', _Sort.cheapest: 'الأقل سعرًا', _Sort.shortest: 'الأقصر مدة'};

/// Results (Figma 3083:2001) for the outbound leg, or the return leg (B6: swapped cities on the
/// return date, only trips leaving after the outbound arrives). Sort and filter are client-side.
class ResultsPage extends ConsumerStatefulWidget {
  const ResultsPage({super.key, required this.isReturn});

  final bool isReturn;

  @override
  ConsumerState<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends ConsumerState<ResultsPage> {
  _Sort _sort = _Sort.best;
  Set<String> _carriers = {};
  String? _class;

  List<BrokerTrip> _apply(List<BrokerTrip> trips) {
    final list = trips.where((t) => (_carriers.isEmpty || _carriers.contains(t.companyName)) && (_class == null || t.serviceClass == _class)).toList();
    int dep(BrokerTrip t) => t.departureAt?.millisecondsSinceEpoch ?? 0;
    switch (_sort) {
      case _Sort.best:
        list.sort((a, b) {
          final full = (a.seatsFree == 0 ? 1 : 0) - (b.seatsFree == 0 ? 1 : 0);
          return full != 0 ? full : dep(a).compareTo(dep(b));
        });
      case _Sort.earliest:
        list.sort((a, b) => dep(a).compareTo(dep(b)));
      case _Sort.cheapest:
        list.sort((a, b) => a.basePrice.compareTo(b.basePrice));
      case _Sort.shortest:
        list.sort((a, b) => (a.durationMinutes ?? 1 << 20).compareTo(b.durationMinutes ?? 1 << 20));
    }
    return list;
  }

  Future<void> _pickSort() async {
    final picked = await showModalBottomSheet<_Sort>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ترتيب النتائج', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            for (final s in _Sort.values)
              ListTile(
                title: Text(_sortLabels[s]!),
                trailing: s == _sort ? const Icon(IconsaxPlusBold.tick_circle, color: ZoolColors.brand) : null,
                onTap: () => Navigator.of(ctx).pop(s),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _sort = picked);
  }

  Future<void> _pickFilter(List<BrokerTrip> trips) async {
    final carriers = trips.map((t) => t.companyName).toSet().toList()..sort();
    var chosen = {..._carriers};
    var cls = _class;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('فلترة', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text('شركة النقل', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in carriers)
                      FilterChip(
                        label: Text(c),
                        selected: chosen.contains(c),
                        onSelected: (on) => setSheet(() => on ? chosen.add(c) : chosen.remove(c)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('الدرجة', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (v, l) in const [(null, 'الكل'), ('STANDARD', 'عادية'), ('VIP', 'VIP')])
                      ChoiceChip(label: Text(l), selected: cls == v, onSelected: (_) => setSheet(() => cls = v)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheet(() {
                          chosen = {};
                          cls = null;
                        }),
                        child: const Text('مسح'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('تطبيق'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (apply == true) {
      setState(() {
        _carriers = chosen;
        _class = cls;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(bookingFlowProvider);
    if (flow.fromCity == null || flow.toCity == null || flow.date == null || (widget.isReturn && flow.outbound == null)) {
      return const ZoolPage(title: 'النتائج', body: EmptyView(title: 'ابدأ البحث من جديد', icon: IconsaxPlusLinear.search_normal_1));
    }
    final isReturn = widget.isReturn;
    final from = isReturn ? flow.toCity! : flow.fromCity!;
    final to = isReturn ? flow.fromCity! : flow.toCity!;
    final date = isReturn ? (flow.returnDate ?? flow.date!) : flow.date!;
    final search = (from: from.id, to: to.id, date: dayKey(date));
    final results = ref.watch(_resultsProvider(search));
    final out = flow.outbound;
    final notBefore = isReturn ? (out!.trip.arrivalAt ?? out.trip.departureAt) : null;
    final travellers = flow.passengerCount == 1 ? '1 مسافر' : '${flow.passengerCount} مسافرين';

    return ZoolPage(
      title: isReturn ? 'رحلة العودة: ${from.name} ← ${to.name}' : '${from.name} ← ${to.name}',
      subtitle: '${formatCalendarDate(date)} · $travellers',
      action: TextButton(onPressed: () => context.pop(), child: const Text('تعديل')),
      body: AsyncBody(
        value: results,
        onRetry: () => ref.invalidate(_resultsProvider(search)),
        data: (trips) {
          final fits = trips.where((tr) => tr.seatsFree >= flow.passengerCount || tr.seatsFree == 0).toList();
          final valid = notBefore == null ? fits : fits.where((tr) => tr.departureAt != null && !tr.departureAt!.isBefore(notBefore)).toList();
          final hidden = fits.length - valid.length;
          final shown = _apply(valid);
          final filtered = _carriers.isNotEmpty || _class != null;
          return RefreshIndicator(
            color: ZoolColors.brand,
            onRefresh: () => ref.refresh(_resultsProvider(search).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (isReturn) ...[_OutboundSummary(leg: out!), const SizedBox(height: 12)],
                Row(
                  children: [
                    Expanded(child: Text('${shown.length} رحلة', style: const TextStyle(fontSize: 13, color: ZoolColors.textSecondary))),
                    _ToolChip(icon: IconsaxPlusLinear.sort, label: _sortLabels[_sort]!, onTap: _pickSort),
                    const SizedBox(width: 8),
                    _ToolChip(icon: IconsaxPlusLinear.setting_4, label: filtered ? 'فلترة •' : 'فلترة', onTap: () => _pickFilter(valid)),
                  ],
                ),
                const SizedBox(height: 12),
                if (shown.isEmpty)
                  EmptyView(
                    title: 'لا توجد رحلات متاحة',
                    message: hidden > 0
                        ? 'توجد $hidden رحلة تغادر قبل وصول رحلة الذهاب. جرّب تاريخ عودة لاحقًا.'
                        : (filtered ? 'لا رحلات تطابق الفلترة.' : 'جرّب تاريخًا آخر. تظهر فقط رحلات الشركات المُسندة لمكتبك.'),
                    icon: IconsaxPlusLinear.bus,
                  )
                else
                  for (final trip in shown) ...[
                    TripCard(trip: trip, onTap: () => context.push('/book/trip/${isReturn ? 'return' : 'outbound'}/${trip.id}')),
                    const SizedBox(height: 12),
                  ],
                if (shown.isNotEmpty && hidden > 0)
                  Text('أُخفيت $hidden رحلة تغادر قبل وصول رحلة الذهاب.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: ZoolColors.textStrong),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ZoolColors.textStrong)),
            ],
          ),
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
    return ZoolCard(
      color: ZoolColors.secondarySoft,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(IconsaxPlusBold.tick_circle, color: ZoolColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الذهاب: ${leg.trip.origin.city} ← ${leg.trip.destination.city} · ${formatDateTime(leg.trip.departureAt)} · مقاعد ${leg.seatLabels}',
              style: const TextStyle(fontSize: 12, color: ZoolColors.brand),
            ),
          ),
        ],
      ),
    );
  }
}
