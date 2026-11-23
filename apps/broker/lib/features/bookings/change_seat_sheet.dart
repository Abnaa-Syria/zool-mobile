import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// Seat map of a broker trip (used by change seat and change trip).
class TripSeatMap extends StatelessWidget {
  const TripSeatMap({super.key, required this.trip, required this.selected, required this.onToggle});

  final BrokerTrip trip;
  final Set<String> selected;
  final ValueChanged<TripSeat> onToggle;

  @override
  Widget build(BuildContext context) {
    final layout = trip.layout;
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SeatMap(
            seats: [
              for (final s in trip.seats)
                SeatCell(id: s.id, label: s.label, available: s.status == 'FREE', row: s.row, column: s.column, womenOnly: s.womenOnly),
            ],
            layout: layout == null
                ? null
                : SeatLayoutSpec(
                    rows: layout.integer('rows'),
                    columns: layout.integer('columns'),
                    aisleAfterColumn: layout.integer('aisleAfterColumn'),
                    driverSide: layout.str('driverSide', 'LEFT'),
                  ),
            selected: selected,
            onToggle: (cell) => onToggle(trip.seats.firstWhere((s) => s.id == cell.id)),
          ),
        ),
        const SizedBox(height: 10),
        const SeatLegend(),
      ],
    );
  }
}

/// B5 — change one passenger's seat on the same trip (free of charge).
Future<void> showChangeSeatSheet(BuildContext context, WidgetRef ref, Booking booking) {
  ref.invalidate(tripProvider(booking.tripId));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ChangeSeatSheet(booking: booking),
  );
}

class _ChangeSeatSheet extends ConsumerStatefulWidget {
  const _ChangeSeatSheet({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_ChangeSeatSheet> createState() => _ChangeSeatSheetState();
}

class _ChangeSeatSheetState extends ConsumerState<_ChangeSeatSheet> {
  late BookingTicket _ticket = widget.booking.activeTickets.first;
  TripSeat? _target;
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).changeSeat(widget.booking.id, fromSeatLabel: _ticket.seatLabel, toSeatLabel: _target!.label);
      ref.invalidate(bookingProvider(widget.booking.id));
      ref.read(bookingsVersionProvider.notifier).state++;
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessageSnack(context, 'تم نقل ${_ticket.passengerName} إلى المقعد ${_target!.label}');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
      ref.invalidate(tripProvider(widget.booking.tripId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.booking.tripId));
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          Text('تغيير المقعد', style: t.titleMedium),
          Expanded(
            child: AsyncBody(
              value: trip,
              onRetry: () => ref.invalidate(tripProvider(widget.booking.tripId)),
              data: (trip) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('الراكب', style: t.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tk in widget.booking.activeTickets)
                        ChoiceChip(
                          label: Text('${tk.passengerName} · ${tk.seatLabel}'),
                          selected: tk.ticketNumber == _ticket.ticketNumber,
                          onSelected: (_) => setState(() => _ticket = tk),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('المقعد الجديد', style: t.bodySmall),
                  const SizedBox(height: 8),
                  Center(
                    child: TripSeatMap(
                      trip: trip,
                      selected: {?_target?.id},
                      onToggle: (s) => setState(() => _target = _target?.id == s.id ? null : s),
                    ),
                  ),
                ],
              ),
            ),
          ),
          BottomActionBar(
            child: PrimaryButton(
              label: _target == null ? 'اختر المقعد الجديد' : 'نقل من ${_ticket.seatLabel} إلى ${_target!.label}',
              busy: _busy,
              onPressed: _target == null ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}
