import 'package:dio/dio.dart';
import 'package:zool_core/zool_core.dart';

import 'models.dart';

/// A page of a list endpoint.
class Paged<T> {
  const Paged(this.items, this.totalPages, this.total);

  final List<T> items;
  final int totalPages;
  final int total;
}

/// Every broker endpoint the app uses (`/broker/*`, same API as the broker web panel).
class BrokerApi {
  BrokerApi(this.client);

  final ApiClient client;

  // -------------------------------------------------------------- profile & home
  Future<BrokerMe> me() async => BrokerMe((await client.get('/broker/auth/me')).json);

  Future<Json> dashboard() async => (await client.get('/broker/dashboard')).json;

  Future<Json> wallet() async => (await client.get('/broker/wallet')).json;

  Future<List<City>> cities() async => (await client.get('/public/cities')).items.map(City.new).toList();

  // -------------------------------------------------------------- booking
  Future<List<BrokerTrip>> searchTrips({required String fromCityId, required String toCityId, required String date}) async {
    final res = await client.get('/broker/trips', query: {'fromCityId': fromCityId, 'toCityId': toCityId, 'date': date, 'pageSize': 50});
    return res.items.map(BrokerTrip.new).toList();
  }

  Future<BrokerTrip> trip(String id) async => BrokerTrip((await client.get('/broker/trips/$id')).json);

  Future<HoldResult> hold(String tripId, List<String> seatIds) async =>
      HoldResult((await client.post('/broker/trips/$tripId/holds', body: {'mode': 'MANUAL', 'seatIds': seatIds})).json);

  /// Best effort: expired or already released holds are ignored.
  Future<void> releaseHolds(Iterable<String> holdIds) async {
    await Future.wait(holdIds.map((id) => client.delete('/broker/holds/$id').then((_) {}, onError: (_) {})));
  }

  Future<BookingQuote> quote(Json body) async => BookingQuote((await client.post('/broker/bookings/quote', body: body)).json);

  /// `{ booking, returnBooking?, balanceAfterMinor }`
  Future<Json> confirm(Json body) async => (await client.post('/broker/bookings/confirm', body: body)).json;

  // -------------------------------------------------------------- bookings
  Future<Paged<Booking>> bookings({required String tab, String? q, int page = 1}) async {
    final res = await client.get('/broker/bookings', query: {'tab': tab, 'q': q, 'page': page, 'pageSize': 20});
    return Paged(res.items.map(Booking.new).toList(), res.totalPages, res.total);
  }

  Future<List<Booking>> bookingGroup(String groupId) async {
    final res = await client.get('/broker/bookings', query: {'groupId': groupId, 'pageSize': 10});
    return res.items.map(Booking.new).toList();
  }

  Future<Booking> booking(String id) async => Booking((await client.get('/broker/bookings/$id')).json);

  /// `{ booking, refundedAmountMinor, commissionClawedBackMinor, balanceAfterMinor }`
  Future<Json> cancel(String id) async => (await client.post('/broker/bookings/$id/cancel')).json;

  Future<Booking> changeSeat(String id, {required String fromSeatLabel, required String toSeatLabel}) async => Booking(
        (await client.post('/broker/bookings/$id/change-seat', body: {'fromSeatLabel': fromSeatLabel, 'toSeatLabel': toSeatLabel})).json,
      );

  Future<List<ChangeOption>> changeOptions(String id, String date) async =>
      (await client.get('/broker/bookings/$id/change-options', query: {'date': date})).items.map(ChangeOption.new).toList();

  Future<Json> changeQuote(String id, {required String tripId, required List<String> seatIds}) async =>
      (await client.post('/broker/bookings/$id/change-quote', body: {'tripId': tripId, 'seatIds': seatIds})).json;

  Future<Booking> change(String id, {required String tripId, required List<String> seatIds, required String idempotencyKey}) async {
    final res = await client.post('/broker/bookings/$id/change', body: {'tripId': tripId, 'seatIds': seatIds, 'idempotencyKey': idempotencyKey});
    return Booking(res.json.obj('booking'));
  }

  // -------------------------------------------------------------- wallet
  Future<Paged<LedgerEntry>> ledger({int page = 1}) async {
    final res = await client.get('/broker/wallet/ledger', query: {'page': page, 'pageSize': 20});
    return Paged(res.items.map(LedgerEntry.new).toList(), res.totalPages, res.total);
  }

  Future<Paged<TopUp>> topUps({int page = 1}) async {
    final res = await client.get('/broker/wallet/top-ups', query: {'page': page, 'pageSize': 20});
    return Paged(res.items.map(TopUp.new).toList(), res.totalPages, res.total);
  }

  Future<TopUp> topUp(String id) async => TopUp((await client.get('/broker/wallet/top-ups/$id')).json);

  Future<TopUp> createTopUp({required int amountMinor, required String idempotencyKey}) async =>
      TopUp((await client.post('/broker/wallet/top-ups', body: {'amountMinor': amountMinor, 'idempotencyKey': idempotencyKey})).json);

  Future<TopUp> submitEvidence(String id, {required String receiptPath, required String paymentReference, String? note}) async {
    final form = FormData.fromMap({
      'paymentReference': paymentReference,
      if (note != null && note.isNotEmpty) 'note': note,
      'receipt': await MultipartFile.fromFile(receiptPath),
    });
    return TopUp((await client.post('/broker/wallet/top-ups/$id/evidence', body: form)).json);
  }

  Future<void> mockConfirmTopUp(String id) => client.post('/broker/wallet/top-ups/$id/mock-confirm');

  // -------------------------------------------------------------- notifications & commissions
  Future<Paged<AppNotification>> notifications({int page = 1}) async {
    final res = await client.get('/broker/notifications', query: {'page': page, 'pageSize': 30});
    return Paged(res.items.map(AppNotification.new).toList(), res.totalPages, res.total);
  }

  Future<int> unreadCount() async {
    final data = (await client.get('/broker/notifications/unread-count')).json;
    return data.integer('count', data.integer('unread'));
  }

  Future<void> markRead(String id) => client.post('/broker/notifications/$id/read');

  Future<void> markAllRead() => client.post('/broker/notifications/read-all');

  /// `{ totalUnsettledMinor, unsettledCount, lastSettledAt, items[] }`
  Future<Json> commissions({required String status, int page = 1}) async =>
      (await client.get('/broker/commissions', query: {'status': status, 'page': page, 'pageSize': 30})).json;
}
