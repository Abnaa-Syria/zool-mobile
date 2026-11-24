import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import 'flow.dart';
import 'hold_expired.dart';
import 'trip_card.dart';

/// Booking review / checkout (Figma 3074:3175 + C6): legs, passengers and seats, coupon,
/// payment method (online / cash to the driver with the reason when blocked), totals, pay.
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  final _coupon = TextEditingController();
  Future<Quote>? _quote;
  String? _couponError;
  String _method = 'ONLINE';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _coupon.text = ref.read(bookingFlowProvider).couponCode ?? '';
    _quote = _fetch();
  }

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  Future<Quote> _fetch() {
    final future = ref.read(apiProvider).quote(ref.read(bookingFlowProvider).body());
    future.then((q) {
      if (mounted && !q.cashAllowed && _method == 'CASH_ON_BOARD') setState(() => _method = 'ONLINE');
    }, onError: (_) {});
    return future;
  }

  void _load() {
    final future = _fetch();
    setState(() {
      _quote = future;
    });
  }

  Future<void> _applyCoupon() async {
    final code = _coupon.text.trim().toUpperCase();
    ref.read(bookingFlowProvider.notifier).setCoupon(code.isEmpty ? null : code);
    try {
      final q = await ref.read(apiProvider).quote(ref.read(bookingFlowProvider).body());
      if (!mounted) return;
      setState(() {
        _couponError = null;
        _quote = Future.value(q);
      });
      if (code.isNotEmpty) showMessageSnack(context, 'تم تطبيق كود الخصم');
    } on ApiException catch (e) {
      ref.read(bookingFlowProvider.notifier).setCoupon(null);
      if (!mounted) return;
      if (e.code == 'HOLD_EXPIRED') return onHoldExpired(context, ref);
      setState(() => _couponError = e.code == 'COUPON_INVALID' ? couponErrorText(e.detailsMap['reason']) : errorMessage(e));
      _load();
    }
  }

  Future<void> _pay() async {
    final notifier = ref.read(bookingFlowProvider.notifier);
    final key = notifier.ensureIdempotencyKey(() => const Uuid().v4());
    final body = {...ref.read(bookingFlowProvider).body(), 'paymentMethod': _method};
    setState(() => _busy = true);
    try {
      final res = await ref.read(apiProvider).createBooking(body, idempotencyKey: key);
      final bookings = res.list('bookings').map(Booking.new).toList();
      final payment = res.objOrNull('payment');
      notifier.completed();
      bookingsChanged(ref);
      if (!mounted) return;
      final router = GoRouter.of(context);
      router.go('/');
      if (payment != null && payment.str('status') == 'PENDING') {
        router.push('/payment/${payment.str('intentId')}?booking=${bookings.first.id}');
      } else {
        router.push('/done/${bookings.first.id}');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'HOLD_EXPIRED' || e.code == 'HOLD_REQUIRED') {
        await onHoldExpired(context, ref);
      } else if (e.code == 'SEAT_UNAVAILABLE') {
        await showInfoDialog(context, title: 'المقعد غير متاح', message: errorMessage(e));
        if (mounted) await onHoldExpired(context, ref);
      } else if (e.code == 'CASH_NOT_ALLOWED') {
        setState(() => _method = 'ONLINE');
        showErrorSnack(context, e);
        _load();
      } else if (e.isNetwork) {
        showErrorSnack(context, e); // the same idempotency key is reused on retry
      } else {
        await showInfoDialog(context, title: 'تعذّر إتمام الحجز', message: errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(bookingFlowProvider);
    if (flow.outbound == null) {
      return const ZoolPage(title: 'مراجعة الحجز', body: EmptyView(title: 'ابدأ الحجز من جديد', icon: IconsaxPlusLinear.ticket));
    }
    return FutureBuilder<Quote>(
      future: _quote,
      builder: (context, snap) {
        final q = snap.data;
        final total = q == null ? '' : formatSdg(q.totalMinor);
        return ZoolPage(
          title: 'مراجعة الحجز',
          bottomBar: q == null
              ? null
              : ZoolBottomBar(
                  child: PrimaryButton(
                    label: _method == 'CASH_ON_BOARD' ? 'تأكيد الحجز · الدفع للسائق $total' : 'الدفع الآن | $total',
                    busy: _busy,
                    onPressed: _pay,
                  ),
                ),
          body: snap.connectionState != ConnectionState.done
              ? const LoadingView()
              : snap.hasError
                  ? (snap.error is ApiException && (snap.error as ApiException).code == 'HOLD_EXPIRED'
                      ? EmptyView(
                          title: 'انتهت مدة حجز المقاعد',
                          icon: IconsaxPlusLinear.timer_1,
                          action: OutlinedButton(onPressed: () => onHoldExpired(context, ref), child: const Text('اختيار المقاعد')),
                        )
                      : ErrorView(error: snap.error!, onRetry: _load))
                  : _body(flow, q!),
        );
      },
    );
  }

  Widget _body(BookingFlowState flow, Quote q) {
    String seatsOf(int i) => [flow.outbound!.seats[i].label, if (flow.inbound != null) flow.inbound!.seats[i].label].join(' / ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (flow.expiresAt != null) ...[
          HoldCountdown(expiresAt: flow.expiresAt!, onExpired: () => onHoldExpired(context, ref)),
          const SizedBox(height: 12),
        ],
        TripSummaryCard(trip: flow.outbound!.trip, title: flow.inbound == null ? null : 'رحلة الذهاب'),
        if (flow.inbound != null) ...[const SizedBox(height: 12), TripSummaryCard(trip: flow.inbound!.trip, title: 'رحلة العودة')],
        const SizedBox(height: 16),
        const SectionTitle('بيانات الركاب'),
        ZoolCard(
          child: Column(children: [
            for (var i = 0; i < flow.passengers.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Expanded(child: Text(flow.passengers[i].fullName.trim(), style: const TextStyle(fontSize: 14, color: ZoolColors.textStrong))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: ZoolColors.secondarySoft, borderRadius: BorderRadius.circular(8)),
                    child: Text(seatsOf(i), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ZoolColors.brand)),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        const SectionTitle('كود الخصم'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: _coupon,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(hintText: 'أدخل الكود إن وُجد', fillColor: Colors.white, errorText: _couponError),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(height: 50, child: OutlinedButton(onPressed: _applyCoupon, style: OutlinedButton.styleFrom(minimumSize: const Size(90, 50)), child: const Text('تطبيق'))),
        ]),
        const SizedBox(height: 16),
        const SectionTitle('طريقة الدفع'),
        _MethodTile(
          selected: _method == 'ONLINE',
          icon: IconsaxPlusLinear.card,
          title: 'دفع إلكتروني',
          subtitle: 'ادفع الآن وتصلك التذكرة فورًا',
          onTap: () => setState(() => _method = 'ONLINE'),
        ),
        const SizedBox(height: 10),
        _MethodTile(
          selected: _method == 'CASH_ON_BOARD',
          icon: IconsaxPlusLinear.money_3,
          title: 'نقدًا للسائق',
          subtitle: q.cashAllowed ? 'تُصدر التذكرة الآن وتدفع للسائق عند الصعود' : cashBlockedText(q.cashBlockedReason),
          enabled: q.cashAllowed,
          onTap: () => setState(() => _method = 'CASH_ON_BOARD'),
        ),
        const SizedBox(height: 16),
        const SectionTitle('ملخص الدفع'),
        ZoolCard(
          child: Column(children: [
            for (final leg in q.legs) ...[
              if (q.legs.length > 1) InfoRow(legLabel(leg.strOrNull('leg')) ?? 'الرحلة', '', bold: true),
              InfoRow('سعر التذكرة', formatSdg(leg.integer('unitPriceMinor'))),
              InfoRow('عدد المسافرين', '${leg.list('seats').length}'),
            ],
            InfoRow('المجموع الفرعي', formatSdg(q.subtotalMinor)),
            if (q.discountMinor > 0) InfoRow('خصم الكوبون', '-${formatSdg(q.discountMinor)}', valueColor: ZoolColors.primary),
            const Divider(height: 18),
            InfoRow('الإجمالي النهائي', formatSdg(q.totalMinor), large: true, valueColor: ZoolColors.brand),
          ]),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.selected, required this.icon, required this.title, required this.subtitle, required this.onTap, this.enabled = true});

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZoolRadii.card),
          side: BorderSide(color: selected ? ZoolColors.brand : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(ZoolRadii.card),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: ZoolColors.secondarySoft, shape: BoxShape.circle),
                child: Icon(icon, color: ZoolColors.brand, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: enabled ? ZoolColors.textMuted : ZoolColors.primary)),
                ]),
              ),
              Icon(selected ? IconsaxPlusBold.tick_circle : IconsaxPlusLinear.record, color: selected ? ZoolColors.brand : ZoolColors.border),
            ]),
          ),
        ),
      ),
    );
  }
}
