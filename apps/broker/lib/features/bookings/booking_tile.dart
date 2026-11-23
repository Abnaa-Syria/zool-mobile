import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../data/models.dart';
import 'share_ticket.dart';

/// Status chip of a booking card: cancelled / changed, else the boarding state of its tickets.
(String, BadgeTone) bookingChip(Booking b) {
  if (!b.isConfirmed) return bookingStatus(b.status);
  final active = b.activeTickets;
  if (active.isNotEmpty && active.every((t) => t.boardingStatus == 'BOARDED')) return ('مؤكدة الصعود', BadgeTone.success);
  if (active.any((t) => t.boardingStatus == 'NO_SHOW')) return ('لم يحضر', BadgeTone.error);
  if (b.departed) return ('انطلقت', BadgeTone.info);
  return ('بانتظار الصعود', BadgeTone.warning);
}

/// Booking card (Figma 3083:1927): carrier, status, passenger, route, departure, price,
/// commission, «عرض التذكرة» and share.
class BookingTile extends ConsumerWidget {
  const BookingTile({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = booking;
    final (label, tone) = bookingChip(b);
    final leg = legLabel(b.leg);
    final passengers = b.passengers;
    final who = passengers.isEmpty ? '—' : (passengers.length == 1 ? passengers.first.fullName : '${passengers.first.fullName} +${passengers.length - 1}');
    final tickets = b.activeTickets;
    Widget row(String l, String v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(width: 92, child: Text(l, style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted))),
              Expanded(
                child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: ZoolColors.textStrong)),
              ),
            ],
          ),
        );
    return ZoolCard(
      onTap: () => context.push('/booking/${b.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(b.companyName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.brand))),
              if (leg != null) ...[StatusBadge(leg, tone: BadgeTone.brand), const SizedBox(width: 6)],
              StatusBadge(label, tone: tone),
            ],
          ),
          const Divider(height: 20),
          row('اسم المسافر:', who, bold: true),
          row('خط الرحلة:', '${b.origin} ← ${b.destination}'),
          row('تاريخ المغادرة:', '${shortDate(b.departureAt)} · ${formatTime(b.departureAt)}'),
          const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MoneyText(formatSdg(b.totalMinor), size: 18, color: b.status == 'CANCELLED' ? ZoolColors.textMuted : ZoolColors.primary),
                    Text('عمولتك المحسوبة: ${formatSdg(b.commissionMinor)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ZoolColors.brand)),
                  ],
                ),
              ),
              if (b.isConfirmed && tickets.isNotEmpty) ...[
                _SquareButton(
                  icon: IconsaxPlusLinear.export_1,
                  tooltip: 'إرسال التذكرة',
                  onTap: () => shareTicket(context, ref, b, tickets.first),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ZoolColors.brand,
                      minimumSize: const Size(110, 40),
                      textStyle: zoolText(13, weight: FontWeight.w700),
                    ),
                    onPressed: () => tickets.length == 1
                        ? context.push('/booking/${b.id}/ticket/${Uri.encodeComponent(tickets.first.ticketNumber)}')
                        : context.push('/booking/${b.id}'),
                    child: Text(tickets.length == 1 ? 'عرض التذكرة' : 'عرض التذاكر'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(side: const BorderSide(color: ZoolColors.border), borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: ZoolColors.textStrong)),
        ),
      ),
    );
  }
}

/// "الخميس، 15 مايو"
String shortDate(DateTime? instant) {
  if (instant == null) return '—';
  final d = toSudan(instant);
  return '${kArabicWeekdays[d.weekday - 1]}، ${d.day} ${kArabicMonths[d.month - 1]}';
}
