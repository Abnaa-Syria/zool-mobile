import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import 'flow.dart';
import 'trip_card.dart';

/// Server-side sort (C3) and filters (C2).
class _Query {
  const _Query({this.sort = 'recommended', this.carrierIds = const {}, this.serviceClass, this.amenities = const {}, this.window});

  final String sort;
  final Set<String> carrierIds;
  final String? serviceClass;
  final Set<String> amenities;

  /// departureWindows[].key with its from/to.
  final Json? window;

  bool get filtered => carrierIds.isNotEmpty || serviceClass != null || amenities.isNotEmpty || window != null;

  Map<String, Object?> params() => {
        'sort': sort,
        'carrierId': carrierIds.isEmpty ? null : carrierIds.join(','),
        'serviceClass': serviceClass,
        'amenity': amenities.isEmpty ? null : amenities.join(','),
        'departureFrom': window?.strOrNull('from'),
        'departureTo': window?.strOrNull('to'),
      };
}

const _sortLabels = {'recommended': 'الأنسب', 'departureAt': 'الأقرب مغادرة', 'priceMinor': 'الأقل سعرًا', 'durationMinutes': 'الأقصر مدة'};

/// Results (Figma 3074:2473 + loading 2718, empty 2814, error 2839) for the outbound leg or the
/// return leg (C4: swapped cities on the return date, only trips leaving after the outbound arrives).
class ResultsPage extends ConsumerStatefulWidget {
  const ResultsPage({super.key, required this.isReturn});

  final bool isReturn;

  @override
  ConsumerState<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends ConsumerState<ResultsPage> {
  _Query _query = const _Query();
  Future<List<Trip>>? _future;
  Map<String, Object?>? _base;

  Map<String, Object?> _baseQuery(BookingFlowState flow) {
    final s = flow.search!;
    final from = widget.isReturn ? s.to : s.from;
    final to = widget.isReturn ? s.from : s.to;
    final date = widget.isReturn ? (s.returnDate ?? s.date) : s.date;
    return {'fromCityId': from.id, 'toCityId': to.id, 'date': dayKey(date), 'passengers': s.passengers};
  }

  void _load() {
    final future = ref.read(apiProvider).searchTrips({..._base!, ..._query.params()});
    setState(() {
      _future = future;
    });
  }

  Future<void> _pickSort() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ترتيب النتائج', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            for (final e in _sortLabels.entries)
              ListTile(
                title: Text(e.value),
                trailing: e.key == _query.sort ? const Icon(IconsaxPlusBold.tick_circle, color: ZoolColors.brand) : null,
                onTap: () => Navigator.of(ctx).pop(e.key),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      _query = _Query(sort: picked, carrierIds: _query.carrierIds, serviceClass: _query.serviceClass, amenities: _query.amenities, window: _query.window);
      _load();
    }
  }

