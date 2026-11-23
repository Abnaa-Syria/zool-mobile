import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

enum SeatState { available, selected, women, booked }

/// The design's seat (base, back and cushion SVG parts) with its number; colors per state:
/// available #C7C8CF, selected #115233, women-only #7BC4A5, booked #EDEDEF.
class SeatIcon extends StatelessWidget {
  const SeatIcon({super.key, required this.state, this.label, this.width = 40});

  final SeatState state;
  final String? label;
  final double width;

  static Color colorOf(SeatState s) => switch (s) {
        SeatState.available => ZoolColors.border,
        SeatState.selected => ZoolColors.brand,
        SeatState.women => ZoolColors.women,
        SeatState.booked => ZoolColors.divider,
      };

  @override
  Widget build(BuildContext context) {
    final w = width, h = width * 1.3;
    final filter = ColorFilter.mode(colorOf(state), BlendMode.srcIn);
    Widget part(String name, {required double left, required double top, required double right, required double bottom}) => Positioned(
          left: w * left,
          top: h * top,
          right: w * right,
          bottom: h * bottom,
          child: SvgPicture.asset('assets/icons/$name.svg', package: 'zool_ui', fit: BoxFit.fill, colorFilter: filter),
        );
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          // Insets from the Figma seat component (Isolation_Mode 40×52).
          part('seat_base', left: 0, top: 0.8176, right: 0, bottom: 0),
          part('seat_back', left: 0.1127, top: 0, right: 0.1126, bottom: 0.2269),
          part('seat_cushion', left: 0.2892, top: 0.3634, right: 0.2911, bottom: 0.2269),
          if (label != null)
            Positioned(
              left: 0,
              right: 0,
              top: h * 0.40,
              child: Text(
                label!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: w * 0.3,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: state == SeatState.booked ? ZoolColors.border : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bus seat map from the design: «السائق» at the front, pairs of seats with the aisle between
/// them. Columns follow the vehicle layout (column 1 on the left). Without a layout (legacy
/// trips) the seats are laid out in rows of four.
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
    final rows = placed ? _grid(spec) : _fallback();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(
            child: Text('السائق', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
          ),
          const SizedBox(height: 16),
          for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 8), child: r),
        ],
      ),
    );
  }

  List<Widget> _grid(SeatLayoutSpec spec) {
    final byPos = {for (final s in seats) '${s.row}:${s.column}': s};
    final aisle = spec.aisleAfterColumn;
    return [
      for (var r = 1; r <= spec.rows; r++)
        Row(
          children: [
            for (var c = 1; c <= spec.columns; c++) ...[
              _slot(byPos['$r:$c']),
              if (c == aisle) const Spacer() else if (c < spec.columns) const SizedBox(width: 12),
            ],
          ],
        ),
    ];
  }

  List<Widget> _fallback() {
    final out = <Widget>[];
    for (var i = 0; i < seats.length; i += 4) {
      final chunk = seats.sublist(i, i + 4 > seats.length ? seats.length : i + 4);
      out.add(Row(
        children: [
          for (var j = 0; j < chunk.length; j++) ...[
            _slot(chunk[j]),
            if (j == 1) const Spacer() else if (j < chunk.length - 1) const SizedBox(width: 12),
          ],
        ],
      ));
    }
    return out;
  }

  Widget _slot(SeatCell? seat) {
    if (seat == null) return const SizedBox(width: 40, height: 52);
    final isSelected = selected.contains(seat.id);
    final state = isSelected
        ? SeatState.selected
        : !seat.available
            ? SeatState.booked
            : seat.womenOnly
                ? SeatState.women
                : SeatState.available;
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: seat.available || isSelected,
      label: 'مقعد ${seat.label}${seat.womenOnly ? '، للسيدات' : ''}${state == SeatState.booked ? '، محجوز' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: state == SeatState.booked ? null : () => onToggle(seat),
        child: SeatIcon(state: state, label: seat.label),
      ),
    );
  }
}

/// Legend under the map: مختار · متاح · محجوز · مخصص للسيدات.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(String label, SeatState state) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SeatIcon(state: state, width: 18.5),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
          ],
        );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 14,
      runSpacing: 8,
      children: [
        item('مختار', SeatState.selected),
        item('متاح', SeatState.available),
        item('محجوز', SeatState.booked),
        item('مخصص للسيدات', SeatState.women),
      ],
    );
  }
}
