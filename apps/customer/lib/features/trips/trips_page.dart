import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import '../booking/trip_card.dart';
import 'rating_sheet.dart';

final liveProvider = FutureProvider.autoDispose.family<LiveTrip, String>((ref, bookingId) => ref.watch(apiProvider).live(bookingId));

/// رحلاتي (Figma 3074:3697 upcoming, 3992 ongoing, 4036 past + C10 cancelled and empty states).
class TripsPage extends ConsumerWidget {
  const TripsPage({super.key});

  static const _tabs = [('UPCOMING', 'القادمة'), ('ONGOING', 'الجارية'), ('PAST', 'السابقة'), ('CANCELLED', 'الملغاة')];

  static const _empty = {
    'UPCOMING': ('لا توجد رحلات قادمة', 'ابحث عن رحلتك القادمة واحجز مقعدك في دقائق.'),
    'ONGOING': ('لا توجد رحلة جارية الآن', 'ستظهر هنا رحلتك عند بدء الصعود مع التتبع المباشر.'),
    'PAST': ('لا توجد رحلات سابقة', 'رحلاتك المكتملة تظهر هنا لتقييمها أو حجزها مرة أخرى.'),
    'CANCELLED': ('لا توجد رحلات ملغاة', 'الحجوزات الملغاة وحالة استرداد المبالغ تظهر هنا.'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(bookingsVersionProvider);
    final api = ref.watch(apiProvider);
    return DefaultTabController(
      length: _tabs.length,
      child: ZoolPage(
        header: const Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text('رحلاتي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ZoolColors.textStrong)),
        ),
        body: Column(children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ZoolRadii.card)),
            child: TabBar(tabs: [for (final t in _tabs) Tab(text: t.$2)]),
          ),
          Expanded(
            child: TabBarView(children: [
              for (final (tab, _) in _tabs)
                PagedList<Booking>(
                  reloadKey: (tab, version),
                  separator: 12,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  fetch: (page) async {
                    final res = await api.bookings(tab: tab, page: page);
                    return (items: res.items, totalPages: res.totalPages);
                  },
                  itemBuilder: (_, b) => tab == 'ONGOING' ? OngoingCard(booking: b) : TripBookingCard(booking: b, tab: tab),
                  empty: EmptyView(
                    title: _empty[tab]!.$1,
                    message: _empty[tab]!.$2,
                    icon: IconsaxPlusLinear.bus,
                    action: tab == 'UPCOMING' ? OutlinedButton(onPressed: () => context.go('/'), style: OutlinedButton.styleFrom(minimumSize: const Size(180, 44)), child: const Text('ابحث عن رحلة')) : null,
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Upcoming / past / cancelled card: carrier, timeline with the bus, seat + reference, actions.
class TripBookingCard extends ConsumerWidget {
  const TripBookingCard({super.key, required this.booking, required this.tab});

  final Booking booking;
  final String tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = booking;
    final trip = b.trip;
    final (label, tone) = bookingChip(b);
    final tickets = b.activeTickets;
    final leg = legLabel(b.leg);
    return ZoolCard(
      onTap: () => context.push('/booking/${b.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CarrierHeader(
            name: trip.carrierName,
            subtitle: trip.legalName,
            logoUrl: trip.logoUrl,
            trailing: Text(shortDay(trip.departureAt), style: const TextStyle(fontSize: 12, color: ZoolColors.textStrong)),
          ),
          const SizedBox(height: 12),
          TripTimeline(trip: trip),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _Fact(icon: IconsaxPlusLinear.ticket_2, label: 'المقعد', value: tickets.isEmpty ? '—' : tickets.map((t) => t.seatLabel).join('، '))),
            Expanded(child: _Fact(icon: IconsaxPlusLinear.receipt_2, label: 'رقم الحجز', value: b.reference)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            StatusBadge(label, tone: tone),
            if (leg != null) StatusBadge(leg, tone: BadgeTone.brand),
            if (b.otherLeg != null && leg == null) const StatusBadge('ذهاب وعودة', tone: BadgeTone.brand),
          ]),
          const SizedBox(height: 12),
          _Actions(booking: b, tab: tab),
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.booking, required this.tab});

  final Booking booking;
  final String tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = booking;
    final tickets = b.activeTickets;
    if (tab == 'CANCELLED') {
      final refund = b.refunds.isEmpty ? null : b.refunds.first;
      return refund == null
          ? const SizedBox.shrink()
          : Text(
              'استرداد ${formatSdg(refund.integer('amountMinor'))} · ${refund.str('status') == 'SUCCEEDED' ? 'تم' : 'قيد المعالجة'}',
              style: const TextStyle(fontSize: 12, color: ZoolColors.brand, fontWeight: FontWeight.w600),
            );
    }
    if (tab == 'PAST') {
      return Row(children: [
        if (b.canRate)
          Expanded(
            child: FilledButton.icon(
              onPressed: () => showRatingSheet(context, ref, b),
              icon: const Icon(IconsaxPlusLinear.star_1, size: 18),
              label: const Text('قيّم الرحلة'),
            ),
          )
        else if (b.rating != null)
          Expanded(child: Text('تقييمك: ${'★' * b.rating!.integer('stars')}', style: const TextStyle(color: ZoolColors.warning, fontSize: 14))),
        if (b.canRate || b.rating != null) const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(IconsaxPlusLinear.repeat, size: 18),
            label: const Text('احجز مجددًا'),
          ),
        ),
      ]);
    }
    if (b.canPay) {
      return PrimaryButton(label: 'أكمل الدفع', onPressed: () => context.push('/payment/${b.payment?.str('intentId')}?booking=${b.id}'));
    }
    return Row(children: [
      Expanded(
        child: FilledButton.icon(
          onPressed: tickets.isEmpty
              ? null
              : () => tickets.length == 1
                  ? context.push('/booking/${b.id}/ticket/${Uri.encodeComponent(tickets.first.ticketNumber)}')
                  : context.push('/booking/${b.id}'),
          icon: const Icon(IconsaxPlusLinear.scan_barcode, size: 18),
          label: Text(tickets.length > 1 ? 'عرض التذاكر' : 'عرض التذكرة'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => context.push('/booking/${b.id}'),
          icon: const Icon(IconsaxPlusLinear.edit_2, size: 18),
          label: const Text('تعديل الرحلة'),
        ),
      ),
    ]);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 20, color: ZoolColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: ZoolColors.textMuted)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
            ),
          ]),
        ),
      ]);
}

