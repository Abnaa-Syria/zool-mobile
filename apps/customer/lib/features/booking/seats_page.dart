import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import 'flow.dart';
import 'trip_card.dart';

/// Natural seat order: "2" < "10", "A2" < "A10".
int labelOrder(String a, String b) {
  final na = int.tryParse(a.replaceAll(RegExp(r'\D'), ''));
  final nb = int.tryParse(b.replaceAll(RegExp(r'\D'), ''));
  final pa = a.replaceAll(RegExp(r'\d'), ''), pb = b.replaceAll(RegExp(r'\d'), '');
  if (pa != pb) return pa.compareTo(pb);
  if (na != null && nb != null) return na.compareTo(nb);
  return a.compareTo(b);
}

/// Seat map of a customer trip (also used by «تغيير المقعد»).
class CustomerSeatMap extends StatelessWidget {
  const CustomerSeatMap({super.key, required this.data, required this.selected, required this.onToggle, this.mine = const {}});

  final SeatMapData data;
  final Set<String> selected;
  final ValueChanged<Seat> onToggle;

  /// Labels this customer already sits in (shown as available while changing a seat).
  final Set<String> mine;

  @override
  Widget build(BuildContext context) {
    final layout = data.layout;
    final seats = data.seats;
    return Column(children: [
      SeatMap(
        seats: [
          for (final s in seats)
            SeatCell(id: s.id, label: s.label, available: s.available || mine.contains(s.label), row: s.row, column: s.column, womenOnly: s.womenOnly),
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
        onToggle: (cell) => onToggle(seats.firstWhere((s) => s.id == cell.id)),
      ),
      const SizedBox(height: 8),
      const SeatLegend(),
    ]);
  }
}

/// Seat selection (Figma 3074:3265) + «المقعد غير متاح» (3074:4249): pick one seat per traveller,
/// hold them (`POST /customer/trips/:id/holds { seatLabels }`), then the return leg or passengers.
class SeatsPage extends ConsumerStatefulWidget {
  const SeatsPage({super.key, required this.tripId, required this.isReturn});

  final String tripId;
  final bool isReturn;

  @override
  ConsumerState<SeatsPage> createState() => _SeatsPageState();
}

class _SeatsPageState extends ConsumerState<SeatsPage> {
  final Set<String> _selected = {};
  bool _busy = false;
  bool _seeded = false;

  void _seed(SeatMapData data) {
    if (_seeded) return;
    _seeded = true;
    final flow = ref.read(bookingFlowProvider);
    final leg = widget.isReturn ? flow.inbound : flow.outbound;
    if (leg != null && leg.trip.id == widget.tripId) {
      final mine = data.seats.where((s) => s.heldByMe).map((s) => s.id).toSet();
      _selected.addAll(leg.seats.map((s) => s.id).where(mine.contains));
    }
  }

  void _toggle(Seat seat, int needed) {
    setState(() {
      if (_selected.contains(seat.id)) {
        _selected.remove(seat.id);
      } else if (_selected.length < needed) {
        _selected.add(seat.id);
      } else if (needed == 1) {
        _selected
          ..clear()
          ..add(seat.id);
      } else {
        showMessageSnack(context, 'اخترت $needed مقاعد. ألغِ مقعدًا لاختيار غيره.', success: false);
      }
    });
  }

  Future<void> _continue(Trip trip, SeatMapData data) async {
    final flow = ref.read(bookingFlowProvider);
    final seats = data.seats.where((s) => _selected.contains(s.id)).toList()..sort((a, b) => labelOrder(a.label, b.label));
    final previous = widget.isReturn ? flow.inbound : flow.outbound;
    void next() => context.push(flow.roundTrip && !widget.isReturn ? '/results/return' : '/passengers');

    if (previous != null &&
        previous.trip.id == trip.id &&
        previous.expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 20))) &&
        previous.seats.map((s) => s.id).toSet().containsAll(_selected) &&
        previous.seats.length == _selected.length) {
      return next();
    }
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      if (previous != null) await api.releaseHolds(previous.holdIds);
      final hold = await api.hold(trip.id, seats.map((s) => s.label).toList());
      ref.read(bookingFlowProvider.notifier).setLeg(
            isReturn: widget.isReturn,
            selection: LegSelection(trip: trip, seats: seats, holdIds: hold.holdIds, expiresAt: hold.expiresAt),
          );
      if (mounted) next();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'SEAT_UNAVAILABLE') {
        await showInfoDialog(context, title: 'المقعد غير متاح', message: 'تم حجز مقعد أو أكثر من اختيارك قبل قليل. اختر مقعدًا آخر.', button: 'اختيار مقعد آخر');
        _selected.clear();
        ref.invalidate(seatsProvider(widget.tripId));
      } else {
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seats = ref.watch(seatsProvider(widget.tripId));
    final trip = ref.watch(tripProvider(widget.tripId));
    final needed = ref.watch(bookingFlowProvider.select((s) => s.passengerCount));
    final t = trip.value, d = seats.value;
    return ZoolPage(
      title: widget.isReturn ? 'مقاعد رحلة العودة' : 'اختيار مقعدك',
      bottomBar: t == null || d == null
          ? null
          : ZoolBottomBar(
              child: Row(children: [
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  MoneyText(formatSdg(t.priceMinor * (_selected.isEmpty ? 1 : _selected.length)), size: 22),
                  Text(_selected.length <= 1 ? 'للمسافر الواحد' : 'لـ ${seatsLabel(_selected.length)}', style: const TextStyle(fontSize: 12, color: ZoolColors.navInactive)),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: PrimaryButton(
                    label: _selected.length == needed ? 'متابعة' : pickSeatsLabel(needed - _selected.length),
                    busy: _busy,
                    onPressed: _selected.length == needed ? () => _continue(t, d) : null,
                  ),
                ),
              ]),
            ),
      body: AsyncBody(
        value: seats,
        onRetry: () => ref.invalidate(seatsProvider(widget.tripId)),
        data: (data) {
          _seed(data);
          return RefreshIndicator(
            color: ZoolColors.brand,
            onRefresh: () => ref.refresh(seatsProvider(widget.tripId).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (t != null) ...[TripSummaryCard(trip: t), const SizedBox(height: 20)],
                CustomerSeatMap(data: data, selected: _selected, onToggle: (s) => _toggle(s, needed)),
              ],
            ),
          );
        },
      ),
    );
  }
}
