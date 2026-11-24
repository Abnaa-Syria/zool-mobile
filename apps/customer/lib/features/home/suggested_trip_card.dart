import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// «رحلات مقترحة لك» card (Figma 3074:2364): ticket-shaped card (design SVG), carrier logo,
/// name and rating, the heart (favourite), times with the dotted line, price.
class SuggestedTripCard extends ConsumerStatefulWidget {
  const SuggestedTripCard({super.key, required this.trip, this.onFavoriteChanged});

  final Trip trip;
  final ValueChanged<bool>? onFavoriteChanged;

  @override
  ConsumerState<SuggestedTripCard> createState() => _SuggestedTripCardState();
}

class _SuggestedTripCardState extends ConsumerState<SuggestedTripCard> {
  late bool _favorite = widget.trip.isFavorite;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final next = !_favorite;
    setState(() {
      _favorite = next;
      _busy = true;
    });
    try {
      await ref.read(apiProvider).setFavorite(widget.trip.id, next);
      widget.onFavoriteChanged?.call(next);
      if (mounted) showMessageSnack(context, next ? 'أُضيفت الرحلة إلى المفضلة' : 'أُزيلت الرحلة من المفضلة');
    } catch (e) {
      if (!mounted) return;
      setState(() => _favorite = !next);
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final bookable = t.bookable && t.departureAt != null && t.departureAt!.isAfter(DateTime.now());
    return GestureDetector(
      onTap: bookable ? () => context.push('/trip/outbound/${t.id}') : null,
      child: Stack(clipBehavior: Clip.none, children: [
        // Ticket outline from the design (350 × 185 card inside a 398 × 233 drop-shadow canvas).
        Positioned(
          left: -24 * (MediaQuery.sizeOf(context).width / 390),
          right: -24 * (MediaQuery.sizeOf(context).width / 390),
          top: -16,
          bottom: -32,
          child: SvgPicture.asset('assets/icons/ticket_card.svg', fit: BoxFit.fill),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CarrierLogo(name: t.carrierName, logoUrl: t.logoUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.carrierName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
                  const SizedBox(height: 4),
                  if (t.rating != null)
                    Row(children: [
                      const Icon(IconsaxPlusBold.star_1, size: 14, color: ZoolColors.warning),
                      const SizedBox(width: 4),
                      Text(t.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Text('(${t.ratingCount})', style: const TextStyle(fontSize: 12, color: ZoolColors.navInactive)),
                    ])
                  else
                    Text(formatLongDate(t.departureAt), style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                ]),
              ),
              IconButton(
                tooltip: _favorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                onPressed: _toggle,
                icon: Icon(_favorite ? IconsaxPlusBold.heart : IconsaxPlusLinear.heart, color: _favorite ? ZoolColors.primary : ZoolColors.textStrong),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _End(time: t.departureAt, city: t.origin.city),
              Expanded(
                child: Column(children: [
                  Text(formatDuration(t.durationMinutes), style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const _Dot(),
                    Expanded(child: CustomPaint(painter: _DashPainter(), size: const Size.fromHeight(1))),
                    const _Dot(),
                  ]),
                ]),
              ),
              _End(time: t.arrivalAt, city: t.destination.city),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text(
                  bookable ? '${formatDayMonth(t.departureAt)} · ${seatsLabel(t.seatsAvailable)} متاحة' : 'لم تعد متاحة للحجز',
                  style: TextStyle(fontSize: 12, color: bookable ? ZoolColors.textMuted : ZoolColors.error),
                ),
              ),
              MoneyText(formatSdg(t.priceMinor), size: 20, currencyColor: ZoolColors.textStrong),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _End extends StatelessWidget {
  const _End({required this.time, required this.city});

  final DateTime? time;
  final String city;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(children: [
          Text(formatClock(time), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ZoolColors.textStrong)),
          Text(city, style: const TextStyle(fontSize: 12, color: ZoolColors.textStrong)),
        ]),
      );
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
        width: 4,
        height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: const BoxDecoration(color: ZoolColors.brand, shape: BoxShape.circle),
      );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ZoolColors.brand
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 0), Offset((x + 2).clamp(0, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
