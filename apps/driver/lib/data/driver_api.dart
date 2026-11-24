import 'package:zool_core/zool_core.dart';

import 'models.dart';

class Paged<T> {
  const Paged(this.items, this.totalPages);

  final List<T> items;
  final int totalPages;
}

/// A GPS fix for `POST /driver/trips/:id/positions`.
class GpsPoint {
  const GpsPoint({required this.lat, required this.lng, required this.recordedAt, this.speedKmh, this.heading});

  final double lat;
  final double lng;
  final int? speedKmh;
  final int? heading;
  final DateTime recordedAt;

  Json toJson() => {
        'lat': lat,
        'lng': lng,
        'speedKmh': ?speedKmh,
        'heading': ?heading,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      };
}

/// Every driver endpoint the app uses (docs/SCREEN_API_MAP.md §driver).
class DriverApi {
  DriverApi(this.client);

  final ApiClient client;

  String _t(String tripId) => '/driver/trips/${Uri.encodeComponent(tripId)}';

  Future<Json> appConfig() async => (await client.get('/public/app-config')).json;

  Future<DriverMe> me() async => DriverMe((await client.get('/driver/me')).json);

  Future<DriverDashboard> dashboard() async => DriverDashboard((await client.get('/driver/dashboard')).json);

  /// [tab]: UPCOMING · CURRENT · COMPLETED.
  Future<Paged<DriverTrip>> trips({required String tab, int page = 1}) async {
    final res = await client.get('/driver/trips', query: {'tab': tab, 'page': page, 'pageSize': 20});
    return Paged(res.items.map(DriverTrip.new).toList(), res.totalPages);
  }

  Future<DriverTrip> trip(String id) async => DriverTrip((await client.get(_t(id))).json);

  /// BOARDING · IN_PROGRESS · COMPLETED. Returns the updated trip detail.
  Future<DriverTrip> setStatus(String tripId, String status) async =>
      DriverTrip((await client.post('${_t(tripId)}/status', body: {'status': status})).json);

  /// ARRIVED · DEPARTED at an intermediate stop (trip IN_PROGRESS).
  Future<Json> stopEvent(String tripId, String stopId, String event) async =>
      (await client.post('${_t(tripId)}/stops/${Uri.encodeComponent(stopId)}', body: {'event': event})).json;

  Future<Json> positions(String tripId, List<GpsPoint> points) async =>
      (await client.post('${_t(tripId)}/positions', body: {'positions': points.map((p) => p.toJson()).toList()})).json;

  Future<Manifest> manifest(String tripId) async => Manifest((await client.get('${_t(tripId)}/manifest')).json);

  Future<ScanResult> scan(String tripId, String code) async => ScanResult((await client.post('${_t(tripId)}/scan', body: {'code': code})).json);

  /// [method]: QR · MANUAL. Cash tickets need [cashCollectedMinor] equal to what is due.
  Future<ManifestEntry> board(String tripId, String ticketNumber, {String method = 'QR', int? cashCollectedMinor}) async =>
      ManifestEntry((await client.post('${_t(tripId)}/boardings', body: {
        'ticketNumber': ticketNumber,
        'method': method,
        'cashCollectedMinor': ?cashCollectedMinor,
      }))
          .json);

  Future<Json> noShow(String tripId, String ticketNumber) async =>
      (await client.post('${_t(tripId)}/no-shows', body: {'ticketNumber': ticketNumber})).json;

  Future<CashSummary> cash(String tripId) async => CashSummary((await client.get('${_t(tripId)}/cash')).json);

  // ------------------------------------------------------------ notifications
  Future<Paged<AppNotification>> notifications({int page = 1}) async {
    final res = await client.get('/driver/notifications', query: {'page': page, 'pageSize': 30});
    return Paged(res.items.map(AppNotification.new).toList(), res.totalPages);
  }

  Future<int> unreadCount() async => (await client.get('/driver/notifications/unread-count')).json.integer('unread');

  Future<void> markRead(String id) => client.post('/driver/notifications/$id/read');

  Future<void> markAllRead() => client.post('/driver/notifications/read-all');
}
