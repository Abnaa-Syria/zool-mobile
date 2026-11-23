import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zool_core/zool_core.dart';

import '../theme.dart';

/// "07:00 ص  ●────── 3 س 45 د ──────●  10:45 ص" with the cities/stations under the times.
class RouteTimeline extends StatelessWidget {
  const RouteTimeline({
    super.key,
    required this.departureAt,
    required this.arrivalAt,
    required this.originCity,
    required this.destinationCity,
    this.originStation,
    this.destinationStation,
    this.durationMinutes,
    this.middleLabel,
  });

  final DateTime? departureAt;
  final DateTime? arrivalAt;
  final String originCity;
  final String destinationCity;
  final String? originStation;
  final String? destinationStation;
  final int? durationMinutes;

  /// Shown under the line (e.g. "مباشر" / "2 توقف").
  final String? middleLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget end(DateTime? time, String city, String? station, CrossAxisAlignment align) => Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: align,
            children: [
              Text(formatTime(time), style: t.titleMedium),
              const SizedBox(height: 2),
              Text(city, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (station != null && station.isNotEmpty)
                Text(station, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        end(departureAt, originCity, originStation, CrossAxisAlignment.start),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              children: [
                Text(formatDuration(durationMinutes), style: t.bodySmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const _Dot(),
                    Expanded(child: Container(height: 1.5, color: ZoolColors.secondary.withValues(alpha: 0.35))),
                    const Icon(Icons.directions_bus_rounded, size: 18, color: ZoolColors.secondary),
                    Expanded(child: Container(height: 1.5, color: ZoolColors.secondary.withValues(alpha: 0.35))),
                    const _Dot(),
                  ],
                ),
                if (middleLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(middleLabel!, style: t.bodySmall),
                ],
              ],
            ),
          ),
        ),
        end(arrivalAt, destinationCity, destinationStation, CrossAxisAlignment.end),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ZoolColors.secondary, width: 2)),
      );
}

/// Seat-hold countdown: "المقاعد محجوزة لك لمدة 04:59". Calls [onExpired] once at zero.
class HoldCountdown extends StatefulWidget {
  const HoldCountdown({super.key, required this.expiresAt, this.onExpired, this.compact = false});

  final DateTime expiresAt;
  final VoidCallback? onExpired;
  final bool compact;

  @override
  State<HoldCountdown> createState() => _HoldCountdownState();
}

class _HoldCountdownState extends State<HoldCountdown> {
  Timer? _timer;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(HoldCountdown old) {
    super.didUpdateWidget(old);
    if (old.expiresAt != widget.expiresAt) _fired = false;
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (!_fired && widget.expiresAt.isBefore(DateTime.now())) {
      _fired = true;
      widget.onExpired?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.expiresAt.difference(DateTime.now());
    final urgent = left.inSeconds <= 60;
    final color = urgent ? ZoolColors.primary : ZoolColors.secondary;
    final text = formatCountdown(left);
    if (widget.compact) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, size: 18, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ]);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: urgent ? ZoolColors.primarySoft : ZoolColors.secondarySoft,
        borderRadius: BorderRadius.circular(ZoolRadii.field),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text('المقاعد محجوزة لك مؤقتًا', style: TextStyle(color: color, fontWeight: FontWeight.w600))),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}
