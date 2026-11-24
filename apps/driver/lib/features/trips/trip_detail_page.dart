import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import '../gps/gps_banner.dart';
import 'trip_map.dart';

/// Arabic text for a driver action error; the boarding window gets its own sentence.
String driverErrorText(Object e) {
  if (e is ApiException && e.code == 'TRIP_STATE_INVALID') {
    final window = e.details is Map ? (e.details as Map)['windowMinutes'] : null;
    if (window is num) {
      final hours = window / 60;
      final span = hours == hours.roundToDouble() ? '${hours.round()} ساعات' : '${window.round()} دقيقة';
      return 'يبدأ الصعود قبل $span من موعد المغادرة.';
    }
    final m = e.message;
    if (m.contains('Start boarding')) return 'ابدأ الصعود أولًا من تفاصيل الرحلة.';
    if (m.contains('Stops')) return 'تُسجّل المحطات بعد انطلاق الرحلة.';
    if (m.contains('No-shows')) return 'يُسجّل عدم الحضور أثناء الصعود أو بعد الانطلاق.';
  }
  return errorMessage(e);
}

/// تفاصيل الرحلة (Figma 3043:3170) + the lifecycle the design leaves out (D-screens):
/// start boarding → depart → arrive/leave each stop → finish the trip.
class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      tripsChanged(ref);
      if (mounted && done != null) showMessageSnack(context, done);
    } catch (e) {
      if (mounted) showMessageSnack(context, driverErrorText(e), success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(DriverTrip t, String status) async {
    if (status == 'IN_PROGRESS') {
      final ok = await showConfirmDialog(
        context,
        title: 'انطلاق الرحلة؟',
        message: t.pending > 0
            ? 'لم يصعد ${passengersLabel(t.pending)} بعد. عند الانطلاق يُسجَّلون «لم يحضر» ولا يمكن صعودهم بالمسح.'
            : 'صعد جميع الركاب. سيبدأ تتبع الرحلة للركاب.',
        confirmLabel: 'انطلاق',
      );
      if (!ok) return;
    } else if (status == 'COMPLETED') {
      final ok = await showConfirmDialog(context, title: 'إنهاء الرحلة؟', message: 'تأكد من الوصول إلى ${t.destinationCity}. سيتوقف إرسال الموقع.', confirmLabel: 'إنهاء الرحلة');
      if (!ok) return;
    }
    await _run(() async {
      final updated = await ref.read(apiProvider).setStatus(t.id, status);
      syncGps(ref, updated.id, updated.status);
    }, done: switch (status) {
      'BOARDING' => 'بدأ الصعود. امسح تذاكر الركاب.',
      'IN_PROGRESS' => 'انطلقت الرحلة. رحلة موفقة!',
      _ => 'انتهت الرحلة. شكرًا لك.',
    });
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.tripId));
    ref.listen(tripProvider(widget.tripId), (_, next) {
      final t = next.value;
      if (t != null) syncGps(ref, t.id, t.status);
    });
    final t = trip.value;
    return ZoolPage(
      title: 'تفاصيل الرحلة',
      subtitle: t == null ? null : 'رقم الرحلة #${t.tripNumber}',
      bottomBar: t == null || t.status == 'CANCELLED'
          ? null
          : ZoolBottomBar(
              child: PrimaryButton(
                label: 'قائمة الركاب',
                icon: IconsaxPlusLinear.people,
                onPressed: () => context.push('/trip/${t.id}/passengers'),
              ),
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(tripProvider(widget.tripId).future),
        child: AsyncBody<DriverTrip>(
          value: trip,
          onRetry: () => ref.invalidate(tripProvider(widget.tripId)),
          data: (t) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              TripMap(live: t.live),
              if (t.isLive) ...[const SizedBox(height: 10), const GpsBanner()],
              const SizedBox(height: 14),
              _StatusCard(trip: t, busy: _busy, onStatus: (s) => _setStatus(t, s)),
              const SizedBox(height: 18),
              const SectionTitle('محطات الرحلة'),
              _Stops(
                trip: t,
                busy: _busy,
                onEvent: (stop, event) => _run(
                  () => ref.read(apiProvider).stopEvent(t.id, stop.id!, event),
                  done: event == 'ARRIVED' ? 'تم تسجيل الوصول إلى ${stop.cityName}' : 'تم تسجيل المغادرة من ${stop.cityName}',
                ),
              ),
              const SizedBox(height: 18),
              _InfoCard(trip: t),
              if (t.cashExpectedMinor > 0) ...[
                const SizedBox(height: 12),
                _CashCard(trip: t, onTap: () => context.push('/trip/${t.id}/cash')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Trip state + the next lifecycle action.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.trip, required this.busy, required this.onStatus});

  final DriverTrip trip;
  final bool busy;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final (label, color) = tripStatusLabel(t);
    final (String? next, String? action, String hint) = switch (t.status) {
      'SCHEDULED' => ('BOARDING', 'بدء الصعود', 'المغادرة ${relativeDeparture(t.departureAt)}. يبدأ الصعود قبل الموعد بوقت.'),
      'BOARDING' => ('IN_PROGRESS', 'انطلاق الرحلة', 'صعد ${t.boarded} من ${t.booked} · امسح التذاكر ثم انطلق.'),
      'IN_PROGRESS' => (
          'COMPLETED',
          'إنهاء الرحلة',
          t.startedAt == null ? 'سجّل وصولك لكل محطة ثم أنهِ الرحلة عند الوصول.' : 'انطلقت ${formatTime(t.startedAt)} · سجّل وصولك لكل محطة.',
        ),
      'COMPLETED' => (null, null, 'انتهت ${formatDateTime(t.completedAt)} · صعد ${passengersLabel(t.boarded)}.'),
      _ => (null, null, 'أُلغيت هذه الرحلة.'),
    };
    return ZoolCard(
      radius: ZoolRadii.bigCard,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('حالة الرحلة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          DotStatus(label, color),
        ]),
        const SizedBox(height: 6),
        Text(hint, style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary)),
        if (next != null && t.can(next)) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (t.status == 'BOARDING') ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/trip/${t.id}/scan'),
                  icon: const Icon(IconsaxPlusLinear.scan_barcode, size: 18),
                  label: const Text('مسح التذاكر'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: PrimaryButton(
                label: action!,
                busy: busy,
                color: next == 'COMPLETED' ? ZoolColors.primary : ZoolColors.brand,
                onPressed: busy ? null : () => onStatus(next),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

/// «محطات الرحلة»: white rows with a coloured dot on the start rail; intermediate stops get
/// «وصلت» / «غادرت» buttons while the trip is in progress.
class _Stops extends StatelessWidget {
  const _Stops({required this.trip, required this.busy, required this.onEvent});

  final DriverTrip trip;
  final bool busy;
  final void Function(TripStop stop, String event) onEvent;

  @override
  Widget build(BuildContext context) {
    final stops = trip.stops;
    final inProgress = trip.status == 'IN_PROGRESS';
    // The next stop to act on: the first intermediate one not yet departed.
    final nextIdx = stops.indexWhere((s) => s.kind == 'STOP' && s.departedAt == null);
    return Column(children: [
      for (final (i, s) in stops.indexed)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 22,
              child: Stack(alignment: Alignment.center, children: [
                // Rail: the upper half joins the previous stop, the lower half the next one.
                Column(children: [
                  Expanded(child: Container(width: 1.5, color: i == 0 ? Colors.transparent : ZoolColors.border)),
                  Expanded(child: Container(width: 1.5, color: i == stops.length - 1 ? Colors.transparent : ZoolColors.border)),
                ]),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _dot(s),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: _dot(s).withValues(alpha: 0.4), blurRadius: 4)],
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ZoolCard(
                  radius: ZoolRadii.bigCard,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.cityName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ZoolColors.textStrong)),
                          Text(
                            s.isOrigin ? 'نقطة الانطلاق' : (s.isDestination ? 'الوجهة النهائية' : 'محطة توقف'),
                            style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted),
                          ),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(formatClock(s.scheduledAt), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ZoolColors.brand)),
                        if (s.arrivedAt != null)
                          Text('وصل ${formatClock(s.arrivedAt)}', style: const TextStyle(fontSize: 11, color: ZoolColors.success, fontWeight: FontWeight.w600)),
                      ]),
                    ]),
                    if (inProgress && s.kind == 'STOP' && s.id != null && i == nextIdx) ...[
                      const SizedBox(height: 10),
                      s.arrivedAt == null
                          ? OutlinedButton.icon(
                              onPressed: busy ? null : () => onEvent(s, 'ARRIVED'),
                              icon: const Icon(IconsaxPlusLinear.location_tick, size: 18),
                              label: const Text('وصلت المحطة'),
                            )
                          : OutlinedButton.icon(
                              onPressed: busy ? null : () => onEvent(s, 'DEPARTED'),
                              icon: const Icon(IconsaxPlusLinear.routing_2, size: 18),
                              label: const Text('غادرت المحطة'),
                            ),
                    ],
                  ]),
                ),
              ),
            ),
          ]),
        ),
    ]);
  }

  Color _dot(TripStop s) {
    if (s.isOrigin) return ZoolColors.brand;
    if (s.isDestination) return ZoolColors.primary;
    return s.departedAt != null || s.arrivedAt != null ? ZoolColors.success : ZoolColors.warning;
  }
}

