import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import 'change_seat_sheet.dart';

typedef _OptionsKey = ({String bookingId, String date});

final _optionsProvider = FutureProvider.autoDispose.family<List<ChangeOption>, _OptionsKey>(
  (ref, k) => ref.watch(apiProvider).changeOptions(k.bookingId, k.date),
);

/// B5 / D-CHG-01 — move a booking to another trip of the same carrier and cities:
/// date → trip → seats → quote (wallet pays / gets back the difference, new commission) → confirm.
class ChangeTripPage extends ConsumerStatefulWidget {
  const ChangeTripPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ChangeTripPage> createState() => _ChangeTripPageState();
}

class _ChangeTripPageState extends ConsumerState<ChangeTripPage> {
  DateTime? _date;
  ChangeOption? _option;
  final Set<String> _seats = {};
  String? _idempotencyKey;

  DateTime _defaultDate(Booking b) {
    final today = sudanNow();
    final dep = b.departureAt == null ? today : toSudan(b.departureAt!);
    final d = dep.isBefore(today) ? today : dep;
    return DateTime(d.year, d.month, d.day);
  }

  Future<void> _pickDate(Booking b) async {
    final now = sudanNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? _defaultDate(b),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 120)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _option = null;
        _seats.clear();
      });
    }
  }

  Future<void> _review(Booking b, BrokerTrip trip) async {
    final seatIds = trip.seats.where((s) => _seats.contains(s.id)).map((s) => s.id).toList();
    final api = ref.read(apiProvider);
    Json quote;
    try {
      quote = await api.changeQuote(b.id, tripId: trip.id, seatIds: seatIds);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
      return;
    }
    if (!mounted) return;
    final pay = quote.integer('payMinor'), refund = quote.integer('refundMinor');
    final commission = quote.objOrNull('commission');
    final ok = await showConfirmDialog(
      context,
      title: 'تأكيد تغيير الرحلة',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InfoRow('الرحلة الجديدة', formatDateTime(trip.departureAt)),
          InfoRow('المقاعد', quote.strings('seats').join('، ')),
          InfoRow('الإجمالي السابق', formatSdg(quote.integer('oldTotalMinor'))),
          InfoRow('الإجمالي الجديد', formatSdg(quote.integer('newTotalMinor'))),
          if (quote.integer('changeFeeMinor') > 0) InfoRow('رسوم التعديل', formatSdg(quote.integer('changeFeeMinor'))),
          const Divider(height: 16),
          if (pay > 0)
            InfoRow('يُخصم من المحفظة', formatSdg(pay), bold: true, valueColor: ZoolColors.primary)
          else if (refund > 0)
            InfoRow('يُعاد إلى المحفظة', formatSdg(refund), bold: true, valueColor: ZoolColors.secondary)
          else
            const InfoRow('أثر المحفظة', 'لا يوجد فرق'),
          if (commission != null) InfoRow('العمولة الجديدة', formatSdg(commission.integer('newCommissionMinor'))),
        ],
      ),
      confirmLabel: 'تأكيد التغيير',
    );
    if (!ok || !mounted) return;
    _idempotencyKey ??= const Uuid().v4();
    try {
      final booking = await api.change(b.id, tripId: trip.id, seatIds: seatIds, idempotencyKey: _idempotencyKey!);
      refreshMoney(ref);
      ref.invalidate(bookingProvider(b.id));
      if (!mounted) return;
      showMessageSnack(context, 'تم تغيير الرحلة. هذا هو الحجز الجديد.');
      final router = GoRouter.of(context);
      router.pop(); // leave this page
      router.pushReplacement('/booking/${booking.id}'); // the old booking detail → the new booking
    } catch (e) {
      if (e is ApiException && !e.isNetwork) _idempotencyKey = null;
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider(widget.bookingId));
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('تغيير موعد الرحلة')),
      body: AsyncBody(
        value: booking,
        onRetry: () => ref.invalidate(bookingProvider(widget.bookingId)),
        data: (b) {
          final date = _date ?? _defaultDate(b);
          final needed = b.activeTickets.length;
          if (_option != null) return _seatStep(b, needed);
          final key = (bookingId: b.id, date: dayKey(date));
          final options = ref.watch(_optionsProvider(key));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ZoolCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الحجز الحالي', style: t.bodySmall),
                    Text('${b.origin} ← ${b.destination} · ${formatDateTime(b.departureAt)}', style: t.titleSmall),
                    Text('$needed راكب · ${formatSdg(b.totalMinor)}', style: t.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _pickDate(b),
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(formatCalendarDate(date)),
              ),
              const SizedBox(height: 16),
              AsyncBody(
                value: options,
                onRetry: () => ref.invalidate(_optionsProvider(key)),
                data: (list) {
                  final usable = list.where((o) => o.id != b.tripId).toList();
                  if (usable.isEmpty) {
                    return const EmptyView(title: 'لا توجد رحلات بديلة في هذا اليوم', message: 'جرّب يومًا آخر.', icon: Icons.event_busy_rounded);
                  }
                  return Column(
                    children: [
                      for (final o in usable) ...[
                        _OptionCard(
                          option: o,
                          enoughSeats: o.seatsAvailable >= needed,
                          onTap: () => setState(() {
                            _option = o;
                            _seats.clear();
                          }),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _seatStep(Booking b, int needed) {
    final trip = ref.watch(tripProvider(_option!.id));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _option = null);
      },
      child: Column(
        children: [
          Expanded(
            child: AsyncBody(
              value: trip,
              onRetry: () => ref.invalidate(tripProvider(_option!.id)),
              data: (trip) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => setState(() => _option = null), icon: const Icon(Icons.arrow_forward_rounded)),
                      Expanded(child: Text('${formatDateTime(trip.departureAt)} · اختر $needed مقعد', style: Theme.of(context).textTheme.titleSmall)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TripSeatMap(
                      trip: trip,
                      selected: _seats,
                      onToggle: (s) => setState(() {
                        if (_seats.contains(s.id)) {
                          _seats.remove(s.id);
                        } else if (_seats.length < needed) {
                          _seats.add(s.id);
                        }
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          BottomActionBar(
            child: PrimaryButton(
              label: 'مراجعة التغيير (${_seats.length}/$needed)',
              onPressed: _seats.length == needed && trip.value != null ? () => _review(b, trip.value!) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option, required this.enoughSeats, required this.onTap});

  final ChangeOption option;
  final bool enoughSeats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final diff = option.priceDifferenceMinor;
    return ZoolCard(
      onTap: enoughSeats ? onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RouteTimeline(
            departureAt: option.departureAt,
            arrivalAt: option.arrivalAt,
            originCity: option.origin.city,
            destinationCity: option.destination.city,
            originStation: option.origin.station,
            destinationStation: option.destination.station,
            durationMinutes: option.durationMinutes,
          ),
          const Divider(height: 20),
          Row(
            children: [
              Text(enoughSeats ? '${option.seatsAvailable} مقعد متاح' : 'المقاعد غير كافية',
                  style: t.bodySmall?.copyWith(color: enoughSeats ? null : ZoolColors.error)),
              const Spacer(),
              Text(
                diff == 0 ? 'نفس السعر' : (diff > 0 ? 'فرق +${formatSdg(diff)}' : 'يُعاد ${formatSdg(-diff)}'),
                style: t.titleSmall?.copyWith(color: diff > 0 ? ZoolColors.primary : ZoolColors.secondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
