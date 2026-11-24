import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import '../booking/seats_page.dart';
import '../booking/trip_card.dart';
import 'rating_sheet.dart';
import 'share_ticket.dart';

/// One booking: summary, round-trip other leg (C11), tickets with QR / share, cash to pay (C17),
/// pay, change (C13–C15), cancel with the refund (C12), rate.
class BookingPage extends ConsumerWidget {
  const BookingPage({super.key, required this.bookingId});

  final String bookingId;

  Future<void> _cancel(BuildContext context, WidgetRef ref, Booking b) async {
    Json q;
    try {
      q = await ref.read(apiProvider).cancellationQuote(b.id);
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
      return;
    }
    if (!context.mounted) return;
    if (!q.flag('cancellable')) {
      await showInfoDialog(context, title: 'لا يمكن الإلغاء', message: 'انتهى الموعد المسموح لإلغاء هذا الحجز.');
      return;
    }
    final method = switch (q.str('method')) {
      'ORIGINAL_PAYMENT_METHOD' => 'إلى وسيلة الدفع الأصلية',
      'NONE' => '—',
      _ => '',
    };
    final ok = await showConfirmDialog(
      context,
      title: 'إلغاء الحجز ${b.reference}؟',
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (b.isCash && b.paymentStatus != 'PAID')
          const Text('حجزك نقدي ولم يُدفع بعد؛ لا يوجد مبلغ للاسترداد.')
        else ...[
          InfoRow('المبلغ المسترد', formatSdg(q.integer('refundableMinor')), bold: true, valueColor: ZoolColors.brand),
          if (q.integer('feeMinor') > 0) InfoRow('رسوم الإلغاء', formatSdg(q.integer('feeMinor'))),
          if (method.isNotEmpty) InfoRow('طريقة الاسترداد', method),
        ],
        if (q.date('deadline') != null) InfoRow('آخر موعد للإلغاء', formatDateTime(q.date('deadline'))),
        if (q.flag('voidsWholeCheckout')) const Text('سيُلغى حجز الذهاب والعودة معًا.', style: TextStyle(color: ZoolColors.primary, fontSize: 12)),
      ]),
      confirmLabel: 'إلغاء الحجز',
      cancelLabel: 'رجوع',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      final res = await ref.read(apiProvider).cancel(b.id);
      bookingsChanged(ref);
      ref.invalidate(bookingProvider(b.id));
      if (!context.mounted) return;
      final refund = res.objOrNull('refund');
      await showInfoDialog(
        context,
        title: 'تم إلغاء الحجز',
        message: refund == null ? 'أُلغي الحجز.' : 'سيُعاد ${formatSdg(refund.integer('amountMinor'))} إلى وسيلة الدفع الأصلية.',
      );
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  void _modify(BuildContext context, WidgetRef ref, Booking b) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تعديل الرحلة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ListTile(
            enabled: b.canChangeSeat,
            leading: const Icon(IconsaxPlusLinear.ticket_2, color: ZoolColors.brand),
            title: const Text('تغيير المقعد'),
            subtitle: Text(b.canChangeSeat ? 'مقعد آخر في نفس الرحلة، بدون رسوم' : 'غير متاح لهذا الحجز الآن'),
            onTap: () {
              Navigator.of(ctx).pop();
              showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _ChangeSeatSheet(booking: b));
            },
          ),
          ListTile(
            enabled: b.canChangeTrip,
            leading: const Icon(IconsaxPlusLinear.calendar_edit, color: ZoolColors.brand),
            title: const Text('تغيير موعد الرحلة'),
            subtitle: Text(b.canChangeTrip ? 'رحلة أخرى لنفس الشركة والمدينتين مع فرق السعر' : 'غير متاح (قريب من موعد المغادرة أو وصل للحد الأقصى)'),
            onTap: () {
              Navigator.of(ctx).pop();
              context.push('/booking/${b.id}/change-trip');
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider(bookingId));
    final b = booking.value;
    final showActions = b != null && (b.canCancel || b.canChangeSeat || b.canChangeTrip);
    return ZoolPage(
      title: 'تفاصيل الحجز',
      bottomBar: b == null
          ? null
          : b.canPay
              ? ZoolBottomBar(child: PrimaryButton(label: 'أكمل الدفع | ${formatSdg(b.totalMinor)}', onPressed: () => context.push('/payment/${b.payment?.str('intentId')}?booking=${b.id}')))
              : showActions
                  ? ZoolBottomBar(
                      child: Row(children: [
                        if (b.canChangeSeat || b.canChangeTrip)
                          Expanded(
                            child: OutlinedButton.icon(onPressed: () => _modify(context, ref, b), icon: const Icon(IconsaxPlusLinear.edit_2, size: 20), label: const Text('تعديل الرحلة')),
                          ),
                        if ((b.canChangeSeat || b.canChangeTrip) && b.canCancel) const SizedBox(width: 12),
                        if (b.canCancel)
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: ZoolColors.error, side: const BorderSide(color: ZoolColors.error)),
                              onPressed: () => _cancel(context, ref, b),
                              icon: const Icon(IconsaxPlusLinear.close_circle, size: 20),
                              label: const Text('إلغاء الحجز'),
                            ),
                          ),
                      ]),
                    )
                  : null,
      body: AsyncBody(
        value: booking,
        onRetry: () => ref.invalidate(bookingProvider(bookingId)),
        data: (b) => RefreshIndicator(
          color: ZoolColors.brand,
          onRefresh: () => ref.refresh(bookingProvider(bookingId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              TripSummaryCard(trip: b.trip, title: legLabel(b.leg) == null ? null : 'رحلة ${legLabel(b.leg)}'),
              const SizedBox(height: 12),
              ZoolCard(
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Text('رقم الحجز: ${b.reference}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    StatusBadge(bookingChip(b).$1, tone: bookingChip(b).$2),
                  ]),
                  const Divider(height: 18),
                  InfoRow('طريقة الدفع', b.isCash ? 'نقدًا للسائق' : 'دفع إلكتروني'),
                  if (b.discountMinor > 0) InfoRow('الخصم', '-${formatSdg(b.discountMinor)}', valueColor: ZoolColors.primary),
                  InfoRow('الإجمالي', formatSdg(b.totalMinor), large: true, valueColor: ZoolColors.brand),
                ]),
              ),
              if (b.isCash && b.cashToCollectMinor > 0 && b.isConfirmed) ...[
                const SizedBox(height: 12),
                ZoolCard(
                  color: const Color(0xFFFFF4E5),
                  child: Row(children: [
                    const Icon(IconsaxPlusBold.money_3, color: ZoolColors.warning),
                    const SizedBox(width: 10),
                    Expanded(child: Text('ادفع ${formatSdg(b.cashToCollectMinor)} للسائق عند الصعود.', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF9A5B00)))),
                  ]),
                ),
              ],
              if (b.tripCancelled) ...[
                const SizedBox(height: 12),
                const ZoolCard(
                  color: ZoolColors.primarySoft,
                  child: Text('ألغت شركة النقل هذه الرحلة. يُسترد المبلغ تلقائيًا ويمكنك حجز رحلة أخرى.', style: TextStyle(color: ZoolColors.primary)),
                ),
              ],
              if (b.otherLeg != null) ...[
                const SizedBox(height: 12),
                ZoolCard(
                  color: ZoolColors.secondarySoft,
                  onTap: () => context.push('/booking/${b.otherLeg!.str('bookingId')}'),
                  child: Row(children: [
                    const Icon(IconsaxPlusLinear.repeat, color: ZoolColors.brand),
                    const SizedBox(width: 8),
                    Expanded(child: Text('رحلة ${legLabel(b.otherLeg!.strOrNull('leg')) ?? 'أخرى'} في نفس الحجز: ${b.otherLeg!.str('bookingRef')}', style: const TextStyle(fontSize: 13, color: ZoolColors.brand))),
                    const Icon(IconsaxPlusLinear.arrow_left_2, size: 18, color: ZoolColors.brand),
                  ]),
                ),
              ],
              if (b.status == 'CHANGED' && b.replacedByBookingId != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => context.pushReplacement('/booking/${b.replacedByBookingId}'), child: const Text('تم تعديل الحجز — عرض الحجز الجديد')),
              ],
              const SizedBox(height: 16),
              SectionTitle('التذاكر (${b.tickets.length})'),
              for (final t in b.tickets) ...[
                _TicketRow(booking: b, ticket: t),
                const SizedBox(height: 10),
              ],
              if (b.canRate) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => showRatingSheet(context, ref, b), icon: const Icon(IconsaxPlusLinear.star_1), label: const Text('قيّم الرحلة')),
              ],
              if (b.refunds.isNotEmpty) ...[
                const SizedBox(height: 16),
                const SectionTitle('المبالغ المستردة'),
                ZoolCard(
                  child: Column(children: [
                    for (final r in b.refunds)
                      InfoRow(formatDateTime(r.date('createdAt')), '${formatSdg(r.integer('amountMinor'))} · ${r.str('status') == 'SUCCEEDED' ? 'تم' : 'قيد المعالجة'}'),
                  ]),
                ),
              ],
              if (b.trip.status == 'BOARDING' || b.trip.status == 'IN_PROGRESS') ...[
                const SizedBox(height: 12),
                PrimaryButton(label: 'تتبع الرحلة', icon: IconsaxPlusLinear.location, onPressed: () => context.push('/booking/${b.id}/live')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketRow extends ConsumerWidget {
  const _TicketRow({required this.booking, required this.ticket});

  final Booking booking;
  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (label, tone) = ticketChip(booking, ticket);
    final usable = booking.isConfirmed && ticket.active && ticket.qrPayload != null;
    return ZoolCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ticket.passengerName, style: const TextStyle(fontSize: 14, color: ZoolColors.textStrong)),
              Text('مقعد ${ticket.seatLabel}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ZoolColors.textStrong)),
            ]),
          ),
          StatusBadge(label, tone: tone),
        ]),
        if (usable) ...[
          const Divider(height: 22),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push('/booking/${booking.id}/ticket/${Uri.encodeComponent(ticket.ticketNumber)}'),
                icon: const Icon(IconsaxPlusLinear.scan_barcode, size: 18),
                label: const Text('عرض التذكرة'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => shareTicket(context, ref, booking, ticket),
                icon: const Icon(IconsaxPlusLinear.export_1, size: 18),
                label: const Text('مشاركة'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

/// C14 — another seat on the same trip.
class _ChangeSeatSheet extends ConsumerStatefulWidget {
  const _ChangeSeatSheet({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_ChangeSeatSheet> createState() => _ChangeSeatSheetState();
}

class _ChangeSeatSheetState extends ConsumerState<_ChangeSeatSheet> {
  late Ticket _ticket = widget.booking.activeTickets.first;
  Seat? _target;
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).changeSeat(widget.booking.id, from: _ticket.seatLabel, to: _target!.label);
      ref.invalidate(bookingProvider(widget.booking.id));
      bookingsChanged(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessageSnack(context, 'تم نقلك إلى المقعد ${_target!.label}');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
      ref.invalidate(seatsProvider(widget.booking.trip.id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seats = ref.watch(seatsProvider(widget.booking.trip.id));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(children: [
        const Text('تغيير المقعد', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        Expanded(
          child: AsyncBody(
            value: seats,
            onRetry: () => ref.invalidate(seatsProvider(widget.booking.trip.id)),
            data: (data) => ListView(padding: const EdgeInsets.all(16), children: [
              if (widget.booking.activeTickets.length > 1) ...[
                const Text('المسافر', style: TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in widget.booking.activeTickets)
                    ChoiceChip(label: Text('${t.passengerName} · ${t.seatLabel}'), selected: t.ticketNumber == _ticket.ticketNumber, onSelected: (_) => setState(() => _ticket = t)),
                ]),
                const SizedBox(height: 16),
              ],
              CustomerSeatMap(
                data: data,
                selected: {?_target?.id},
                onToggle: (s) => setState(() => _target = s.label == _ticket.seatLabel || !s.available ? null : (_target?.id == s.id ? null : s)),
              ),
            ]),
          ),
        ),
        BottomActionBar(
          child: PrimaryButton(
            label: _target == null ? 'اختر المقعد الجديد' : 'نقل من ${_ticket.seatLabel} إلى ${_target!.label}',
            busy: _busy,
            onPressed: _target == null ? null : _save,
          ),
        ),
      ]),
    );
  }
}
