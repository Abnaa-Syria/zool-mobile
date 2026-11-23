import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import '../bookings/booking_tile.dart';

final _recentProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  ref.watch(bookingsVersionProvider);
  return (await ref.watch(apiProvider).bookings(tab: 'ACTIVE')).items.take(5).toList();
});

/// Home (3083:1840): employee and office, wallet balance, today's KPIs, new booking.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardProvider);
    ref.invalidate(walletProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(_recentProvider);
    await ref.read(dashboardProvider.future).catchError((_) => <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: RefreshIndicator(
        color: ZoolColors.secondary,
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            GradientHeader(
              child: Row(
                children: [
                  InitialsAvatar(me.value?.displayName ?? ''),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('أهلًا، ${me.value?.displayName ?? ''}', style: t.titleMedium),
                        Text(
                          me.value == null ? '' : '${me.value!.officeName} · ${roleLabel(me.value!.role)}',
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const _NotificationsBell(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _WalletCard(),
                  const SizedBox(height: 16),
                  if (me.value?.canBook ?? false) ...[
                    PrimaryButton(label: 'حجز جديد', icon: Icons.add_rounded, onPressed: () => context.push('/book')),
                    const SizedBox(height: 20),
                  ],
                  const _TodayKpis(),
                  const SizedBox(height: 20),
                  SectionTitle(
                    'آخر الحجوزات النشطة',
                    action: TextButton(onPressed: () => context.go('/bookings'), child: const Text('عرض الكل')),
                  ),
                  Consumer(builder: (context, ref, _) {
                    final recent = ref.watch(_recentProvider);
                    return AsyncBody(
                      value: recent,
                      onRetry: () => ref.invalidate(_recentProvider),
                      data: (items) => items.isEmpty
                          ? const EmptyView(title: 'لا توجد حجوزات نشطة', icon: Icons.confirmation_number_outlined)
                          : Column(
                              children: [
                                for (final b in items) ...[BookingTile(booking: b), const SizedBox(height: 10)],
                              ],
                            ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsBell extends ConsumerWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return IconButton(
      tooltip: 'الإشعارات',
      onPressed: () async {
        await context.push('/notifications');
        ref.invalidate(unreadCountProvider);
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        backgroundColor: ZoolColors.primary,
        child: const Icon(Icons.notifications_none_rounded, color: ZoolColors.secondary, size: 28),
      ),
    );
  }
}

class _WalletCard extends ConsumerWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final t = Theme.of(context).textTheme;
    final w = wallet.value;
    return ZoolCard(
      color: ZoolColors.secondary,
      onTap: () => context.go('/wallet'),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('رصيد المحفظة', style: t.bodyMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 6),
                if (wallet.hasError && w == null)
                  Text('تعذّر التحميل — اضغط للمحاولة', style: t.bodyMedium?.copyWith(color: Colors.white))
                else
                  Text(
                    w == null ? '…' : formatSdg(w.integer('balanceMinor')),
                    style: t.titleLarge?.copyWith(color: Colors.white, fontSize: 24),
                  ),
                if (w != null && w.flag('lowBalance')) ...[
                  const SizedBox(height: 8),
                  const StatusBadge('الرصيد منخفض — اشحن المحفظة', tone: BadgeTone.warning),
                ],
              ],
            ),
          ),
          const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 36),
        ],
      ),
    );
  }
}

class _TodayKpis extends ConsumerWidget {
  const _TodayKpis();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final d = dash.value;
    final scope = d?.str('scope') == 'OFFICE' ? 'المكتب' : 'مبيعاتك';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('اليوم ($scope)'),
        if (dash.hasError && d == null)
          ErrorView(error: dash.error!, onRetry: () => ref.invalidate(dashboardProvider))
        else
          GridView(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 76,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              KpiTile(label: 'الحجوزات', value: d == null ? '…' : '${d.integer('bookingsCount')}', icon: Icons.receipt_long_rounded),
              KpiTile(label: 'التذاكر المباعة', value: d == null ? '…' : '${d.integer('ticketsSold')}', icon: Icons.confirmation_number_rounded),
              KpiTile(label: 'المبيعات', value: d == null ? '…' : formatSdg(d.integer('grossSalesMinor')), icon: Icons.payments_rounded),
              KpiTile(
                label: 'العمولة المكتسبة',
                value: d == null ? '…' : formatSdg(d.integer('commissionAccruedMinor')),
                icon: Icons.percent_rounded,
                color: ZoolColors.primary,
              ),
            ],
          ),
      ],
    );
  }
}
