import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';

final _methodsProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(apiProvider).paymentMethods());

/// Payment methods (Figma 3074:3017 + C18): online and cash to the driver with its eligibility;
/// saved cards come with the real payment provider (D-PAY-01).
class PaymentMethodsPage extends ConsumerWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(_methodsProvider);
    final cash = ref.watch(meProvider).value?.cash;
    return ZoolPage(
      title: 'طرق الدفع',
      body: AsyncBody(
        value: methods,
        onRetry: () => ref.invalidate(_methodsProvider),
        data: (data) => ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
          for (final m in data.list('methods'))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ZoolCard(
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: ZoolColors.secondarySoft, shape: BoxShape.circle),
                    child: Icon(m.str('type') == 'CASH_ON_BOARD' ? IconsaxPlusLinear.money_3 : IconsaxPlusLinear.card, color: ZoolColors.brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.str('type') == 'CASH_ON_BOARD' ? 'نقدًا للسائق' : 'دفع إلكتروني', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                        m.str('type') == 'CASH_ON_BOARD'
                            ? (m.flag('eligible', m.flag('available', true)) ? 'ادفع عند الصعود إلى الباص' : cashBlockedText(m.strOrNull('reason')))
                            : (m.flag('isMock') ? 'مزوّد تجريبي (بيئة التطوير)' : 'بطاقة أو محفظة إلكترونية'),
                        style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted),
                      ),
                    ]),
                  ),
                  StatusBadge(m.flag('available', m.flag('eligible', true)) ? 'متاح' : 'غير متاح', tone: m.flag('available', m.flag('eligible', true)) ? BadgeTone.success : BadgeTone.neutral),
                ]),
              ),
            ),
          if (cash != null) ...[
            const SizedBox(height: 6),
            Text(
              'مرات عدم الحضور في الحجوزات النقدية: ${cash.integer('noShowCount')} من ${cash.integer('noShowLimit')}. عند الوصول للحد يتوقف خيار الدفع نقدًا.',
              style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          const Text('حفظ البطاقات يتوفر عند ربط بوابة الدفع الرسمية.', style: TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
        ]),
      ),
    );
  }
}
