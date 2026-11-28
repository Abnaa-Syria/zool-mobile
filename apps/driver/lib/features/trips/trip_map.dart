import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';

/// Trip map card (Figma 3043:3170 MapPlaceholder): dark green map, glowing route between the
/// stations, the bus marker, «تتبع المسار مباشرة» while live, zoom buttons and the speed.
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
              name: (t.obj('station').obj('city').strOrNull('nameEn') ?? '').toUpperCase(),
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
                    color: Color(0xFF1C2A22),
                    child: Center(child: Text('لا توجد إحداثيات للمحطات بعد', style: TextStyle(color: Colors.white70, fontSize: 12))),
                  )
                : FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      backgroundColor: const Color(0xFF1C2A22),
                      initialCameraFit: points.length > 1
                          ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.fromLTRB(36, 56, 36, 36))
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
                          tileBuilder: _darkGreenTile,
                        ),
                      if (route.length > 1)
                        PolylineLayer(polylines: [
                          Polyline(points: route, color: const Color(0x5582F2A8), strokeWidth: 9),
                          Polyline(points: route, color: const Color(0xFFD9FBE4), strokeWidth: 3),
                        ]),
                      MarkerLayer(markers: [
                        for (final s in stations)
                          Marker(
                            point: s.point,
                            width: 110,
                            height: 34,
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            ]),
                          ),
                        if (bus != null)
                          Marker(
                            point: bus,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(color: const Color(0xFF82F2A8).withValues(alpha: 0.3), shape: BoxShape.circle),
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
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: ZoolColors.success, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('تتبع المسار مباشرة', style: TextStyle(color: Color(0xFF82F2A8), fontSize: 12, fontWeight: FontWeight.w700)),
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
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(IconsaxPlusLinear.speedometer, color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  Text('$speed km/h', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Darkens and tints OSM tiles to the design's night-green look.
Widget _darkGreenTile(BuildContext context, Widget tile, TileImage image) => ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -0.12, -0.22, -0.05, 0, 70, //
        -0.10, -0.25, -0.05, 0, 95,
        -0.10, -0.22, -0.06, 0, 72,
        0, 0, 0, 1, 0,
      ]),
      child: tile,
    );

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
        width: 22,
        height: 22,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white70)),
        child: Icon(icon, size: 14, color: Colors.white70),
      ),
    );
  }
}
