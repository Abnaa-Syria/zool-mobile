import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';

/// Trip map card (Figma 3043:3170 MapPlaceholder): the map with the stations (Arabic names), the
/// line between them, the bus marker, «تتبع المسار مباشرة» while live, zoom buttons and the speed.
class TripMap extends ConsumerStatefulWidget {
  const TripMap({super.key, required this.live, this.height = 210});

  /// `live` of the driver trip detail (same shape as the customer live view).
  final Json? live;
  final double height;

  @override
  ConsumerState<TripMap> createState() => _TripMapState();
}

class _TripMapState extends ConsumerState<TripMap> {
  final _map = MapController();
  bool _ready = false;

  List<({LatLng point, String name})> get _stations => [
        for (final t in widget.live?.list('timeline') ?? const <Json>[])
          if (t.obj('station').numOrNull('lat') != null && t.obj('station').numOrNull('lng') != null)
            (
              point: LatLng(t.obj('station').numOrNull('lat')!, t.obj('station').numOrNull('lng')!),
              name: t.obj('station').obj('city').strOrNull('nameAr') ?? t.obj('station').strOrNull('nameAr') ?? '',
            ),
      ];

  void _zoom(double delta) {
    if (!_ready) return;
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(3, 17));
  }

  @override
  Widget build(BuildContext context) {
    final tiles = ref.watch(mapTilesProvider).value;
    final live = widget.live;
    final stations = _stations;
    final route = stations.map((s) => s.point).toList();
    final pos = live?.objOrNull('position');
    final bus = pos?.numOrNull('lat') != null && pos?.numOrNull('lng') != null ? LatLng(pos!.numOrNull('lat')!, pos.numOrNull('lng')!) : null;
    final status = live?.str('status') ?? '';
    final moving = status == 'BOARDING' || status == 'IN_PROGRESS';
    final speed = pos?.intOrNull('speedKmh');
    final points = [...route, ?bus];

    return ClipRRect(
      borderRadius: BorderRadius.circular(ZoolRadii.bigCard),
      child: SizedBox(
        height: widget.height,
        child: Stack(children: [
          Positioned.fill(
            child: points.isEmpty
                ? const ColoredBox(
                    color: ZoolColors.secondarySoft,
                    child: Center(child: Text('لا توجد إحداثيات للمحطات بعد', style: TextStyle(color: ZoolColors.textMuted, fontSize: 12))),
                  )
                : FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      backgroundColor: ZoolColors.secondarySoft,
                      initialCameraFit: points.length > 1
                          ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.fromLTRB(48, 64, 48, 48))
                          : null,
                      initialCenter: points.first,
                      initialZoom: 9,
                      onMapReady: () => _ready = true,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    ),
                    children: [
                      if (tiles != null)
                        TileLayer(
                          urlTemplate: tiles.urlTemplate,
                          maxNativeZoom: tiles.maxZoom.toInt(),
                          userAgentPackageName: 'com.zoolgo.driver',
                        ),
                      if (route.length > 1)
                        PolylineLayer(polylines: [
                          // Stations joined in order (not the road itself), so a dashed line.
                          Polyline(
                            points: route,
                            color: ZoolColors.brand,
                            strokeWidth: 4,
                            borderColor: Colors.white,
                            borderStrokeWidth: 2,
                            pattern: StrokePattern.dashed(segments: const [12, 8]),
                          ),
                        ]),
                      MarkerLayer(markers: [
                        for (final (i, s) in stations.indexed)
                          Marker(
                            point: s.point,
                            width: 120,
                            height: 52,
                            alignment: Alignment.topCenter,
                            child: _StationPin(name: s.name, color: i == stations.length - 1 ? ZoolColors.primary : ZoolColors.brand),
                          ),
                        if (bus != null)
                          Marker(
                            point: bus,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(color: ZoolColors.brand.withValues(alpha: 0.25), shape: BoxShape.circle),
                              padding: const EdgeInsets.all(7),
                              child: Container(
                                decoration: const BoxDecoration(color: ZoolColors.brand, shape: BoxShape.circle),
                                child: const Icon(IconsaxPlusBold.bus, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                      ]),
                    ],
                  ),
          ),
          if (moving)
            PositionedDirectional(
              top: 10,
              end: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: ZoolColors.success, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('تتبع المسار مباشرة', style: TextStyle(color: ZoolColors.brand, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          PositionedDirectional(
            bottom: 8,
            start: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _MapButton(icon: Icons.add, onTap: () => _zoom(1)),
                const SizedBox(width: 6),
                _MapButton(icon: Icons.remove, onTap: () => _zoom(-1)),
              ]),
              if (speed != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(IconsaxPlusLinear.speedometer, color: ZoolColors.textStrong, size: 12),
                    const SizedBox(width: 4),
                    Text('$speed كم/س', style: const TextStyle(color: ZoolColors.textStrong, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Station label (Arabic city name) above its dot.
class _StationPin extends StatelessWidget {
  const _StationPin({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 3),
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
      ),
    ]);
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Icon(icon, size: 18, color: ZoolColors.textStrong),
      ),
    );
  }
}
