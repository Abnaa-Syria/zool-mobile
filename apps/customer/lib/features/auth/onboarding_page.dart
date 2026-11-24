import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../main.dart' show kOnboardingSeenKey;

const _pages = [
  ('assets/images/onboarding_1.jpg', 'تابع رحلتك لحظة بلحظة', 'استلم تذكرتك الرقمية وتابع موقع\nالباص وحالة رحلتك مباشرة.'),
  ('assets/images/onboarding_2.jpg', 'احجز مقعدك بسهولة', 'اختر رحلتك ومقعدك المناسب\nوأكمل حجزك بخطوات بسيطة وآمنة.'),
  ('assets/images/onboarding_3.jpg', 'كل الرحلات في مكان واحد', 'اكتشف رحلات من شركات نقل مختلفة وقارن بين المواعيد والأسعار بسهولة.'),
];

/// Onboarding (Figma 3074:1832 / 1730 / 1628): full-bleed image, ZG mark, title, text, dots,
/// «تخطي» and «التالي» / «ابدأ الآن».
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(kOnboardingSeenKey, true);
    } catch (_) {}
    ref.read(appFlagsProvider).onboardingSeen = true;
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: ZoolColors.brand,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Image.asset(_pages[i].$1, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: OutlinedButton(
                      onPressed: _finish,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('تخطي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const ZoolLogo(size: 200),
                  const SizedBox(height: 40),
                  Text(_pages[_index].$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2)),
                  const SizedBox(height: 10),
                  Text(_pages[_index].$3, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.3)),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _index ? 24 : 8,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _index ? ZoolColors.primary : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: last ? 'ابدأ الآن' : 'التالي',
                    onPressed: () => last ? _finish() : _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
