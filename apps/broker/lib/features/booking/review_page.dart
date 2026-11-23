import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import 'flow.dart';
import 'hold_expired.dart';

final _quoteProvider = FutureProvider.autoDispose<BookingQuote>((ref) {
  final body = ref.read(bookingFlowProvider).body();
  return ref.watch(apiProvider).quote(body);
});

/// Review (3083:2677 + B6/B7): legs, passengers, wallet effect, confirm.
///
/// The wallet is debited the FULL ticket total; the commission is earned and settled later
/// (API_CONVENTIONS §5) — there is no "net debit" line.
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  bool _busy = false;

  Future<void> _confirm() async {
    final notifier = ref.read(bookingFlowProvider.notifier);
    final key = notifier.ensureIdempotencyKey(() => const Uuid().v4());
    final body = {...ref.read(bookingFlowProvider).body(), 'idempotencyKey': key};
    setState(() => _busy = true);
    try {
      final res = await ref.read(apiProvider).confirm(body);
      final booking = res.obj('booking');
      final ret = res.objOrNull('returnBooking');
      notifier.completed();
      refreshMoney(ref);
      if (!mounted) return;
      final id = booking.str('id');
      final router = GoRouter.of(context);
      router.go('/');
      router.push('/book/done/$id${ret == null ? '' : '?return=${ret.str('id')}'}');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'HOLD_EXPIRED' || e.code == 'HOLD_REQUIRED') {
        await onHoldExpired(context, ref);
      } else if (e.code == 'SEAT_UNAVAILABLE') {
        await showInfoDialog(context, title: 'المقعد لم يعد متاحًا', message: errorMessage(e));
        if (mounted) await onHoldExpired(context, ref);
      } else if (e.isNetwork) {
        // Same idempotency key on retry: the server never books twice.
        showErrorSnack(context, e);
      } else {
        await showInfoDialog(context, title: 'تعذّر تأكيد الحجز', message: errorMessage(e));
        ref.invalidate(_quoteProvider);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(bookingFlowProvider);
    if (flow.outbound == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyView(title: 'ابدأ الحجز من جديد', icon: Icons.event_seat_outlined));
    }
    final quote = ref.watch(_quoteProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة الحجز')),
      body: AsyncBody(
        value: quote,
        onRetry: () => ref.invalidate(_quoteProvider),
        data: (q) {
          final blocked = !q.sufficientBalance ? 'رصيد المحفظة غير كافٍ لهذا الحجز. اشحن المحفظة ثم أكمل.' : (!q.withinCeiling ? 'هذا الحجز يتجاوز الحد اليومي المسموح للمكتب.' : null);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (flow.expiresAt != null) HoldCountdown(expiresAt: flow.expiresAt!, onExpired: () => onHoldExpired(context, ref)),
              const SizedBox(height: 12),
              _LegCard(title: flow.inbound == null ? 'الرحلة' : 'رحلة الذهاب', leg: flow.outbound!, quote: q),
              if (flow.inbound != null && q.returnLeg != null) ...[
                const SizedBox(height: 12),
                _LegCard(title: 'رحلة العودة', leg: flow.inbound!, quote: q.returnLeg!),
              ],
              const SizedBox(height: 12),
              ZoolCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الركاب', style: t.titleSmall),
                    const SizedBox(height: 6),
                    for (var i = 0; i < flow.passengers.length; i++)
                      InfoRow(
                        flow.passengers[i].fullName.trim(),
                        'مقعد ${[flow.outbound!.seats[i].label, if (flow.inbound != null) flow.inbound!.seats[i].label].join(' / ')}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ZoolCard(
                child: Column(
                  children: [
                    InfoRow('إجمالي التذاكر (يُخصم من المحفظة)', formatSdg(q.grandTotalMinor), bold: true),
                    InfoRow('عمولتك المكتسبة (تُسوّى لاحقًا)', formatSdg(q.grandCommissionMinor), valueColor: ZoolColors.secondary),
                    const Divider(height: 20),
                    InfoRow('الرصيد الحالي', formatSdg(q.walletBalanceMinor)),
                    InfoRow(
                      'الرصيد بعد الحجز',
                      formatSdg(q.balanceAfterMinor),
                      bold: true,
                      valueColor: q.sufficientBalance ? ZoolColors.text : ZoolColors.error,
                    ),
                  ],
                ),
              ),
              if (blocked != null) ...[
                const SizedBox(height: 12),
                ZoolCard(
                  color: ZoolColors.primarySoft,
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: ZoolColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(blocked, style: const TextStyle(color: ZoolColors.primary))),
                    ],
                  ),
                ),
                if (!q.sufficientBalance) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await context.push('/top-up/new');
                      ref.invalidate(_quoteProvider);
                    },
                    icon: const Icon(Icons.add_card_rounded),
                    label: const Text('شحن المحفظة'),
                  ),
                ],
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: quote.value == null
          ? null
          : BottomActionBar(
              child: PrimaryButton(
                label: 'تأكيد الحجز · ${formatSdg(quote.value!.grandTotalMinor)}',
                busy: _busy,
                onPressed: quote.value!.sufficientBalance && quote.value!.withinCeiling ? _confirm : null,
              ),
            ),
    );
  }
}

class _LegCard extends StatelessWidget {
  const _LegCard({required this.title, required this.leg, required this.quote});

  final String title;
  final LegSelection leg;
  final BookingQuote quote;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final trip = leg.trip;
    return ZoolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: t.titleSmall)),
              Text(trip.companyName, style: t.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(formatLongDate(trip.departureAt), style: t.bodySmall),
          const SizedBox(height: 12),
          RouteTimeline(
            departureAt: trip.departureAt,
            arrivalAt: trip.arrivalAt,
            originCity: trip.origin.city,
            destinationCity: trip.destination.city,
            originStation: trip.origin.station,
            destinationStation: trip.destination.station,
            durationMinutes: trip.durationMinutes,
          ),
          const Divider(height: 24),
          InfoRow('المقاعد', leg.seatLabels),
          InfoRow('سعر التذكرة', formatSdg(quote.unitPriceMinor)),
          InfoRow('الإجمالي (${quote.seatCount} تذكرة)', formatSdg(quote.totalMinor), bold: true),
        ],
      ),
    );
  }
}
