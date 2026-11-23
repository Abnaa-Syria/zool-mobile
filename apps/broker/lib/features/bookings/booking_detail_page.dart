import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import 'booking_tile.dart';
import 'change_seat_sheet.dart';
import 'share_ticket.dart';

final _groupProvider = FutureProvider.autoDispose.family<List<Booking>, String>((ref, groupId) => ref.watch(apiProvider).bookingGroup(groupId));

/// Booking details (3086:2544) + tickets with QR (3083:2743), cancel (B4) and change (B5).
class BookingDetailPage extends ConsumerWidget {
  const BookingDetailPage({super.key, required this.bookingId});

  final String bookingId;

  Future<void> _cancel(BuildContext context, WidgetRef ref, Booking b) async {
    final ok = await showConfirmDialog(
      context,
      title: 'إلغاء الحجز ${b.reference}',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سيُلغى الحجز وكل تذاكره، ويعود مبلغه إلى محفظة المكتب وتُسترد عمولته.'),
          const SizedBox(height: 12),
          InfoRow('مبلغ الحجز', formatSdg(b.totalMinor)),
          InfoRow('العمولة المستردة', formatSdg(b.commissionMinor)),
        ],
      ),
      confirmLabel: 'إلغاء الحجز',
      cancelLabel: 'رجوع',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      final res = await ref.read(apiProvider).cancel(b.id);
      refreshMoney(ref);
      ref.invalidate(bookingProvider(b.id));
      if (!context.mounted) return;
      await showInfoDialog(
        context,
        title: 'تم إلغاء الحجز',
        message: 'أُعيد ${formatSdg(res.integer('refundedAmountMinor'))} إلى المحفظة، واستُردت عمولة ${formatSdg(res.integer('commissionClawedBackMinor'))}. '
            'الرصيد الآن ${formatSdg(res.integer('balanceAfterMinor'))}.',
      );
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    final canBook = ref.watch(meProvider).value?.canBook ?? false;
    final b = booking.value;
    return ZoolPage(
      title: 'تفاصيل الحجز والمسافرين',
      action: b != null && b.isConfirmed
          ? RoundIconButton(icon: IconsaxPlusLinear.export_1, tooltip: 'إرسال كل التذاكر', onTap: () => shareBookingTickets(context, ref, b))
          : null,
      bottomBar: b != null && b.canModify && canBook
          ? ZoolBottomBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showChangeMenu(context, ref, b),
                      icon: const Icon(IconsaxPlusLinear.edit_2, size: 20),
                      label: const Text('تعديل الحجز'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: ZoolColors.error, side: const BorderSide(color: ZoolColors.error)),
                      onPressed: () => _cancel(context, ref, b),
                      icon: const Icon(IconsaxPlusLinear.close_circle, size: 20),
                      label: const Text('إلغاء الحجز'),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: AsyncBody(
        value: booking,
        onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        data: (b) => RefreshIndicator(
          color: ZoolColors.brand,
          onRefresh: () => ref.refresh(bookingProvider(bookingId).future),
          child: _Body(booking: b),
        ),
      ),
    );
  }

  void _showChangeMenu(BuildContext context, WidgetRef ref, Booking b) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تعديل الحجز', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.ticket, color: ZoolColors.secondary),
              title: const Text('تغيير المقعد'),
              subtitle: const Text('مقعد آخر في نفس الرحلة، بدون رسوم'),
              onTap: () {
                Navigator.of(ctx).pop();
                showChangeSeatSheet(context, ref, b);
              },
            ),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.repeat, color: ZoolColors.secondary),
              title: const Text('تغيير موعد الرحلة'),
              subtitle: const Text('رحلة أخرى لنفس الشركة والمدينتين، مع فرق السعر'),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push('/booking/${b.id}/change-trip');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = booking;
    final (label, tone) = bookingChip(b);
    final leg = legLabel(b.leg);
    final tickets = b.isConfirmed ? b.activeTickets : b.tickets;
    final seats = b.activeTickets.map((t) => t.seatLabel).join(', ');
    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 110, child: Text(l, style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted))),
              Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ZoolColors.textStrong))),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ZoolCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(b.companyName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ZoolColors.brand))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: ZoolColors.secondarySoft, borderRadius: BorderRadius.circular(8)),
                    child: Text('رقم الحجز: #${b.reference}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ZoolColors.brand)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [StatusBadge(label, tone: tone), if (leg != null) StatusBadge(leg, tone: BadgeTone.brand)]),
              const SizedBox(height: 8),
              row('خط الرحلة:', '${b.origin} ← ${b.destination}'),
              row('تاريخ المغادرة:', '${shortDate(b.departureAt)} · ${formatTime(b.departureAt)}'),
              if (seats.isNotEmpty) row('المقاعد المحجوزة:', '${seatsLabel(b.activeTickets.length)} ($seats)'),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text('عمولتك المحسوبة: ${formatSdg(b.commissionMinor)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ZoolColors.brand)),
                  ),
                  MoneyText(formatSdg(b.totalMinor), size: 20, color: ZoolColors.primary),
                ],
              ),
            ],
          ),
        ),
        if (b.status == 'CHANGED' && b.replacedByBookingId != null) ...[
          const SizedBox(height: 12),
          _LinkCard(
            icon: IconsaxPlusLinear.info_circle,
            text: 'تم نقل هذا الحجز إلى رحلة أخرى؛ التذاكر الصالحة في الحجز الجديد.',
            action: 'فتح الحجز الجديد',
            onTap: () => context.pushReplacement('/booking/${b.replacedByBookingId}'),
          ),
        ],
        if (b.groupId != null) _OtherLeg(booking: b),
        const SizedBox(height: 20),
        SectionTitle('قائمة المسافرين (${tickets.length})'),
        for (final ticket in tickets) ...[
          _PassengerTicket(booking: b, ticket: ticket),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        const SectionTitle('تفاصيل إضافية'),
        ZoolCard(
          child: Column(
            children: [
              for (final p in b.passengers)
                InfoRow(p.fullName, [formatPhone(p.phone), if (p.gender == 'FEMALE') 'أنثى' else if (p.gender == 'MALE') 'ذكر'].join(' · ')),
              const Divider(height: 16),
              InfoRow('حالة العمولة', commissionStatus(b.commissionStatus)),
              if (b.employeeName != null) InfoRow('الموظف', b.employeeName!),
              InfoRow('تاريخ الحجز', formatDateTime(b.createdAt)),
              if (b.cancelledAt != null) InfoRow('تاريخ الإلغاء', formatDateTime(b.cancelledAt)),
              if (b.changeCount > 0) InfoRow('عدد التعديلات', '${b.changeCount}'),
            ],
          ),
        ),
        if (b.replacesBookingId != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: () => context.push('/booking/${b.replacesBookingId}'), child: const Text('عرض الحجز الأصلي قبل التعديل')),
        ],
      ],
    );
  }
}

