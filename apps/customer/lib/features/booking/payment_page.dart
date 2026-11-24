import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';

/// C7 / C8 — waiting for the online payment: amount, time left, the provider's next action
/// (`MOCK_CONFIRM` in development, `REDIRECT` with a URL once a PSP is connected), polling until
/// SUCCEEDED (→ tickets) or FAILED / EXPIRED (→ retry from «رحلاتي»).
class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key, required this.intentId, this.bookingId});

  final String intentId;
  final String? bookingId;

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  Json? _intent;
  Object? _error;
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final intent = await ref.read(apiProvider).paymentIntent(widget.intentId);
      if (!mounted) return;
      setState(() {
        _intent = intent;
        _error = null;
      });
      _onStatus(intent);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _onStatus(Json intent) {
    final status = intent.str('status');
    if (status == 'PENDING') return;
    _poll?.cancel();
    bookingsChanged(ref);
    if (status == 'SUCCEEDED') {
      final id = widget.bookingId ?? intent.strings('bookingIds').firstOrNull;
      if (id != null) context.pushReplacement('/done/$id');
    }
  }

  Future<void> _act() async {
    final next = _intent?.objOrNull('nextAction');
    final type = next?.str('type');
    setState(() => _busy = true);
    try {
      if (type == 'MOCK_CONFIRM') {
        final intent = await ref.read(apiProvider).mockConfirm(widget.intentId);
        if (mounted) _onStatus(intent);
      } else {
        final url = next?.strOrNull('url') ?? next?.strOrNull('redirectUrl');
        if (url != null) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final intent = _intent;
    final status = intent?.str('status');
    final failed = status != null && status != 'PENDING' && status != 'SUCCEEDED';
    final mock = intent?.objOrNull('nextAction')?.str('type') == 'MOCK_CONFIRM';
    return ZoolPage(
      title: 'الدفع',
      bottomBar: intent == null || status == 'SUCCEEDED'
          ? null
          : ZoolBottomBar(
              child: failed
                  ? PrimaryButton(label: 'الذهاب إلى رحلاتي', onPressed: () => context.go('/trips'))
                  : PrimaryButton(label: mock ? 'تأكيد الدفع التجريبي' : 'إتمام الدفع', busy: _busy, onPressed: _act),
            ),
      body: intent == null
          ? (_error != null ? ErrorView(error: _error!, onRetry: _refresh) : const LoadingView())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(
                      failed ? IconsaxPlusBold.close_circle : IconsaxPlusBold.card,
                      size: 52,
                      color: failed ? ZoolColors.error : ZoolColors.brand,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  failed ? (status == 'EXPIRED' ? 'انتهت مهلة الدفع' : 'لم يكتمل الدفع') : 'أكمل الدفع لتأكيد حجزك',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ZoolColors.textStrong),
                ),
                const SizedBox(height: 6),
                Text(
                  failed
                      ? 'لم يُخصم أي مبلغ. أُلغيت المقاعد المحجوزة؛ يمكنك الحجز من جديد.'
                      : (mock
                          ? 'بيئة تجريبية: اضغط «تأكيد الدفع التجريبي» لمحاكاة دفع ناجح.'
                          : 'سننقلك إلى صفحة مزوّد الدفع. ستتحدث الحالة هنا تلقائيًا.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: ZoolColors.textSecondary, height: 1.6),
                ),
                const SizedBox(height: 20),
                ZoolCard(
                  child: Column(children: [
                    InfoRow('المبلغ', formatSdg(intent.integer('amountMinor')), large: true, valueColor: ZoolColors.brand),
                    if (!failed && intent.date('expiresAt') != null) ...[
                      const Divider(height: 18),
                      Row(children: [
                        const Expanded(child: Text('الوقت المتبقي للدفع', style: TextStyle(fontSize: 13, color: ZoolColors.textSecondary))),
                        HoldCountdown(expiresAt: intent.date('expiresAt')!, compact: true, onExpired: _refresh),
                      ]),
                    ],
                    if (failed && intent.strOrNull('failureReason') != null) InfoRow('السبب', intent.str('failureReason')),
                  ]),
                ),
                if (!failed) ...[
                  const SizedBox(height: 16),
                  const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ZoolColors.brand)),
                    SizedBox(width: 8),
                    Text('جارٍ التأكد من الدفع…', style: TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                  ]),
                ],
              ],
            ),
    );
  }
}

/// C8 — booking confirmed (online paid, or cash to the driver).
class BookingDonePage extends ConsumerWidget {
  const BookingDonePage({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    final b = booking.value;
    return ZoolPage(
      showBack: false,
      bottomBar: ZoolBottomBar(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PrimaryButton(
            label: 'عرض التذكرة',
            onPressed: () {
              final router = GoRouter.of(context);
              router.go('/trips');
              router.push('/booking/$bookingId');
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => context.go('/'), child: const Text('الرئيسية')),
        ]),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(IconsaxPlusBold.tick_circle, color: ZoolColors.brand, size: 60),
            ),
            const SizedBox(height: 20),
            const Text('تم تأكيد حجزك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ZoolColors.textStrong)),
            const SizedBox(height: 8),
            if (b != null) ...[
              Text('${b.trip.origin.city} ← ${b.trip.destination.city} · ${formatDateTime(b.trip.departureAt)}',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: ZoolColors.textSecondary)),
              const SizedBox(height: 12),
              StatusBadge(bookingChip(b).$1, tone: bookingChip(b).$2),
              if (b.isCash && b.cashToCollectMinor > 0) ...[
                const SizedBox(height: 12),
                Text('ادفع ${formatSdg(b.cashToCollectMinor)} للسائق عند الصعود.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.primary)),
              ],
            ],
            const SizedBox(height: 8),
            const Text('تذكرتك برمز QR جاهزة في «رحلاتي».', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ZoolColors.textMuted)),
          ]),
        ),
      ),
    );
  }
}
