import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';

/// B2 — office wallet: balance, ledger, top-up requests.
class WalletPage extends ConsumerWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canTopUp = ref.watch(meProvider).value?.canTopUp ?? false;
    final version = ref.watch(bookingsVersionProvider);
    final api = ref.watch(apiProvider);
    final wallet = ref.watch(walletProvider);
    final t = Theme.of(context).textTheme;
    final tabs = [const Tab(text: 'الحركات'), if (canTopUp) const Tab(text: 'طلبات الشحن')];
    return DefaultTabController(
      length: tabs.length,
      child: ZoolPage(
        title: 'المحفظة',
        body: NestedScrollView(
          headerSliverBuilder: (_, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: ZoolCard(
                  color: ZoolColors.brand,
                  radius: ZoolRadii.bigCard,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الرصيد المتاح', style: t.bodyMedium?.copyWith(color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text(
                        wallet.value == null ? (wallet.hasError ? errorMessage(wallet.error) : '…') : formatSdg(wallet.value!.integer('balanceMinor')),
                        style: t.titleLarge?.copyWith(color: Colors.white, fontSize: wallet.value == null ? 15 : 26),
                      ),
                      if (wallet.value?.flag('lowBalance') ?? false) ...[
                        const SizedBox(height: 8),
                        StatusBadge(
                          'أقل من حد التنبيه (${formatSdg(wallet.value!.integer('lowBalanceThresholdMinor'))})',
                          tone: BadgeTone.warning,
                        ),
                      ],
                      if (canTopUp) ...[
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: ZoolColors.secondary, minimumSize: const Size.fromHeight(46)),
                          onPressed: () => context.push('/top-up/new'),
                          icon: const Icon(IconsaxPlusLinear.wallet_add),
                          label: const Text('شحن المحفظة'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ZoolRadii.card)),
                child: TabBar(tabs: tabs),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              PagedList<LedgerEntry>(
                reloadKey: version,
                fetch: (page) async {
                  final res = await api.ledger(page: page);
                  return (items: res.items, totalPages: res.totalPages);
                },
                itemBuilder: (context, e) => _LedgerTile(entry: e),
                empty: const EmptyView(title: 'لا توجد حركات بعد', icon: IconsaxPlusLinear.receipt_2),
              ),
              if (canTopUp)
                PagedList<TopUp>(
                  reloadKey: version,
                  fetch: (page) async {
                    final res = await api.topUps(page: page);
                    return (items: res.items, totalPages: res.totalPages);
                  },
                  itemBuilder: (context, x) => _TopUpTile(topUp: x),
                  empty: const EmptyView(title: 'لا توجد طلبات شحن', icon: IconsaxPlusLinear.card_add),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = entry;
    final ref = e.referenceType;
    VoidCallback? open;
    if (ref == 'booking' && e.referenceId != null) open = () => context.push('/booking/${e.referenceId}');
    if (ref == 'top_up_intent' && e.referenceId != null) open = () => context.push('/top-up/${e.referenceId}');
    return ZoolCard(
      onTap: open,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: e.credit ? ZoolColors.secondarySoft : ZoolColors.primarySoft,
            child: Icon(e.credit ? IconsaxPlusLinear.arrow_down : IconsaxPlusLinear.arrow_up, size: 18, color: e.credit ? ZoolColors.secondary : ZoolColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ledgerType(e.type), style: t.titleSmall),
                Text(formatDateTime(e.createdAt), style: t.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatSignedSdg(e.amountMinor, credit: e.credit), style: t.titleSmall?.copyWith(color: e.credit ? ZoolColors.secondary : ZoolColors.primary)),
              Text('الرصيد ${formatSdg(e.balanceAfterMinor)}', style: t.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopUpTile extends StatelessWidget {
  const _TopUpTile({required this.topUp});

  final TopUp topUp;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (label, tone) = topUpStatus(topUp.status);
    return ZoolCard(
      onTap: () => context.push('/top-up/${topUp.id}'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatSdg(topUp.amountMinor), style: t.titleSmall),
                Text(formatDateTime(topUp.createdAt), style: t.bodySmall),
              ],
            ),
          ),
          StatusBadge(label, tone: tone),
        ],
      ),
    );
  }
}
