import 'api/json.dart';

/// Map tile source from `GET /public/app-config` → `maps` (MapTiler once its key is set in the
/// admin settings; OpenStreetMap otherwise). Phones use the high-density (@2x) tiles.
class MapTiles {
  const MapTiles({required this.urlTemplate, required this.attribution, this.maxZoom = 19});

  factory MapTiles.fromAppConfig(Json config) {
    final m = config.objOrNull('maps');
    final url = m?.strOrNull('tileUrlRetina') ?? m?.strOrNull('tileUrl');
    if (m == null || url == null) return osm;
    return MapTiles(urlTemplate: url, attribution: m.strOrNull('attribution') ?? osm.attribution, maxZoom: (m.intOrNull('maxZoom') ?? 19).toDouble());
  }

  static const osm = MapTiles(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', attribution: '© OpenStreetMap contributors');

  final String urlTemplate;
  final String attribution;
  final double maxZoom;
}
