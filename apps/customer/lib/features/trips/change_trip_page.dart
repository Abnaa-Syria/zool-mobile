import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import '../booking/seats_page.dart';
import '../booking/trip_card.dart';

typedef _Key = ({String bookingId, String date});

final _optionsProvider = FutureProvider.autoDispose.family<List<Trip>, _Key>((ref, k) => ref.watch(apiProvider).changeOptions(k.bookingId, k.date));

/// C15 — change the trip: date → another trip of the same carrier and cities → seats (held) →
/// quote (pay the difference / refund / cash difference) → confirm (→ payment when due).
class ChangeTripPage extends ConsumerStatefulWidget {
  const ChangeTripPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ChangeTripPage> createState() => _ChangeTripPageState();
}

class _ChangeTripPageState extends ConsumerState<ChangeTripPage> {
  DateTime? _date;
  Trip? _option;
  final Set<String> _seats = {};
  bool _busy = false;
  String? _key;

  DateTime _defaultDate(Booking b) {
    final today = sudanNow();
    final dep = b.trip.departureAt == null ? today : toSudan(b.trip.departureAt!);
    final d = dep.isBefore(today) ? today : dep;
    return DateTime(d.year, d.month, d.day);
  }

  Future<void> _review(Booking b, SeatMapData data) async {
    final api = ref.read(apiProvider);
    final labels = data.seats.where((s) => _seats.contains(s.id)).map((s) => s.label).toList()..sort(labelOrder);
    setState(() => _busy = true);
    List<String> holdIds;
    Json quote;
    try {
      holdIds = (await api.hold(_option!.id, labels)).holdIds;
      quote = await api.changeQuote(b.id, holdIds);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showErrorSnack(context, e);
        ref.invalidate(seatsProvider(_option!.id));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final pay = quote.integer('payMinor'), refund = quote.integer('refundMinor');
    final cashDiff = quote.intOrNull('cashDifferenceMinor') ?? quote.intOrNull('cashToCollectDeltaMinor');
    final ok = await showConfirmDialog(
      context,
      title: 'تأكيد تغيير الرحلة',
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        InfoRow('الرحلة الجديدة', formatDateTime(_option!.departureAt)),
        InfoRow('المقاعد', labels.join('، ')),
        InfoRow('الإجمالي السابق', formatSdg(quote.integer('oldTotalMinor'))),
        InfoRow('الإجمالي الجديد', formatSdg(quote.integer('newTotalMinor'))),
        if (quote.integer('changeFeeMinor') > 0) InfoRow('رسوم التعديل', formatSdg(quote.integer('changeFeeMinor'))),
        const Divider(height: 16),
        if (pay > 0)
          InfoRow('ادفع الفرق', formatSdg(pay), bold: true, valueColor: ZoolColors.primary)
        else if (refund > 0)
          InfoRow('يُسترد لك', formatSdg(refund), bold: true, valueColor: ZoolColors.brand)
        else if (cashDiff != null && cashDiff != 0)
          InfoRow('يُدفع للسائق', formatSdg(cashDiff), bold: true)
        else
          const InfoRow('فرق السعر', 'لا يوجد'),
      ]),
      confirmLabel: pay > 0 ? 'تأكيد والدفع' : 'تأكيد التغيير',
    );
    if (!ok || !mounted) {
      api.releaseHolds(holdIds);
      return;
    }
    _key ??= const Uuid().v4();
    setState(() => _busy = true);
    try {
      final res = await api.change(b.id, holdIds, idempotencyKey: _key!);
      bookingsChanged(ref);
      ref.invalidate(bookingProvider(b.id));
      final newBooking = Booking(res.obj('booking'));
      final payment = res.objOrNull('payment');
      if (!mounted) return;
      final router = GoRouter.of(context);
      router.go('/trips');
      if (payment != null && payment.str('status') == 'PENDING') {
        router.push('/payment/${payment.str('intentId')}?booking=${newBooking.id}');
      } else {
        router.push('/booking/${newBooking.id}');
        showMessageSnack(context, 'تم تغيير رحلتك.');
      }
    } catch (e) {
      if (e is ApiException && !e.isNetwork) _key = null;
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider(widget.bookingId));
    return ZoolPage(
      title: 'تغيير موعد الرحلة',
      onBack: _option == null
          ? null
          : () => setState(() {
                _option = null;
                _seats.clear();
              }),
      bottomBar: _option == null || booking.value == null
          ? null
          : ZoolBottomBar(
              child: Builder(builder: (context) {
                final needed = booking.value!.activeTickets.length;
                final data = ref.watch(seatsProvider(_option!.id)).value;
                return PrimaryButton(
                  label: 'مراجعة التغيير (${_seats.length}/$needed)',
                  busy: _busy,
                  onPressed: _seats.length == needed && data != null ? () => _review(booking.value!, data) : null,
                );
              }),
            ),
      body: AsyncBody(
        value: booking,
        onRetry: () => ref.invalidate(bookingProvider(widget.bookingId)),
        data: (b) {
          final needed = b.activeTickets.length;
          if (_option != null) {
            final seats = ref.watch(seatsProvider(_option!.id));
            return AsyncBody(
              value: seats,
              onRetry: () => ref.invalidate(seatsProvider(_option!.id)),
              data: (data) => ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
                TripSummaryCard(trip: _option!),
                const SizedBox(height: 16),
                Text('اختر ${seatsLabel(needed)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                CustomerSeatMap(
                  data: data,
                  selected: _seats,
                  onToggle: (s) => setState(() {
                    if (_seats.contains(s.id)) {
                      _seats.remove(s.id);
                    } else if (_seats.length < needed) {
                      _seats.add(s.id);
                    }
                  }),
                ),
              ]),
            );
          }
          final date = _date ?? _defaultDate(b);
          final key = (bookingId: b.id, date: dayKey(date));
          final options = ref.watch(_optionsProvider(key));
          return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
            ZoolCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('حجزك الحالي', style: TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                Text('${b.trip.origin.city} ← ${b.trip.destination.city} · ${formatDateTime(b.trip.departureAt)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text('${travellersLabel(needed)} · ${formatSdg(b.totalMinor)}', style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final now = sudanNow();
                final picked = await showZoolDatePicker(
                  context,
                  initialDate: date,
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 120)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              icon: const Icon(IconsaxPlusLinear.calendar_1),
              label: Text(formatCalendarDate(date)),
            ),
            const SizedBox(height: 16),
            AsyncBody(
              value: options,
              onRetry: () => ref.invalidate(_optionsProvider(key)),
              data: (list) {
                final usable = list.where((t) => t.id != b.trip.id).toList();
                if (usable.isEmpty) {
                  return const EmptyView(title: 'لا توجد رحلات بديلة في هذا اليوم', message: 'جرّب يومًا آخر.', icon: IconsaxPlusLinear.calendar_remove);
                }
                return Column(children: [
                  for (final t in usable) ...[
                    _Option(
                      trip: t,
                      diff: t.json.intOrNull('priceDifferenceMinor'),
                      enough: t.seatsAvailable >= needed,
                      onTap: () => setState(() {
                        _option = t;
                        _seats.clear();
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                ]);
              },
            ),
          ]);
        },
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.trip, required this.diff, required this.enough, required this.onTap});

  final Trip trip;
  final int? diff;
  final bool enough;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = diff ?? 0;
    return ZoolCard(
      onTap: enough ? onTap : null,
      child: Column(children: [
        TripTimeline(trip: trip),
        const Divider(height: 20),
        Row(children: [
          Text(enough ? '${seatsLabel(trip.seatsAvailable)} متاحة' : 'المقاعد غير كافية', style: TextStyle(fontSize: 12, color: enough ? ZoolColors.textMuted : ZoolColors.error)),
          const Spacer(),
          Text(
            diff == null ? formatSdg(trip.priceMinor) : (d == 0 ? 'نفس السعر' : (d > 0 ? 'فرق +${formatSdg(d)}' : 'يُسترد ${formatSdg(-d)}')),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: d > 0 ? ZoolColors.primary : ZoolColors.brand),
          ),
        ]),
      ]),
    );
  }
}
