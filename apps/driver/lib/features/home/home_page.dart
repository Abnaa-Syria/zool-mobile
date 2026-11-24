import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import '../gps/gps_banner.dart';
import '../trips/trip_card.dart';

/// Driver home (Figma 3043:2004): greeting, today's KPIs, the current trip and today's trips.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    final dash = ref.watch(dashboardProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    ref.listen(dashboardProvider, (_, next) {
      final current = next.value?.currentTrip;
      if (current != null) syncGps(ref, current.id, current.status);
    });

    return ZoolPage(
      header: GreetingHeader(
        name: me?.displayName ?? '',
        subtitle: me?.companyName ?? '',
        unread: unread > 0,
        onBell: () async {
          await context.push('/notifications');
          ref.invalidate(unreadCountProvider);
        },
      ),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(meProvider);
          ref.invalidate(unreadCountProvider);
          return ref.refresh(dashboardProvider.future);
        },
        child: AsyncBody<DriverDashboard>(
          value: dash,
          onRetry: () => ref.invalidate(dashboardProvider),
          data: (d) => _Body(d),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.d);

  final DriverDashboard d;

  @override
  Widget build(BuildContext context) {
    final current = d.currentTrip;
    final featured = current ?? d.nextTrip;
    final today = d.todayTrips.where((t) => t.id != featured?.id).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(children: [
          Expanded(child: _Kpi(icon: IconsaxPlusLinear.routing, label: 'رحلات اليوم', value: tripsCountLabel(d.tripsToday))),
          const SizedBox(width: 12),
          Expanded(child: _Kpi(icon: IconsaxPlusLinear.people, label: 'المقاعد المحجوزة', value: d.bookedSeatsToday == 0 ? '0 راكب' : passengersLabel(d.bookedSeatsToday))),
        ]),
        if (current != null) ...[const SizedBox(height: 12), const GpsBanner()],
        const SizedBox(height: 18),
        SectionTitle(
          current != null ? 'الرحلة الحالية' : 'الرحلة القادمة',
          action: featured == null
              ? null
              : _Link('عرض تفاصيل الرحلة', () => context.push('/trip/${featured.id}')),
        ),
        if (featured == null)
          const ZoolCard(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: EmptyView(title: 'لا توجد رحلة حالية', message: 'ستظهر هنا رحلتك عند إسنادها إليك من شركة النقل.', icon: IconsaxPlusLinear.bus),
          )
        else
          TripCard(trip: featured, highlight: current != null, onTap: () => context.push('/trip/${featured.id}')),
        const SizedBox(height: 18),
        SectionTitle('رحلات اليوم', action: _Link('عرض الكل', () => context.go('/trips'))),
        if (today.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('لا توجد رحلات أخرى اليوم.', textAlign: TextAlign.center, style: TextStyle(color: ZoolColors.textSecondary)),
          ),
        for (final t in today) ...[
          TodayTripCard(trip: t, onTap: () => context.push('/trip/${t.id}')),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ZoolColors.brand)),
      ),
    );
  }
}

/// KPI card from the design: pink icon chip, grey label, big bold value.
class _Kpi extends StatelessWidget {
  const _Kpi({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ZoolCard(
      radius: ZoolRadii.bigCard,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: ZoolColors.primarySoft, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: ZoolColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary))),
        ]),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ZoolColors.textStrong)),
        ),
      ]),
    );
  }
}
