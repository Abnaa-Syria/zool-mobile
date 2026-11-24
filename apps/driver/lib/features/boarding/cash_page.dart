import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// النقد المحصّل (D-screen): what the driver must collect on this trip, what was collected,
/// and each cash ticket — to hand over to the carrier at the end of the trip.
class CashPage extends ConsumerWidget {
  const CashPage({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cash = ref.watch(cashProvider(tripId));
    return ZoolPage(
      title: 'النقد المحصّل',
      subtitle: ref.watch(tripProvider(tripId)).value?.routeLabel,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(cashProvider(tripId).future),
        child: AsyncBody<CashSummary>(
          value: cash,
          onRetry: () => ref.invalidate(cashProvider(tripId)),
          data: (c) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: ZoolColors.brand, borderRadius: BorderRadius.circular(ZoolRadii.bigCard), boxShadow: ZoolShadows.wallet),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('تم تحصيله', style: TextStyle(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 4),
                  MoneyText(formatSdg(c.collectedMinor), size: 28, color: Colors.white, currencyColor: Colors.white70),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: c.expectedMinor == 0 ? 0 : c.collectedMinor / c.expectedMinor,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      color: const Color(0xFF82F2A8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Text('المتوقع ${formatSdg(c.expectedMinor)}', style: const TextStyle(fontSize: 12, color: Colors.white70))),
                    Text('المتبقي ${formatSdg(c.outstandingMinor)}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ]),
              ),
              const SizedBox(height: 18),
              const SectionTitle('تذاكر الدفع نقدًا'),
              if (c.tickets.isEmpty)
                const EmptyView(title: 'لا توجد تذاكر نقدية', message: 'كل تذاكر هذه الرحلة مدفوعة إلكترونيًا.', icon: IconsaxPlusLinear.money_3),
              for (final t in c.tickets) ...[
                ZoolCard(
                  radius: ZoolRadii.bigCard,
                  padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                      child: Text(t.str('seatLabel'), style: const TextStyle(fontWeight: FontWeight.w800, color: ZoolColors.brand)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.str('passenger'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(t.str('ticketNumber'), style: const TextStyle(fontSize: 11, color: ZoolColors.textMuted)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(formatSdg(t.integer('fareMinor')), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      _collected(t),
                    ]),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _collected(Json t) {
    final collected = t.integer('collectedMinor');
    final status = t.str('boardingStatus');
    final (text, color) = collected > 0
        ? ('تم التحصيل', ZoolColors.success)
        : status == 'NO_SHOW'
            ? ('لم يحضر', ZoolColors.error)
            : ('لم يُحصّل', ZoolColors.warning);
    return Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700));
  }
}
