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
import 'seats_page.dart';

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
      router.go('/book');
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
      return const ZoolPage(title: 'مراجعة وتأكيد الحجز', body: EmptyView(title: 'ابدأ الحجز من جديد', icon: IconsaxPlusLinear.ticket));
    }
    final quote = ref.watch(_quoteProvider);
    final q = quote.value;
    return ZoolPage(
      title: 'مراجعة وتأكيد الحجز',
      bottomBar: q == null
          ? null
          : ZoolBottomBar(
              child: PrimaryButton(
                label: 'تأكيد الحجز والدفع الفوري',
                busy: _busy,
                onPressed: q.sufficientBalance && q.withinCeiling ? _confirm : null,
              ),
            ),
      body: AsyncBody(
        value: quote,
        onRetry: () => ref.invalidate(_quoteProvider),
        data: (q) {
          final blocked = !q.sufficientBalance
              ? 'رصيد المحفظة غير كافٍ لهذا الحجز. اشحن المحفظة ثم أكمل.'
              : (!q.withinCeiling ? 'هذا الحجز يتجاوز الحد اليومي المسموح للمكتب.' : null);
          String seatsOf(int i) => [flow.outbound!.seats[i].label, if (flow.inbound != null) flow.inbound!.seats[i].label].join(' / ');
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (flow.expiresAt != null) ...[
                HoldCountdown(expiresAt: flow.expiresAt!, onExpired: () => onHoldExpired(context, ref)),
                const SizedBox(height: 12),
              ],
              TripSummaryCard(trip: flow.outbound!.trip, title: flow.inbound == null ? null : 'رحلة الذهاب'),
              if (flow.inbound != null) ...[
                const SizedBox(height: 12),
                TripSummaryCard(trip: flow.inbound!.trip, title: 'رحلة العودة'),
              ],
              const SizedBox(height: 16),
              ZoolCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('المسافرون والمقاعد المسجلة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < flow.passengers.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(flow.passengers[i].fullName.trim(), style: const TextStyle(fontSize: 14, color: ZoolColors.textStrong))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: ZoolColors.secondarySoft, borderRadius: BorderRadius.circular(8)),
                              child: Text(seatsOf(i), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ZoolColors.brand)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ZoolCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('ملخص الدفع والمحفظة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
                    const SizedBox(height: 8),
                    InfoRow('قيمة التذاكر الإجمالية (${q.seatCount + (q.returnLeg?.seatCount ?? 0)} تذكرة):', formatSdg(q.grandTotalMinor)),
                    InfoRow('عمولتك (تُسوّى لاحقًا):', '+${formatSdg(q.grandCommissionMinor)}', valueColor: ZoolColors.brand),
                    const Divider(height: 18),
                    InfoRow('رصيد المحفظة قبل الحجز:', formatSdg(q.walletBalanceMinor)),
                    InfoRow('الرصيد المتوقع بعد الخصم:', formatSdg(q.balanceAfterMinor), valueColor: ZoolColors.primary),
                    const Divider(height: 18),
                    InfoRow('إجمالي الخصم من المحفظة:', formatSdg(q.grandTotalMinor), large: true, valueColor: ZoolColors.brand),
                  ],
                ),
              ),
              if (blocked != null) ...[
                const SizedBox(height: 12),
                ZoolCard(
                  color: ZoolColors.primarySoft,
                  child: Row(
                    children: [
                      const Icon(IconsaxPlusLinear.danger, color: ZoolColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(blocked, style: const TextStyle(color: ZoolColors.primary, fontSize: 13))),
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
                    icon: const Icon(IconsaxPlusLinear.wallet_add),
                    label: const Text('شحن المحفظة'),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