/// Passenger card: name, seat, boarding state, «عرض رمز QR» and «إرسال التذكرة».
class _PassengerTicket extends ConsumerWidget {
  const _PassengerTicket({required this.booking, required this.ticket});

  final Booking booking;
  final BookingTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (bl, bt) = ticket.active ? boardingStatus(ticket.boardingStatus) : ('ملغاة', BadgeTone.error);
    final usable = booking.isConfirmed && ticket.active;
    return ZoolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ticket.passengerName, style: const TextStyle(fontSize: 14, color: ZoolColors.textStrong)),
                    Text('مقعد ${ticket.seatLabel}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ZoolColors.textStrong)),
                  ],
                ),
              ),
              StatusBadge(bl, tone: bt),
            ],
          ),
          if (usable) ...[
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/booking/${booking.id}/ticket/${Uri.encodeComponent(ticket.ticketNumber)}'),
                    icon: const Icon(IconsaxPlusLinear.scan_barcode, size: 18),
                    label: const Text('عرض رمز QR'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => shareTicket(context, ref, booking, ticket),
                    icon: const Icon(IconsaxPlusLinear.export_1, size: 18),
                    label: const Text('إرسال التذكرة', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OtherLeg extends ConsumerWidget {
  const _OtherLeg({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(_groupProvider(booking.groupId!)).value ?? const [];
    final others = group.where((g) => g.id != booking.id).toList();
    if (others.isEmpty) return const SizedBox.shrink();
    final other = others.first;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _LinkCard(
        icon: IconsaxPlusLinear.repeat,
        text: 'رحلة ${legLabel(other.leg) ?? 'أخرى'}: ${other.origin} ← ${other.destination} · ${formatDateTime(other.departureAt)}',
        action: 'فتح',
        onTap: () => context.push('/booking/${other.id}'),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.icon, required this.text, required this.action, required this.onTap});

  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ZoolCard(
      color: ZoolColors.secondarySoft,
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Row(
        children: [
          Icon(icon, color: ZoolColors.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ZoolColors.secondary))),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}
