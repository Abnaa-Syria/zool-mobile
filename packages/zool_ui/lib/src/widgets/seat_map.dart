import 'package:flutter/material.dart';

import '../theme.dart';

/// One seat as the seat map draws it (built from the API's seat objects by each app).
class SeatCell {
  const SeatCell({
    required this.id,
    required this.label,
    required this.available,
    this.row,
    this.column,
    this.womenOnly = false,
  });

  final String id;
  final String label;

  /// Free, or held by me (can be picked).
  final bool available;
  final int? row;
  final int? column;
  final bool womenOnly;
}

/// Vehicle grid (`layout: { rows, columns, aisleAfterColumn, driverSide }`).
class SeatLayoutSpec {
  const SeatLayoutSpec({required this.rows, required this.columns, this.aisleAfterColumn = 0, this.driverSide = 'LEFT'});

  final int rows;
  final int columns;
  final int aisleAfterColumn;
  final String driverSide;
}

/// Bus seat map. Columns are drawn physically (column 1 on the left, as the vehicle layout is
/// defined), the aisle after [SeatLayoutSpec.aisleAfterColumn], the driver at the front.
/// Without a layout (legacy trips) the seats are laid out in rows of four.
class SeatMap extends StatelessWidget {
  const SeatMap({
    super.key,
    required this.seats,
    required this.selected,
    required this.onToggle,
    this.layout,
  });

  final List<SeatCell> seats;
  final SeatLayoutSpec? layout;
  final Set<String> selected;
  final ValueChanged<SeatCell> onToggle;

  @override
  Widget build(BuildContext context) {
    final spec = layout;
    final placed = spec != null && seats.every((s) => s.row != null && s.column != null);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ZoolColors.border),
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DriverRow(driverOnRight: spec?.driverSide == 'RIGHT'),
              const SizedBox(height: 12),
              if (placed) ..._grid(spec) else ..._fallback(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _grid(SeatLayoutSpec spec) {
    final byPos = {for (final s in seats) '${s.row}:${s.column}': s};
    return [
      for (var r = 1; r <= spec.rows; r++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var c = 1; c <= spec.columns; c++) ...[
                _slot(byPos['$r:$c']),
                if (c == spec.aisleAfterColumn) const SizedBox(width: 26),
              ],
            ],
          ),
        ),
    ];
  }

  List<Widget> _fallback() {
    final rows = <Widget>[];
    for (var i = 0; i < seats.length; i += 4) {
      final chunk = seats.sublist(i, i + 4 > seats.length ? seats.length : i + 4);
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var j = 0; j < chunk.length; j++) ...[_slot(chunk[j]), if (j == 1) const SizedBox(width: 26)],
          ],
        ),
      ));
    }
    return rows;
  }

  Widget _slot(SeatCell? seat) {
    if (seat == null) return const SizedBox(width: 50, height: 46);
    return _SeatTile(seat: seat, selected: selected.contains(seat.id), onTap: () => onToggle(seat));
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.driverOnRight});

  final bool driverOnRight;

  @override
  Widget build(BuildContext context) {
    final wheel = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: ZoolColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.airline_seat_recline_normal_rounded, color: ZoolColors.textMuted),
    );
    return Row(
      mainAxisAlignment: driverOnRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: wheel)],
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, required this.selected, required this.onTap});

  final SeatCell seat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final taken = !seat.available && !selected;
    final bg = selected ? ZoolColors.secondary : (taken ? ZoolColors.divider : Colors.white);
    final fg = selected ? Colors.white : (taken ? ZoolColors.textMuted : ZoolColors.text);
    final border = seat.womenOnly ? ZoolColors.women : (selected ? ZoolColors.secondary : ZoolColors.border);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: !taken,
        label: 'مقعد ${seat.label}${seat.womenOnly ? '، للسيدات' : ''}${taken ? '، محجوز' : ''}',
        child: InkWell(
          onTap: taken ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: seat.womenOnly ? 2 : 1),
            ),
            child: taken
                ? Icon(Icons.person_rounded, size: 20, color: fg)
                : Text(seat.label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

/// Legend under the seat map.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(String label, Color bg, Color border, {double width = 1}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5), border: Border.all(color: border, width: width)),
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        item('متاح', Colors.white, ZoolColors.border),
        item('محدد', ZoolColors.secondary, ZoolColors.secondary),
        item('محجوز', ZoolColors.divider, ZoolColors.divider),
        item('للسيدات', Colors.white, ZoolColors.women, width: 2),
      ],
    );
  }
}
