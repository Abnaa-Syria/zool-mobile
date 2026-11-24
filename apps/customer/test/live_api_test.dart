// Contract test against a running dev backend (devOtp exposed). Skipped unless LIVE_API is set:
//   LIVE_API=http://localhost:4000/api/v1 flutter test test/live_api_test.dart
// A fresh test customer books online (mock payment) and cash, changes a seat, then cancels both.
import 'dart:io';
import 'dart:math';

import 'package:customer/data/customer_api.dart';
import 'package:customer/data/models.dart';
import 'package:customer/features/booking/flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

void main() {
  final base = Platform.environment['LIVE_API'];

  test('customer app API contract: login → search → hold → quote → pay (online + cash) → ticket → change seat → cancel', () async {
    final session = AuthSession(authPath: '/customer/auth', store: MemoryTokenStore(), dio: createDio(baseUrl: base));
    final api = CustomerApi(ApiClient(session, dio: createDio(baseUrl: base)));
    final phone = '+2499127${(Random().nextInt(90000) + 10000)}';

    final otp = await session.requestOtp(phone);
    final login = await session.verifyOtp(phone: phone, code: otp.str('devOtp'), challengeId: otp.str('challengeId'));
    expect(login.flag('isNewCustomer'), isTrue);
    expect(login.strOrNull('refreshToken'), isNotNull);

    final me = await api.updateMe(displayName: 'اختبار التطبيق');
    expect(me.displayName, 'اختبار التطبيق');
    expect(me.profileIncomplete, isFalse);

    final config = await api.appConfig();
    expect(config.str('defaultCountryCode'), '+249');

    final cities = (await api.cities()).map(SearchCity.fromJson).toList();
    final krt = cities.firstWhere((c) => c.nameEn == 'Khartoum');
    final pzu = cities.firstWhere((c) => c.nameEn == 'Port Sudan');
    expect(await api.popular(), isNotEmpty);

    final tomorrow = sudanDay(DateTime.now().add(const Duration(days: 1)));
    final query = {'fromCityId': krt.id, 'toCityId': pzu.id, 'date': tomorrow, 'passengers': 1};
    final trips = await api.searchTrips({...query, 'sort': 'priceMinor'});
    expect(trips, isNotEmpty, reason: 'run npm run db:demo on the backend');
    final filters = await api.filters(query);
    expect(filters.list('carriers'), isNotEmpty);
    expect((await api.recentSearches()).first.obj('toCity').str('id'), pzu.id);

    // Home extras: banners, suggestions, favourites.
    await api.promotions();
    final suggested = await api.suggestedTrips();
    expect(suggested.map((t) => t.id), contains(trips.first.id));
    await api.setFavorite(trips.first.id, true);
    expect((await api.favorites()).single.isFavorite, isTrue);
    expect((await api.suggestedTrips()).firstWhere((t) => t.id == trips.first.id).isFavorite, isTrue);
    await api.setFavorite(trips.first.id, false);
    expect(await api.favorites(), isEmpty);

    final trip = await api.trip(trips.first.id);
    expect(trip.stops, isNotEmpty);
    expect(trip.priceMinor, greaterThan(0));

    Future<({String holdId, Seat seat})> holdFree() async {
      final seats = await api.seats(trip.id);
      final seat = seats.seats.firstWhere((s) => s.state == 'AVAILABLE' && !s.womenOnly);
      final hold = await api.hold(trip.id, [seat.label]);
      expect(hold.holdIds, hasLength(1));
      return (holdId: hold.holdIds.first, seat: seat);
    }

    const pax = PassengerDraft(fullName: 'محمد أحمد', gender: 'MALE', phone: '0912345678');

    // Online: quote (coupon rejected), create, pay with the mock provider.
    final h1 = await holdFree();
    final body1 = {'holdIds': [h1.holdId], 'passengers': [pax.toJson()]};
    final quote = await api.quote(body1);
    expect(quote.totalMinor, trip.priceMinor);
    await expectLater(
      api.quote({...body1, 'couponCode': 'NOPE-${Random().nextInt(9999)}'}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'COUPON_INVALID')),
    );
    final created = await api.createBooking({...body1, 'paymentMethod': 'ONLINE'}, idempotencyKey: const Uuid().v4());
    final payment = created.obj('payment');
    expect(payment.str('status'), 'PENDING');
    expect(payment.obj('nextAction').str('type'), 'MOCK_CONFIRM');
    final paid = await api.mockConfirm(payment.str('intentId'));
    expect(paid.str('status'), 'SUCCEEDED');
    final online = await api.booking(created.list('bookings').first.str('id'));
    expect(online.isConfirmed, isTrue);
    expect(online.tickets.single.qrPayload, isNotNull);
    expect(online.canCancel, isTrue);

    // Change seat on the same trip.
    if (online.canChangeSeat) {
      final seats = await api.seats(trip.id);
      final target = seats.seats.firstWhere((s) => s.state == 'AVAILABLE' && !s.womenOnly);
      final moved = await api.changeSeat(online.id, from: online.tickets.single.seatLabel, to: target.label);
      expect(moved.activeTickets.single.seatLabel, target.label);
    }

    // Cash to the driver.
    final h2 = await holdFree();
    final body2 = {'holdIds': [h2.holdId], 'passengers': [pax.toJson()]};
    final q2 = await api.quote(body2);
    if (q2.cashAllowed) {
      final cash = await api.createBooking({...body2, 'paymentMethod': 'CASH_ON_BOARD'}, idempotencyKey: const Uuid().v4());
      final cb = Booking(cash.list('bookings').first);
      expect(cb.isConfirmed, isTrue);
      expect(cb.isCash, isTrue);
      expect(cb.cashToCollectMinor, trip.priceMinor);
      final cq = await api.cancellationQuote(cb.id);
      expect(cq.flag('cancellable'), isTrue);
      await api.cancel(cb.id);
    } else {
      await api.releaseHolds([h2.holdId]);
    }

    // Lists, live, ticket, cancel the online booking with its refund.
    final upcoming = await api.bookings(tab: 'UPCOMING');
    expect(upcoming.items.map((b) => b.id), contains(online.id));
    final live = await api.live(online.id);
    expect(live.timeline, isNotEmpty);
    final cancelQuote = await api.cancellationQuote(online.id);
    expect(cancelQuote.integer('refundableMinor'), trip.priceMinor);
    final cancelled = await api.cancel(online.id);
    expect(Booking(cancelled.obj('booking')).status, 'CANCELLED');
    expect(cancelled.obj('refund').integer('amountMinor'), trip.priceMinor);
    expect((await api.bookings(tab: 'CANCELLED')).items.map((b) => b.id), contains(online.id));

    final notifications = await api.notifications();
    expect(notifications.items, isNotEmpty);
    expect(await api.unreadCount(), greaterThan(0));
    expect((await api.content('privacy')).list('sections'), isNotEmpty);
    expect((await api.paymentMethods()).list('methods'), isNotEmpty);
    expect((await api.setTripAlerts(false)).tripAlerts, isFalse);

    await session.logout();
  }, skip: base == null ? 'set LIVE_API to run against a backend' : false, timeout: const Timeout(Duration(minutes: 3)));
}
