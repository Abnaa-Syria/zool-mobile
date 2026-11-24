import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:zool_core/zool_core.dart';

import '../theme.dart';

/// Design timeline: departure time (green, bold) · city · «المغادرة» on the start, a dotted line
/// with the duration above and «مباشر» / stops below, the arrival on the end.
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

  /// Under the line (e.g. "مباشر" / "2 توقف").
  final String? middleLabel;

  @override
  Widget build(BuildContext context) {
    Widget end(DateTime? time, String city, String? station, String label) => SizedBox(
          width: 84,
          child: Column(
            children: [
              Text(formatClock(time), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.brand)),
              Text(
                station == null || station.isEmpty ? city : '$city\n$station',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: ZoolColors.textStrong, height: 1.35),
              ),
              Text(label, style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
            ],
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        end(departureAt, originCity, originStation, 'المغادرة'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              children: [
                Text(formatDuration(durationMinutes), style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                const SizedBox(height: 4),
                const _DottedLine(),
                const SizedBox(height: 4),
                if (middleLabel != null) Text(middleLabel!, style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
              ],
            ),
          ),
        ),
        end(arrivalAt, destinationCity, destinationStation, 'الوصول'),
      ],
    );
  }
}

/// "08:30" (24-hour, Sudan time) as in the design cards.
String formatClock(DateTime? instant) {
  if (instant == null) return '—';
  final d = toSudan(instant);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _DottedLine extends StatelessWidget {
  const _DottedLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4,
      child: Row(
        children: [
          const _Dot(),
          const SizedBox(width: 8),
          Expanded(child: CustomPaint(painter: _DashPainter(), size: const Size.fromHeight(1))),
          const SizedBox(width: 8),
          const _Dot(),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 4, height: 4, child: DecoratedBox(decoration: BoxDecoration(color: ZoolColors.brand, shape: BoxShape.circle)));
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ZoolColors.brand
      ..strokeWidth = 1;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, y), Offset((x + 2).clamp(0, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Carrier logo (40 px, 12 radius) or its initial.
class CarrierLogo extends StatelessWidget {
  const CarrierLogo({super.key, required this.name, this.logoUrl, this.size = 40});

  final String name;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: ZoolColors.secondarySoft, borderRadius: BorderRadius.circular(12)),
      child: Text(name.isEmpty ? '؟' : name.characters.first, style: TextStyle(color: ZoolColors.brand, fontWeight: FontWeight.w800, fontSize: size * 0.45)),
    );
    if (logoUrl == null || logoUrl!.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(logoUrl!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}

/// Logo · carrier name (bold) · legal name (grey) · date on the end — the top of every trip card.
class CarrierHeader extends StatelessWidget {
  const CarrierHeader({super.key, required this.name, this.subtitle, this.logoUrl, this.trailing});

  final String name;
  final String? subtitle;
  final String? logoUrl;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CarrierLogo(name: name, logoUrl: logoUrl),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.textStrong), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
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
    final color = urgent ? ZoolColors.primary : ZoolColors.brand;
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
        color: urgent ? ZoolColors.primarySoft : Colors.white,
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

/// Amenity code (wifi, ac, usb, wc, snack, tv, luggage, vip_seats) → Iconsax icon.
IconData amenityIcon(String code) => switch (code) {
      'wifi' => IconsaxPlusLinear.wifi,
      'ac' => IconsaxPlusLinear.wind,
      'usb' => IconsaxPlusLinear.flash_1,
      'snack' => IconsaxPlusLinear.coffee,
      'tv' => IconsaxPlusLinear.monitor,
      'luggage' => IconsaxPlusLinear.box_1,
      'vip_seats' => IconsaxPlusLinear.shield,
      'wc' => IconsaxPlusLinear.drop,
      _ => IconsaxPlusLinear.tick_circle,
    };