  Future<void> _pickFilter() async {
    Json data;
    try {
      data = await ref.read(apiProvider).filters(_base!);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
      return;
    }
    if (!mounted) return;
    var carriers = {..._query.carrierIds};
    var amenities = {..._query.amenities};
    var cls = _query.serviceClass;
    var window = _query.window;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Widget title(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)));
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('فلترة النتائج', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    title('شركة النقل'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final c in data.list('carriers'))
                        FilterChip(
                          label: Text('${c.str('name')} (${c.integer('tripsCount')})'),
                          selected: carriers.contains(c.str('id')),
                          onSelected: (on) => set(() => on ? carriers.add(c.str('id')) : carriers.remove(c.str('id'))),
                        ),
                    ]),
                    title('وقت المغادرة'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final w in data.list('departureWindows').where((w) => w.integer('tripsCount') > 0))
                        ChoiceChip(
                          label: Text('${_windowLabel(w.str('key'))} ${w.str('from')}–${w.str('to')}'),
                          selected: window?.str('key') == w.str('key'),
                          onSelected: (on) => set(() => window = on ? w : null),
                        ),
                    ]),
                    title('الدرجة'),
                    Wrap(spacing: 8, children: [
                      ChoiceChip(label: const Text('الكل'), selected: cls == null, onSelected: (_) => set(() => cls = null)),
                      for (final c in data.strings('serviceClasses'))
                        ChoiceChip(label: Text(c == 'VIP' ? 'VIP' : 'عادية'), selected: cls == c, onSelected: (_) => set(() => cls = c)),
                    ]),
                    title('الخدمات'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final a in data.list('amenities'))
                        FilterChip(
                          avatar: Icon(amenityIcon(a.str('code')), size: 16),
                          label: Text(a.str('nameAr')),
                          selected: amenities.contains(a.str('code')),
                          onSelected: (on) => set(() => on ? amenities.add(a.str('code')) : amenities.remove(a.str('code'))),
                        ),
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => set(() {
                            carriers = {};
                            amenities = {};
                            cls = null;
                            window = null;
                          }),
                          child: const Text('مسح'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('تطبيق'))),
                    ]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (apply == true) {
      _query = _Query(sort: _query.sort, carrierIds: carriers, serviceClass: cls, amenities: amenities, window: window);
      _load();
    }
  }

  static String _windowLabel(String key) => switch (key) {
        'EARLY' => 'فجرًا',
        'MORNING' => 'صباحًا',
        'AFTERNOON' => 'ظهرًا',
        'EVENING' => 'مساءً',
        'NIGHT' => 'ليلًا',
        _ => key,
      };

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(bookingFlowProvider);
    if (flow.search == null || (widget.isReturn && flow.outbound == null)) {
      return const ZoolPage(title: 'النتائج', body: EmptyView(title: 'ابدأ البحث من جديد', icon: IconsaxPlusLinear.search_normal_1));
    }
    _base ??= _baseQuery(flow);
    _future ??= ref.read(apiProvider).searchTrips({..._base!, ..._query.params()});
    final s = flow.search!;
    final from = widget.isReturn ? s.to : s.from;
    final to = widget.isReturn ? s.from : s.to;
    final date = widget.isReturn ? (s.returnDate ?? s.date) : s.date;
    final out = flow.outbound;
    final notBefore = widget.isReturn ? (out!.trip.arrivalAt ?? out.trip.departureAt) : null;

    return ZoolPage(
      title: widget.isReturn ? 'رحلة العودة: ${from.name} ← ${to.name}' : '${from.name} ← ${to.name}',
      subtitle: '${formatCalendarDate(date)} · ${travellersLabel(s.passengers)}',
      action: TextButton(onPressed: () => context.pop(), child: const Text('تعديل')),
      body: FutureBuilder<List<Trip>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const _LoadingList();
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _load);
          final all = snap.data!;
          final valid = notBefore == null ? all : all.where((t) => t.departureAt != null && !t.departureAt!.isBefore(notBefore)).toList();
          final hidden = all.length - valid.length;
          return RefreshIndicator(
            color: ZoolColors.brand,
            onRefresh: () async => _load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (widget.isReturn) ...[_OutboundSummary(leg: out!), const SizedBox(height: 12)],
                Row(
                  children: [
                    Expanded(child: Text('${valid.length} رحلة', style: const TextStyle(fontSize: 13, color: ZoolColors.textSecondary))),
                    _ToolChip(icon: IconsaxPlusLinear.sort, label: _sortLabels[_query.sort]!, onTap: _pickSort),
                    const SizedBox(width: 8),
                    _ToolChip(icon: IconsaxPlusLinear.setting_4, label: _query.filtered ? 'فلترة •' : 'فلترة', onTap: _pickFilter),
                  ],
                ),
                const SizedBox(height: 12),
                if (valid.isEmpty)
                  EmptyView(
                    title: 'لا توجد رحلات متاحة',
                    message: hidden > 0
                        ? 'توجد $hidden رحلة تغادر قبل وصول رحلة الذهاب. جرّب تاريخ عودة لاحقًا.'
                        : (_query.filtered ? 'لا رحلات تطابق الفلترة. جرّب مسح الفلاتر.' : 'لا توجد رحلات في هذا اليوم. جرّب تاريخًا آخر.'),
                    icon: IconsaxPlusLinear.bus,
                    action: OutlinedButton(onPressed: () => context.pop(), style: OutlinedButton.styleFrom(minimumSize: const Size(180, 44)), child: const Text('تعديل البحث')),
                  )
                else
                  for (final trip in valid) ...[
                    TripCard(trip: trip, onTap: () => context.push('/trip/${widget.isReturn ? 'return' : 'outbound'}/${trip.id}')),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Results – Loading (3074:2718): placeholder cards.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
        children: [
          for (var i = 0; i < 3; i++) ...[
            Container(height: 200, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(ZoolRadii.card))),
            const SizedBox(height: 12),
          ],
        ],
      );
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: ZoolColors.textStrong),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ZoolColors.textStrong)),
            ]),
          ),
        ),
      );
}

class _OutboundSummary extends StatelessWidget {
  const _OutboundSummary({required this.leg});

  final LegSelection leg;

  @override
  Widget build(BuildContext context) => ZoolCard(
        color: ZoolColors.secondarySoft,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(IconsaxPlusBold.tick_circle, color: ZoolColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الذهاب: ${leg.trip.origin.city} ← ${leg.trip.destination.city} · ${formatDateTime(leg.trip.departureAt)} · مقاعد ${leg.labelText}',
              style: const TextStyle(fontSize: 12, color: ZoolColors.brand),
            ),
          ),
        ]),
      );
}
