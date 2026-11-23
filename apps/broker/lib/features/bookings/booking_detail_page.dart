import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import 'change_seat_sheet.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(booking.value == null ? 'تفاصيل الحجز' : 'حجز ${booking.value!.reference}')),
      body: AsyncBody(
        value: booking,
        onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        data: (b) => RefreshIndicator(
          onRefresh: () => ref.refresh(bookingProvider(bookingId).future),
          child: _Body(booking: b),
        ),
      ),
      bottomNavigationBar: booking.value != null && booking.value!.canModify && canBook
          ? BottomActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showChangeMenu(context, ref, booking.value!),
                      icon: const Icon(Icons.edit_calendar_rounded),
                      label: const Text('تعديل'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: ZoolColors.error, side: const BorderSide(color: ZoolColors.error)),
                      onPressed: () => _cancel(context, ref, booking.value!),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('إلغاء الحجز'),
                    ),
                  ),
                ],
              ),
            )
          : null,
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
              leading: const Icon(Icons.event_seat_rounded, color: ZoolColors.secondary),
              title: const Text('تغيير المقعد'),
              subtitle: const Text('مقعد آخر في نفس الرحلة، بدون رسوم'),
              onTap: () {
                Navigator.of(ctx).pop();
                showChangeSeatSheet(context, ref, b);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded, color: ZoolColors.secondary),
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
    final t = Theme.of(context).textTheme;
    final (label, tone) = bookingStatus(b.status);
    final leg = legLabel(b.leg);
    final tickets = b.isConfirmed ? b.activeTickets : b.tickets;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ZoolCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('${b.origin} ← ${b.destination}', style: t.titleMedium)),
                  if (leg != null) ...[StatusBadge(leg, tone: BadgeTone.brand), const SizedBox(width: 6)],
                  StatusBadge(label, tone: tone),
                ],
              ),
              const SizedBox(height: 6),
              Text('${formatLongDate(b.departureAt)} · ${formatTime(b.departureAt)}', style: t.bodyMedium),
              Text(b.companyName, style: t.bodySmall),
            ],
          ),
        ),
        if (b.status == 'CHANGED' && b.replacedByBookingId != null) ...[
          const SizedBox(height: 12),
          _LinkCard(
            icon: Icons.info_outline_rounded,
            text: 'تم نقل هذا الحجز إلى رحلة أخرى؛ التذاكر الصالحة في الحجز الجديد.',
            action: 'فتح الحجز الجديد',
            onTap: () => context.pushReplacement('/booking/${b.replacedByBookingId}'),
          ),
        ],
        if (b.groupId != null) _OtherLeg(booking: b),
        const SizedBox(height: 16),
        SectionTitle('التذاكر (${tickets.length})'),
        for (final ticket in tickets) ...[
          Builder(builder: (context) {
            final (bl, bt) = ticket.active ? boardingStatus(ticket.boardingStatus) : ('ملغاة', BadgeTone.error);
            return TicketQrCard(
              ticketNumber: ticket.ticketNumber,
              passengerName: ticket.passengerName,
              seatLabel: ticket.seatLabel,
              qrPayload: b.isConfirmed ? ticket.qrPayload : null,
              statusLabel: bl,
              statusTone: bt,
            );
          }),
          const SizedBox(height: 12),
        ],
        const SectionTitle('الركاب'),
        ZoolCard(
          child: Column(
            children: [
              for (final p in b.passengers)
                InfoRow(
                  p.fullName,
                  [formatPhone(p.phone), if (p.gender == 'FEMALE') 'أنثى' else if (p.gender == 'MALE') 'ذكر'].join(' · '),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionTitle('المبالغ'),
        ZoolCard(
          child: Column(
            children: [
              InfoRow('إجمالي الحجز', formatSdg(b.totalMinor), bold: true),
              InfoRow('العمولة', formatSdg(b.commissionMinor), valueColor: ZoolColors.secondary),
              InfoRow('حالة العمولة', commissionStatus(b.commissionStatus)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionTitle('معلومات أخرى'),
        ZoolCard(
          child: Column(
            children: [
              InfoRow('رقم الحجز', b.reference),
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
        icon: Icons.sync_alt_rounded,
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
