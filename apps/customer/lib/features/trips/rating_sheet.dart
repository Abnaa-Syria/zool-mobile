import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// Rate carrier modal (Figma 3074:4230): 1–5 stars + optional comment, once per booking.
Future<void> showRatingSheet(BuildContext context, WidgetRef ref, Booking booking) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RatingSheet(booking: booking),
  );
}

class _RatingSheet extends ConsumerStatefulWidget {
  const _RatingSheet({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<_RatingSheet> {
  int _stars = 0;
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final c = _comment.text.trim();
      await ref.read(apiProvider).rate(widget.booking.id, stars: _stars, comment: c.isEmpty ? null : c);
      bookingsChanged(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
      showMessageSnack(context, 'شكرًا لتقييمك!');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CarrierLogo(name: widget.booking.trip.carrierName, logoUrl: widget.booking.trip.logoUrl, size: 56),
          const SizedBox(height: 10),
          Text('كيف كانت رحلتك مع ${widget.booking.trip.carrierName}؟', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${widget.booking.trip.origin.city} ← ${widget.booking.trip.destination.city}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: () => setState(() => _stars = i),
                iconSize: 38,
                tooltip: '$i',
                icon: Icon(i <= _stars ? IconsaxPlusBold.star_1 : IconsaxPlusLinear.star_1, color: ZoolColors.warning),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _comment, maxLines: 3, decoration: const InputDecoration(hintText: 'شاركنا رأيك (اختياري)')),
          const SizedBox(height: 16),
          PrimaryButton(label: 'إرسال التقييم', busy: _busy, onPressed: _stars == 0 ? null : _send),
        ]),
      ),
    );
  }
}
