import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import 'flow.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(widget.isReturn ? 'مقاعد رحلة العودة' : 'اختيار المقاعد')),
      body: AsyncBody(
        value: tripAsync,
        onRetry: () => ref.invalidate(tripProvider(widget.tripId)),
        data: (trip) {
          _seed(trip);
          final layout = trip.layout;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(tripProvider(widget.tripId).future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TripInfo(trip: trip),
                const SizedBox(height: 16),
                Text('اختر $needed ${needed == 1 ? 'مقعدًا' : 'مقاعد'}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('المقاعد بالإطار الوردي مخصّصة للسيدات.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SeatMap(
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
                  ),
                ),
                const SizedBox(height: 12),
                const SeatLegend(),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: tripAsync.value == null
          ? null
          : BottomActionBar(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_selected.length} / $needed مقعد', style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          formatSdg(tripAsync.value!.basePrice * _selected.length),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: ZoolColors.secondary),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: PrimaryButton(
                      label: 'متابعة',
                      busy: _busy,
                      onPressed: _selected.length == needed ? () => _continue(tripAsync.value!) : null,
                    ),
                  ),
                ],
              ),
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

class _TripInfo extends StatelessWidget {
  const _TripInfo({required this.trip});

  final BrokerTrip trip;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final stops = trip.stops;
    return ZoolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(trip.companyName, style: t.titleSmall)),
              if (trip.rating != null) ...[
                const Icon(Icons.star_rounded, color: ZoolColors.warning, size: 18),
                Text(trip.rating!.toStringAsFixed(1), style: t.bodySmall),
                const SizedBox(width: 8),
              ],
              StatusBadge(serviceClass(trip.serviceClass), tone: BadgeTone.brand),
            ],
          ),
          const SizedBox(height: 4),
          Text(formatLongDate(trip.departureAt), style: t.bodySmall),
          const SizedBox(height: 12),
          RouteTimeline(
            departureAt: trip.departureAt,
            arrivalAt: trip.arrivalAt,
            originCity: trip.origin.city,
            destinationCity: trip.destination.city,
            originStation: trip.origin.station,
            destinationStation: trip.destination.station,
            durationMinutes: trip.durationMinutes,
          ),
          if (stops.length > 2)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('المحطات (${stops.length})', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                children: [
                  for (final s in stops)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        s.kind == 'STOP' ? Icons.radio_button_unchecked_rounded : Icons.location_on_rounded,
                        color: ZoolColors.secondary,
                        size: 18,
                      ),
                      title: Text(s.station == null ? s.city : '${s.city} — ${s.station}'),
                      trailing: Text(formatTime(s.scheduledAt), style: t.bodySmall),
                    ),
                ],
              ),
            ),
          if (trip.amenities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final a in trip.amenities) StatusBadge(a.str('nameAr'), tone: BadgeTone.neutral)],
            ),
          ],
          if (trip.vehicleModel != null) ...[
            const SizedBox(height: 8),
            Text('الحافلة: ${trip.vehicleModel}', style: t.bodySmall),
          ],
        ],
      ),
    );
  }
}
