import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import '../trips/trip_detail_page.dart';

/// Boards a passenger. A cash-to-driver ticket first asks the driver to confirm the amount
/// was received (D-CASH-01: the full amount, no partial payments). Returns true on success.
Future<bool> boardPassenger(BuildContext context, WidgetRef ref, String tripId, ManifestEntry p, {required String method}) async {
  final due = p.cashToCollectMinor;
  if (due > 0) {
    final ok = await showConfirmDialog(
      context,
      title: 'استلام المبلغ نقدًا',
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الراكب ${p.fullName} · مقعد ${p.seatLabel}', style: const TextStyle(fontSize: 13, color: ZoolColors.textSecondary)),
        const SizedBox(height: 12),
        Center(child: MoneyText(formatSdg(due), size: 26)),
        const SizedBox(height: 12),
        const Text('تأكد من استلام المبلغ كاملًا قبل تسجيل الصعود.', style: TextStyle(fontSize: 12, color: ZoolColors.textSecondary)),
      ]),
      confirmLabel: 'استلمت المبلغ',
    );
    if (!ok) return false;
  }
  try {
    await ref.read(apiProvider).board(tripId, p.ticketNumber, method: method, cashCollectedMinor: due > 0 ? due : null);
    tripsChanged(ref);
    if (context.mounted) showMessageSnack(context, 'تم تسجيل صعود ${p.fullName}');
    return true;
  } catch (e) {
    if (context.mounted) showMessageSnack(context, driverErrorText(e), success: false);
    return false;
  }
}
