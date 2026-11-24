import 'package:flutter/material.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../data/models.dart';

/// Trip status as in the design: coloured dot + text («في الطريق» orange, «مجدولة اليوم» green).
(String, Color) tripStatusLabel(DriverTrip t) {
  switch (t.status) {
    case 'BOARDING':
      return ('جارٍ الصعود', ZoolColors.info);
    case 'IN_PROGRESS':
      return ('في الطريق', ZoolColors.warning);
    case 'COMPLETED':
      return ('مكتملة', ZoolColors.brand);
    case 'CANCELLED':
      return ('ملغاة', ZoolColors.error);
  }
  final dep = t.departureAt;
  if (dep != null && sudanDay(dep) == sudanDay()) return ('مجدولة اليوم', ZoolColors.success);
  return ('مجدولة', ZoolColors.success);
}

/// «اليوم، 08:00 صباحاً» / «الغد، 08:00 صباحاً» / «25 نوفمبر، 08:00 صباحاً».
String relativeDeparture(DateTime? at) {
  if (at == null) return '—';
  final day = sudanDay(at);
  final today = sudanDay();
  final tomorrow = sudanDay(DateTime.now().add(const Duration(days: 1)));
  final prefix = day == today ? 'اليوم' : (day == tomorrow ? 'الغد' : formatDayMonth(at));
  return '$prefix، ${formatTime(at)}';
}

/// Manifest row status: «صعد الباص» green · «في الانتظار» orange · «لم يحضر» red.
(String, Color) boardingLabel(ManifestEntry p) => switch (p.boardingStatus) {
      'BOARDED' => ('صعد الباص', ZoolColors.success),
      'NO_SHOW' => ('لم يحضر', ZoolColors.error),
      _ => ('في الانتظار', ZoolColors.warning),
    };

/// Scan result headline + colour.
(String, String, Color) scanResultText(ScanResult r) => switch (r.result) {
      'VALID' => ('تذكرة صالحة', 'تم التأكيد', ZoolColors.success),
      'ALREADY_BOARDED' => ('صعد مسبقًا', 'مستخدمة', ZoolColors.warning),
      'WRONG_TRIP' => ('رحلة مختلفة', 'ليست لهذه الرحلة', ZoolColors.error),
      'CANCELLED' => ('تذكرة ملغاة', 'ملغاة', ZoolColors.error),
      _ => ('رمز غير صالح', 'غير معروف', ZoolColors.error),
    };

/// «12 راكب» style count used in the design KPIs.
String passengersLabel(int n) => countLabel(n, one: 'راكب واحد', two: 'راكبان', few: 'ركاب', many: 'راكبًا');

String tripsCountLabel(int n) => n == 0 ? 'لا رحلات' : countLabel(n, one: 'رحلة واحدة', two: 'رحلتان', few: 'رحلات', many: 'رحلة');

/// Dot + text status from the design.
class DotStatus extends StatelessWidget {
  const DotStatus(this.label, this.color, {super.key, this.size = 12});

  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 4)]),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w600)),
    ]);
  }
}
