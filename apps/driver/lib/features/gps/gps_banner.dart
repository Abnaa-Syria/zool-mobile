import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import 'gps_tracker.dart';

/// Keeps the GPS sender in step with a trip: on while BOARDING / IN_PROGRESS, off otherwise.
void syncGps(WidgetRef ref, String tripId, String status) {
  final gps = ref.read(gpsProvider);
  final live = status == 'BOARDING' || status == 'IN_PROGRESS';
  if (live) {
    gps.start(tripId);
  } else if (gps.tripId == tripId) {
    gps.stop();
  }
}

/// Live-location strip: «يتم مشاركة موقعك» with the last send time, or why it cannot.
class GpsBanner extends ConsumerWidget {
  const GpsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gps = ref.watch(gpsProvider);
    return ListenableBuilder(
      listenable: gps,
      builder: (context, _) {
        if (!gps.active) return const SizedBox.shrink();
        final problem = gps.problem;
        final (text, color, icon) = switch (problem) {
          GpsProblem.serviceOff => ('خدمة الموقع متوقفة. فعّلها ليتمكن الركاب من تتبع الرحلة.', ZoolColors.error, IconsaxPlusLinear.location_slash),
          GpsProblem.denied || GpsProblem.deniedForever => ('اسمح للتطبيق بالوصول إلى الموقع لمشاركة مسار الرحلة.', ZoolColors.error, IconsaxPlusLinear.location_slash),
          GpsProblem.none => (
              gps.lastSentAt == null
                  ? (gps.pending > 0 ? 'بانتظار الاتصال لإرسال الموقع (${gps.pending})' : 'جارٍ تحديد موقعك…')
                  : 'يتم مشاركة موقعك مباشرة · آخر إرسال ${formatTime(gps.lastSentAt)}',
              gps.pending > 1 ? ZoolColors.warning : ZoolColors.success,
              IconsaxPlusLinear.location_tick,
            ),
        };
        return Material(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: problem == GpsProblem.none ? null : gps.retryPermission,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600))),
                if (problem != GpsProblem.none) Text('تفعيل', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        );
      },
    );
  }
}
