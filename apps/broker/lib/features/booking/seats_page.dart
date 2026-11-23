import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import 'flow.dart';
import 'trip_card.dart';

/// Trip detail (3083:2246) + seat selection (3083:2396): pick one seat per passenger, then hold
/// them (POST /broker/trips/:id/holds) before passengers / the return leg.
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

  void _seed(BrokerTrip trip) {
    if (_seeded) return;
    _seeded = true;
    final flow = ref.read(bookingFlowProvider);
    final leg = widget.isReturn ? flow.inbound : flow.outbound;
    if (leg != null && leg.trip.id == trip.id) {
      final mine = trip.seats.where((s) => s.heldByMe).map((s) => s.id).toSet();
      _selected.addAll(leg.seatIds.where(mine.contains));
    }
  }

  void _toggle(TripSeat seat, int needed) {
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

  Future<void> _continue(BrokerTrip trip) async {
    final flow = ref.read(bookingFlowProvider);
    final seats = trip.seats.where((s) => _selected.contains(s.id)).toList()..sort((a, b) => _labelOrder(a.label, b.label));
    final previous = widget.isReturn ? flow.inbound : flow.outbound;
    void next() {
      if (flow.roundTrip && !widget.isReturn) {
        context.push('/book/results/return');
      } else {
        context.push('/book/passengers');
      }
    }

    // Same seats still held: nothing to do (holds accept FREE seats only).
    if (previous != null &&
        previous.trip.id == trip.id &&
        previous.expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 20))) &&
        previous.seatIds.toSet().containsAll(_selected) &&
        previous.seatIds.length == _selected.length) {
      return next();
    }
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      if (previous != null) await api.releaseHolds(previous.holdIds);
      final hold = await api.hold(trip.id, seats.map((s) => s.id).toList());
      ref.read(bookingFlowProvider.notifier).setLeg(
            isReturn: widget.isReturn,
            selection: LegSelection(trip: trip, seats: seats, holdIds: hold.holdIds, expiresAt: hold.expiresAt),
          );
      if (!mounted) return;
      next();
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
      if (e.code == 'SEAT_UNAVAILABLE') {
        _selected.clear();
        ref.invalidate(tripProvider(widget.tripId));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripProvider(widget.tripId));
    final needed = ref.watch(bookingFlowProvider.select((s) => s.passengerCount));
    final trip = tripAsync.value;
    return ZoolPage(
      title: widget.isReturn ? 'مقاعد رحلة العودة' : 'اختيار مقعدك',
      bottomBar: trip == null
          ? null
          : ZoolBottomBar(
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MoneyText(formatSdg(trip.basePrice * (_selected.isEmpty ? 1 : _selected.length)), size: 22),
                      Text(
                        _selected.length <= 1 ? 'للمسافر الواحد' : 'لـ ${_selected.length} مقاعد',
                        style: const TextStyle(fontSize: 12, color: ZoolColors.navInactive),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrimaryButton(
                      label: _selected.length == needed ? 'متابعة' : 'اختر ${needed - _selected.length} مقعد',
                      busy: _busy,
                      onPressed: _selected.length == needed ? () => _continue(trip) : null,
                    ),
                  ),
                ],
              ),
            ),
      body: AsyncBody(
        value: tripAsync,
        onRetry: () => ref.invalidate(tripProvider(widget.tripId)),
        data: (trip) {
          _seed(trip);
          final layout = trip.layout;
          return RefreshIndicator(
            color: ZoolColors.brand,
            onRefresh: () => ref.refresh(tripProvider(widget.tripId).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                TripSummaryCard(trip: trip),
                const SizedBox(height: 20),
                SeatMap(
                  seats: [
                    for (final s in trip.seats)
                      SeatCell(id: s.id, label: s.label, available: s.available, row: s.row, column: s.column, womenOnly: s.womenOnly),
                  ],
                  layout: layout == null
                      ? null
                      : SeatLayoutSpec(
                          rows: layout.integer('rows'),
                          columns: layout.integer('columns'),
                          aisleAfterColumn: layout.integer('aisleAfterColumn'),
                          driverSide: layout.str('driverSide', 'LEFT'),
                        ),
                  selected: _selected,
                  onToggle: (cell) => _toggle(trip.seats.firstWhere((s) => s.id == cell.id), needed),
                ),
                const SizedBox(height: 8),
                const SeatLegend(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Natural seat order: "2" < "10", "A2" < "A10".
int _labelOrder(String a, String b) {
  final na = int.tryParse(a.replaceAll(RegExp(r'\D'), ''));
  final nb = int.tryParse(b.replaceAll(RegExp(r'\D'), ''));
  final pa = a.replaceAll(RegExp(r'\d'), ''), pb = b.replaceAll(RegExp(r'\d'), '');
  if (pa != pb) return pa.compareTo(pb);
  if (na != null && nb != null) return na.compareTo(nb);
  return a.compareTo(b);
}

/// Compact white trip card (carrier, date, timeline) used above the seat map and in the review.
class TripSummaryCard extends StatelessWidget {
  const TripSummaryCard({super.key, required this.trip, this.title});

  final BrokerTrip trip;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return ZoolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ZoolColors.brand)),
            const SizedBox(height: 8),
          ],
          CarrierHeader(
            name: trip.companyName,
            subtitle: trip.legalName,
            logoUrl: trip.logoUrl,
            trailing: Text(shortDay(trip.departureAt), style: const TextStyle(fontSize: 12, color: ZoolColors.textStrong)),
          ),
          const SizedBox(height: 12),
          RouteTimeline(
            departureAt: trip.departureAt,
            arrivalAt: trip.arrivalAt,
            originCity: trip.origin.city,
            destinationCity: trip.destination.city,
            originStation: trip.origin.station,
            destinationStation: trip.destination.station,
            durationMinutes: trip.durationMinutes,
            middleLabel: trip.intermediateStops == 0 ? 'مباشر' : '${trip.intermediateStops} توقف',
          ),
        ],
      ),
    );
  }
}