/// Ongoing card (Figma 3074:3992): «رحلتك جارية الآن», route, next station, ETA, progress, «تتبع الرحلة».
class OngoingCard extends ConsumerWidget {
  const OngoingCard({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveProvider(booking.id)).value;
    final trip = booking.trip;
    final progress = (live?.progressPercent ?? 0).clamp(0, 100);
    return ClipRRect(
      borderRadius: BorderRadius.circular(ZoolRadii.card),
      child: ColoredBox(
        color: Colors.white,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            color: ZoolColors.brand,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: const Row(children: [
              Expanded(child: Text('رحلتك جارية الآن', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
              Icon(IconsaxPlusLinear.radar_2, color: Colors.white, size: 18),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Icon(IconsaxPlusLinear.location, color: ZoolColors.brand),
                const SizedBox(width: 8),
                Text('${trip.origin.city} ← ${trip.destination.city}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              if (live?.nextStopName != null) _Line(icon: IconsaxPlusLinear.routing_2, text: 'المحطة القادمة: ${live!.nextStopName}'),
              if (live?.etaAt != null) _Line(icon: IconsaxPlusLinear.clock, text: 'الوصول المتوقع ${formatTime(live!.etaAt)}${live.delayMinutes > 0 ? ' (تأخير ${live.delayMinutes} د)' : ''}'),
              const SizedBox(height: 10),
              Row(children: [
                const Expanded(child: Text('التقدم في الرحلة', style: TextStyle(fontSize: 12))),
                Text('$progress%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: progress / 100, minHeight: 8, backgroundColor: ZoolColors.divider, color: ZoolColors.primary),
              ),
              const SizedBox(height: 12),
              PrimaryButton(label: 'تتبع الرحلة', icon: IconsaxPlusLinear.location, onPressed: () => context.push('/booking/${booking.id}/live')),
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.push('/booking/${booking.id}'), child: const Text('التذاكر وتفاصيل الحجز')),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: ZoolColors.textMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary))),
        ]),
      );
}
