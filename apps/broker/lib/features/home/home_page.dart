import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// Home (Figma 3083:1840): greeting + bell, today's sales, wallet balance, quick access.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardProvider);
    ref.invalidate(walletProvider);
    ref.invalidate(unreadCountProvider);
    await ref.read(dashboardProvider.future).catchError((_) => <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    return ZoolPage(
      header: BrokerGreeting(me: me),
      body: RefreshIndicator(
        color: ZoolColors.brand,
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const _TodaySales(),
            const SizedBox(height: 20),
            const _WalletCard(),
            const SizedBox(height: 20),
            Text('الوصول السريع', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                if (me?.canBook ?? false) ...[
                  Expanded(
                    child: QuickButton(
                      label: 'حجز رحلة جديدة',
                      icon: const Icon(IconsaxPlusBold.calendar_2, color: ZoolColors.secondary),
                      onTap: () => context.go('/book'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: QuickButton(
                    label: 'إدارة الحجوزات',
                    icon: const ZoolSvgIcon('bus_bold', color: ZoolColors.secondary),
                    onTap: () => context.go('/bookings'),
                  ),
                ),
              ],
            ),
            if (me?.canTopUp ?? false) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: QuickButton(
                      label: 'شحن المحفظة',
                      icon: const Icon(IconsaxPlusBold.wallet_add, color: ZoolColors.secondary),
                      onTap: () => context.push('/top-up/new'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuickButton(
                      label: 'حركات المحفظة',
                      icon: const Icon(IconsaxPlusBold.wallet_3, color: ZoolColors.secondary),
                      onTap: () => context.push('/wallet'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Avatar · «مرحباً، أحمد» · office, and the bell with an unread dot.
class BrokerGreeting extends ConsumerWidget {
  const BrokerGreeting({super.key, required this.me});

  final BrokerMe? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return GreetingHeader(
      name: me?.displayName ?? '',
      subtitle: me?.officeName ?? '',
      unread: unread > 0,
      onBell: () async {
        await context.push('/notifications');
        ref.invalidate(unreadCountProvider);
      },
    );
  }
}

class _TodaySales extends ConsumerWidget {
  const _TodaySales();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final d = dash.value;
    final self = d?.str('scope') == 'SELF';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(self ? 'أداء مبيعاتك اليوم' : 'أداء المبيعات اليوم', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (dash.hasError && d == null)
          ZoolCard(child: ErrorView(error: dash.error!, onRetry: () => ref.invalidate(dashboardProvider)))
        else
          Row(
            children: [
              Expanded(child: StatTile(label: 'حجوزات اليوم', value: d == null ? '…' : ticketsLabel(d.integer('ticketsSold')))),
              const SizedBox(width: 10),
              Expanded(child: StatTile(label: 'إجمالي المبيعات', value: d == null ? '…' : formatSdg(d.integer('grossSalesMinor')))),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'العمولة',
                  value: d == null ? '…' : formatSdg(d.integer('commissionAccruedMinor')),
                  valueColor: ZoolColors.brand,
                ),
              ),
            ],
          ),
      ],
    );
  }

}

class _WalletCard extends ConsumerWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final w = wallet.value;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(ZoolRadii.bigCard), boxShadow: ZoolShadows.wallet),
      child: ZoolCard(
        color: ZoolColors.brand,
        radius: ZoolRadii.bigCard,
        padding: const EdgeInsets.all(16),
        onTap: () => context.push('/wallet'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('الرصيد الحالي للمكتب', style: TextStyle(fontSize: 13, color: Color(0xB3E8F5EE)))),
                if (w != null && w.flag('lowBalance')) const StatusBadge('الرصيد منخفض', tone: BadgeTone.warning),
              ],
            ),
            const SizedBox(height: 12),
            if (wallet.hasError && w == null)
              Text(errorMessage(wallet.error), style: const TextStyle(color: Colors.white, fontSize: 14))
            else
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: MoneyText(w == null ? '…' : formatSdg(w.integer('balanceMinor')), size: 32, color: Colors.white, currencyColor: ZoolColors.background),
              ),
          ],
        ),
      ),
    );
  }
}
