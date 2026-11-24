import 'package:zool_core/zool_core.dart';

import 'models.dart';

class Paged<T> {
  const Paged(this.items, this.totalPages);

  final List<T> items;
  final int totalPages;
}

/// Every customer endpoint the app uses (docs/SCREEN_API_MAP.md §1).
class CustomerApi {
  CustomerApi(this.client);

  final ApiClient client;

  // ------------------------------------------------------------ public
  Future<Json> appConfig() async => (await client.get('/public/app-config')).json;

  Future<List<Json>> cities() async => (await client.get('/public/cities')).items;

  Future<List<Destination>> popular() async => (await client.get('/public/destinations/popular')).items.map(Destination.new).toList();

  Future<Json> content(String slug) async => (await client.get('/public/content/$slug')).json;

  // ------------------------------------------------------------ profile
  Future<CustomerMe> me() async => CustomerMe((await client.get('/customer/me')).json);

  Future<CustomerMe> updateMe({String? displayName, String? email}) async => CustomerMe((await client.patch('/customer/me', body: {
        'displayName': ?displayName,
        'email': ?email,
      })).json);

  Future<CustomerMe> setTripAlerts(bool on) async => CustomerMe((await client.patch('/customer/me/preferences', body: {'tripAlerts': on})).json);

  Future<void> deleteAccount() => client.delete('/customer/me');

  Future<List<Json>> recentSearches() async => (await client.get('/customer/recent-searches')).items;

  // ------------------------------------------------------------ search & seats
  Future<List<Trip>> searchTrips(Map<String, Object?> query) async =>
      (await client.get('/customer/trips', query: {...query, 'pageSize': 50})).items.map(Trip.new).toList();

  Future<Json> filters(Map<String, Object?> query) async => (await client.get('/customer/trips/filters', query: query)).json;

  Future<Trip> trip(String id) async => Trip((await client.get('/customer/trips/$id')).json);

  Future<SeatMapData> seats(String tripId) async => SeatMapData((await client.get('/customer/trips/$tripId/seats')).json);

  Future<Hold> hold(String tripId, List<String> seatLabels) async =>
      Hold((await client.post('/customer/trips/$tripId/holds', body: {'seatLabels': seatLabels})).json);

  Future<void> releaseHolds(Iterable<String> holdIds) async {
    await Future.wait(holdIds.map((id) => client.delete('/customer/holds/$id').then((_) {}, onError: (_) {})));
  }

  // ------------------------------------------------------------ checkout & payment
  Future<Quote> quote(Json body) async => Quote((await client.post('/customer/bookings/quote', body: body)).json);

  /// `{ groupId, bookings[], payment, replayed }`
  Future<Json> createBooking(Json body, {required String idempotencyKey}) async =>
      (await client.post('/customer/bookings', body: body, headers: {'Idempotency-Key': idempotencyKey})).json;

  Future<Json> paymentIntent(String intentId) async => (await client.get('/customer/payments/$intentId')).json;

  Future<Json> mockConfirm(String intentId) async => (await client.post('/customer/payments/$intentId/mock-confirm')).json;

  Future<Json> paymentMethods() async => (await client.get('/customer/payments/methods')).json;

  // ------------------------------------------------------------ my trips
  Future<Paged<Booking>> bookings({required String tab, int page = 1}) async {
    final res = await client.get('/customer/bookings', query: {'tab': tab, 'page': page, 'pageSize': 20});
    return Paged(res.items.map(Booking.new).toList(), res.totalPages);
  }

  Future<Booking> booking(String id) async => Booking((await client.get('/customer/bookings/$id')).json);

  Future<LiveTrip> live(String bookingId) async => LiveTrip((await client.get('/customer/bookings/$bookingId/live')).json);

  Future<Json> cancellationQuote(String bookingId) async => (await client.get('/customer/bookings/$bookingId/cancellation-quote')).json;

  /// `{ booking, refund, replayed }`
  Future<Json> cancel(String bookingId, {String? reason}) async =>
      (await client.post('/customer/bookings/$bookingId/cancel', body: {'reason': ?reason})).json;

  Future<Booking> changeSeat(String bookingId, {required String from, required String to}) async =>
      Booking((await client.post('/customer/bookings/$bookingId/change-seat', body: {'fromSeatLabel': from, 'toSeatLabel': to})).json);

  Future<List<Trip>> changeOptions(String bookingId, String date) async =>
      (await client.get('/customer/bookings/$bookingId/change-options', query: {'date': date})).items.map(Trip.new).toList();

  Future<Json> changeQuote(String bookingId, List<String> holdIds) async =>
      (await client.post('/customer/bookings/$bookingId/change-quote', body: {'holdIds': holdIds})).json;

  /// `{ booking, payment, refund, replayed }`
  Future<Json> change(String bookingId, List<String> holdIds, {required String idempotencyKey}) async => (await client
          .post('/customer/bookings/$bookingId/change', body: {'holdIds': holdIds}, headers: {'Idempotency-Key': idempotencyKey}))
      .json;

  Future<void> rate(String bookingId, {required int stars, String? comment}) =>
      client.post('/customer/bookings/$bookingId/rating', body: {'stars': stars, 'comment': ?comment});

  Future<List<int>> ticketPdf(String ticketNumber) => client.getBytes('/customer/tickets/${Uri.encodeComponent(ticketNumber)}/pdf');

  // ------------------------------------------------------------ notifications
  Future<Paged<AppNotification>> notifications({int page = 1}) async {
    final res = await client.get('/customer/notifications', query: {'page': page, 'pageSize': 30});
    return Paged(res.items.map(AppNotification.new).toList(), res.totalPages);
  }

  Future<int> unreadCount() async => (await client.get('/customer/notifications/unread-count')).json.integer('unread');

  Future<void> markRead(String id) => client.post('/customer/notifications/$id/read');

  Future<void> markAllRead() => client.post('/customer/notifications/read-all');
}
