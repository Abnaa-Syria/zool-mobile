import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../data/models.dart';
import '../booking/flow.dart';

/// Promo banners (Figma 3074:2319): 96 px rounded card with the bus image, title, «استخدم الكود»
/// and the code chip; dots under it. Tapping copies the code and pre-fills it at checkout.
class PromoCarousel extends ConsumerStatefulWidget {
  const PromoCarousel({super.key, required this.promotions});

  final List<Promotion> promotions;

  @override
  ConsumerState<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends ConsumerState<PromoCarousel> {
  final _controller = PageController();
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.promotions.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.animateToPage((_index + 1) % widget.promotions.length, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _use(Promotion p) async {
    await Clipboard.setData(ClipboardData(text: p.code));
    ref.read(bookingFlowProvider.notifier).setCoupon(p.code);
    if (mounted) showMessageSnack(context, 'تم نسخ الكود ${p.code} وسيُطبّق عند الدفع');
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.promotions;
    return Column(children: [
      SizedBox(
        height: 96,
        child: PageView.builder(
          controller: _controller,
          itemCount: items.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => _Banner(promotion: items[i], onTap: () => _use(items[i])),
        ),
      ),
      if (items.length > 1) ...[
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < items.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 24 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: ZoolColors.primary.withValues(alpha: i == _index ? 1 : 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
        ]),
      ],
    ]);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.promotion, required this.onTap});

  final Promotion promotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = promotion;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ZoolRadii.card),
        child: Stack(fit: StackFit.expand, children: [
          if (p.imageUrl != null)
            Image.network(p.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => Image.asset('assets/images/promo_banner.jpg', fit: BoxFit.cover))
          else
            Image.asset('assets/images/promo_banner.jpg', fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ZoolColors.textStrong)),
              Row(children: [
                Flexible(
                  child: Text(
                    p.subtitle ?? 'استخدم الكود:',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: ZoolColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(colors: [ZoolColors.brand, Color(0xFF1A7A4D)]),
                  ),
                  child: Text(p.code, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, height: 1.1)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
