import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_ui/zool_ui.dart';

import 'flow.dart';

/// C9 / B3 — the seat hold ran out: explain, drop the legs, go back to the outbound results.
Future<void> onHoldExpired(BuildContext context, WidgetRef ref) async {
  await showInfoDialog(
    context,
    title: 'انتهت مدة حجز المقاعد',
    message: 'انتهت المهلة المؤقتة للمقاعد المختارة. اختر المقاعد مرة أخرى لإكمال الحجز.',
    button: 'اختيار المقاعد',
  );
  if (!context.mounted) return;
  ref.read(bookingFlowProvider.notifier).clearLeg(isReturn: false);
  // Back to the outbound results (the search is kept).
  final router = GoRouter.of(context);
  router.go('/book');
  router.push('/book/results/outbound');
}