class _InfoCard extends ConsumerWidget {
  const _InfoCard({required this.trip});

  final DriverTrip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    final plate = trip.plateNumber;
    final model = trip.vehicleModel;
    return ZoolCard(
      radius: ZoolRadii.bigCard,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(children: [
        InfoRow('الشركة الناقلة', trip.carrierName, bold: true),
        InfoRow('السائق الرئيسي', me?.displayName ?? '—', bold: true),
        InfoRow('لوحة الباص', plate ?? '—', bold: true),
        if (model != null) InfoRow('نوع الباص', model, bold: true),
        InfoRow(
          'الركاب',
          trip.status == 'SCHEDULED' ? '${passengersLabel(trip.booked)} محجوز' : '${passengersLabel(trip.boarded)} صعدوا',
          valueColor: ZoolColors.brand,
          bold: true,
        ),
      ]),
    );
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({required this.trip, required this.onTap});

  final DriverTrip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ZoolCard(
      radius: ZoolRadii.bigCard,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: ZoolColors.secondarySoft, borderRadius: BorderRadius.circular(12)),
          child: const Icon(IconsaxPlusLinear.money_3, color: ZoolColors.brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('النقد المحصّل', style: TextStyle(fontSize: 12, color: ZoolColors.textSecondary)),
            Text(
              '${formatSdg(trip.cashCollectedMinor, withCurrency: false)} / ${formatSdg(trip.cashExpectedMinor)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ZoolColors.textStrong),
            ),
          ]),
        ),
        const Icon(IconsaxPlusLinear.arrow_left_2, color: ZoolColors.textMuted, size: 18),
      ]),
    );
  }
}
