import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// Live tracking (Figma 3074:3620): OpenStreetMap with the stations route and the bus, and a
/// panel with route, progress, distance, ETA, next station and the stop timeline. Polls
/// `GET /customer/bookings/:id/live` every `pollSeconds`.
class LivePage extends ConsumerStatefulWidget {
  const LivePage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<LivePage> createState() => _LivePageState();
}

class _LivePageState extends ConsumerState<LivePage> {
  final _map = MapController();
  LiveTrip? _live;
  Object? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final live = await ref.read(apiProvider).live(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _live = live;
        _error = null;
      });
      _timer?.cancel();
      _timer = Timer(Duration(seconds: live.pollSeconds.clamp(5, 60)), _load);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 20), _load);
    }
  }

  List<LatLng> _route(LiveTrip live) => [
        for (final t in live.timeline)
          if (t.obj('station').numOrNull('lat') != null && t.obj('station').numOrNull('lng') != null)
            LatLng(t.obj('station').numOrNull('lat')!, t.obj('station').numOrNull('lng')!),
      ];

  Future<void> _support() async {
    final s = (await ref.read(appConfigProvider.future).catchError((_) => <String, dynamic>{})).obj('support');
    final phone = s.strOrNull('phone');
    final whatsapp = s.strOrNull('whatsapp');
    if (whatsapp != null) {
      await launchUrl(Uri.parse('https://wa.me/${whatsapp.replaceAll(RegExp(r'\D'), '')}'), mode: LaunchMode.externalApplication);
    } else if (phone != null) {
      await launchUrl(Uri.parse('tel:$phone'));
    } else if (mounted) {
      showMessageSnack(context, 'رقم الدعم غير متاح حاليًا.', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = _live;
    if (live == null) {
      return ZoolPage(title: 'تتبع الرحلة', body: _error != null ? ErrorView(error: _error!, onRetry: _load) : const LoadingView());
    }
    final route = _route(live);
    final bus = live.lat != null && live.lng != null ? LatLng(live.lat!, live.lng!) : null;
    final points = [...route, ?bus];
    final progress = live.progressPercent.clamp(0, 100);
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: points.isEmpty
              ? const ColoredBox(color: ZoolColors.secondarySoft, child: Center(child: Text('لا توجد إحداثيات لهذه الرحلة بعد')))
              : FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCameraFit: points.length > 1
                        ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.fromLTRB(40, 160, 40, 380))
                        : null,
                    initialCenter: points.first,
                    initialZoom: 8,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.zoolgo.customer'),
                    if (route.length > 1) PolylineLayer(polylines: [Polyline(points: route, color: ZoolColors.brand, strokeWidth: 6)]),
                    MarkerLayer(markers: [
                      if (route.isNotEmpty)
                        Marker(point: route.last, width: 40, height: 40, alignment: Alignment.topCenter, child: const Icon(IconsaxPlusBold.location, color: ZoolColors.error, size: 40)),
                      if (bus != null)
                        Marker(
                          point: bus,
                          width: 56,
                          height: 56,
                          child: Container(
                            decoration: BoxDecoration(color: ZoolColors.brand.withValues(alpha: 0.25), shape: BoxShape.circle),
                            padding: const EdgeInsets.all(8),
                            child: Container(
                              decoration: const BoxDecoration(color: ZoolColors.brand, shape: BoxShape.circle),
                              child: const Icon(IconsaxPlusBold.bus, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                    ]),
                    const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap')]),
                  ],
                ),
        ),
        // Top card: back + title + times.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ZoolCard(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Column(children: [
                Row(children: [
                  RoundIconButton(icon: IconsaxPlusLinear.arrow_right, tooltip: 'رجوع', onTap: () => Navigator.of(context).maybePop()),
                  const Expanded(child: Text('تتبع الرحلة', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 40),
                ]),
                if (live.timeline.length >= 2) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    _End(time: live.timeline.first.date('scheduledAt'), name: _stationName(live.timeline.first), label: 'المغادرة'),
                    const Expanded(child: Icon(IconsaxPlusLinear.bus, color: ZoolColors.brand)),
                    _End(time: live.etaAt ?? live.timeline.last.date('scheduledAt'), name: _stationName(live.timeline.last), label: 'الوصول'),
                  ]),
                ],
              ]),
            ),
          ),
        ),
        // Bottom panel.
        DraggableScrollableSheet(
          initialChildSize: 0.42,
          minChildSize: 0.2,
          maxChildSize: 0.85,
          builder: (context, scroll) => DecoratedBox(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24)), boxShadow: ZoolShadows.bar),
            child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 10, 20, 24), children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: ZoolColors.divider, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('المسار', style: TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                    Text(
                      live.timeline.length >= 2 ? '${_cityName(live.timeline.first)} ← ${_cityName(live.timeline.last)}' : '—',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ]),
                ),
                TextButton.icon(onPressed: _support, icon: const Icon(IconsaxPlusLinear.message_question, size: 18), label: const Text('دعم')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Expanded(child: Text('التقدم في الرحلة', style: TextStyle(fontSize: 12))),
                Text('$progress%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: progress / 100, minHeight: 8, backgroundColor: ZoolColors.divider, color: ZoolColors.primary),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _Stat(value: live.remainingKm == null ? '—' : '${live.remainingKm} كم', label: 'المتبقي')),
                const SizedBox(width: 8),
                Expanded(child: _Stat(value: formatTime(live.etaAt), label: 'الوصول')),
                const SizedBox(width: 8),
                Expanded(child: _Stat(value: live.nextStopName ?? '—', label: 'المحطة القادمة')),
              ]),
              if (!live.moving) ...[
                const SizedBox(height: 12),
                StatusBadge(live.status == 'COMPLETED' ? 'انتهت الرحلة' : 'سيبدأ التتبع عند بدء الصعود', tone: BadgeTone.info),
              ],
              if (live.position?.integer('ageSeconds') != null && live.position!.integer('ageSeconds') > 120) ...[
                const SizedBox(height: 8),
                Text('آخر تحديث للموقع قبل ${(live.position!.integer('ageSeconds') / 60).round()} دقيقة', style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
              ],
              const SizedBox(height: 16),
              for (final t in live.timeline)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(t.flag('passed') ? IconsaxPlusBold.tick_circle : IconsaxPlusLinear.record, size: 18, color: t.flag('passed') ? ZoolColors.primary : ZoolColors.border),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_stationName(t), style: TextStyle(fontSize: 14, fontWeight: t.flag('passed') ? FontWeight.w700 : FontWeight.w400))),
                    Text(formatTime(t.date('actualAt') ?? t.date('scheduledAt')), style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                  ]),
                ),
              if (live.vehicle.strOrNull('plateNumber') != null || live.driver.strOrNull('displayName') != null) ...[
                const Divider(height: 24),
                InfoRow('الحافلة', [live.vehicle.strOrNull('model'), live.vehicle.strOrNull('plateNumber')].whereType<String>().join(' · ')),
                if (live.driver.strOrNull('displayName') != null) InfoRow('السائق', live.driver.str('displayName')),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  static String _stationName(Json t) {
    final s = t.obj('station');
    final city = s.obj('city').str('nameAr');
    final name = s.str('nameAr');
    return city.isEmpty || city == name ? name : '$city — $name';
  }

  static String _cityName(Json t) {
    final s = t.obj('station');
    final city = s.obj('city').str('nameAr');
    return city.isEmpty ? s.str('nameAr') : city;
  }
}

class _End extends StatelessWidget {
  const _End({required this.time, required this.name, required this.label});

  final DateTime? time;
  final String name;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 110,
        child: Column(children: [
          Text(formatClock(time), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.brand)),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          Text(label, style: const TextStyle(fontSize: 11, color: ZoolColors.textMuted)),
        ]),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(color: ZoolColors.field, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 11, color: ZoolColors.textMuted)),
        ]),
      );
}
