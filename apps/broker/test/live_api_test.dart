// Contract test against a running backend (dev mode, devOtp exposed). Skipped unless LIVE_API is set:
//   LIVE_API=http://localhost:4000/api/v1 flutter test test/live_api_test.dart
// Books one seat with the demo broker manager and cancels it again (the wallet ends where it started).
import 'dart:io';

import 'package:broker/data/broker_api.dart';
import 'package:broker/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:zool_core/zool_core.dart';

void main() {
  final base = Platform.environment['LIVE_API'];

  test('broker app API contract: login → search → hold → quote → confirm → ticket → cancel', () async {
    final session = AuthSession(authPath: '/broker/auth', store: MemoryTokenStore(), dio: createDio(baseUrl: base));
    final api = BrokerApi(ApiClient(session, dio: createDio(baseUrl: base)));

    // Login (waits out an OTP cooldown if one is running).
    Json challenge;
    while (true) {
      try {
        challenge = await session.requestOtp('+249900000101');
        break;
      } on ApiException catch (e) {
        if (e.code != 'OTP_COOLDOWN') rethrow;
        final wait = (e.detailsMap['retryAfterSeconds'] as num?)?.toInt() ?? 60;
        await Future<void>.delayed(Duration(seconds: wait + 1));
      }
    }
    expect(challenge.strOrNull('devOtp'), isNotNull, reason: 'the backend must run in development mode');
    final login = await session.verifyOtp(phone: '+249900000101', code: challenge.str('devOtp'), challengeId: challenge.str('challengeId'));
    expect(login.strOrNull('refreshToken'), isNotNull, reason: 'X-Client-Platform must return the refresh token in the body');

    final me = await api.me();
    expect(me.officeName, isNotEmpty);
    expect(me.canBook, isTrue);
    expect(me.isManager, isTrue);

    final dash = await api.dashboard();
    expect(dash.containsKey('ticketsSold'), isTrue);

    // Search tomorrow Khartoum → Port Sudan (demo schedule runs daily).
    final cities = await api.cities();
    final krt = cities.firstWhere((c) => c.json.str('code') == 'KRT');
    final pzu = cities.firstWhere((c) => c.json.str('code') == 'PZU');
    final tomorrow = sudanDay(DateTime.now().add(const Duration(days: 1)));
    final trips = await api.searchTrips(fromCityId: krt.id, toCityId: pzu.id, date: tomorrow);
    expect(trips, isNotEmpty, reason: 'run npm run db:demo on the backend');
    final listed = trips.firstWhere((t) => t.seatsFree > 0);
    expect(listed.origin.city, isNotEmpty);
    expect(listed.departureAt, isNotNull);
    expect(listed.basePrice, greaterThan(0));

    final trip = await api.trip(listed.id);
    expect(trip.seats, isNotEmpty);
    final seat = trip.seats.firstWhere((s) => s.status == 'FREE' && !s.womenOnly);

    // Top up when the demo wallet cannot pay (create → mock provider confirm, dev only).
    var balanceBefore = (await api.wallet()).integer('balanceMinor');
    if (balanceBefore < trip.basePrice) {
      final topUp = await api.createTopUp(amountMinor: trip.basePrice * 3, idempotencyKey: const Uuid().v4());
      expect(topUp.status, 'PENDING');
      expect(topUp.mockConfirmAvailable, isTrue);
      await api.mockConfirmTopUp(topUp.id);
      expect((await api.topUp(topUp.id)).status, 'CONFIRMED');
      final after = (await api.wallet()).integer('balanceMinor');
      expect(after, balanceBefore + trip.basePrice * 3);
      balanceBefore = after;
    }

    // Hold → quote → confirm.
    final hold = await api.hold(trip.id, [seat.id]);
    expect(hold.holdIds, hasLength(1));
    expect(hold.expiresAt.isAfter(DateTime.now()), isTrue);

    final body = {
      'tripId': trip.id,
      'seatIds': [seat.id],
      'passengers': [
        {'fullName': 'اختبار التطبيق', 'phone': '+249911000111', 'gender': 'MALE'},
      ],
    };
    final quote = await api.quote(body);
    expect(quote.totalMinor, trip.basePrice);
    expect(quote.walletBalanceMinor, balanceBefore);
    expect(quote.balanceAfterMinor, balanceBefore - trip.basePrice);
    expect(quote.sufficientBalance, isTrue);

    final confirmed = await api.confirm({...body, 'idempotencyKey': const Uuid().v4()});
    final booking = Booking(confirmed.obj('booking'));
    expect(booking.isConfirmed, isTrue);
    expect(confirmed.integer('balanceAfterMinor'), balanceBefore - trip.basePrice);

    final detail = await api.booking(booking.id);
    expect(detail.activeTickets, hasLength(1));
    expect(detail.activeTickets.first.seatLabel, seat.label);
    expect(detail.activeTickets.first.qrPayload, isNotNull);
    expect(detail.canModify, isTrue);

    final active = await api.bookings(tab: 'ACTIVE', q: detail.activeTickets.first.ticketNumber);
    expect(active.items.map((b) => b.id), contains(booking.id));

    // Change options for the same day (other trips of the same carrier) parse.
    final options = await api.changeOptions(booking.id, tomorrow);
    for (final o in options) {
      expect(o.departureAt, isNotNull);
    }

    // Cancel: full amount back to the wallet.
    final cancel = await api.cancel(booking.id);
    expect(cancel.integer('refundedAmountMinor'), trip.basePrice);
    expect(cancel.integer('balanceAfterMinor'), balanceBefore);
    expect((await api.booking(booking.id)).status, 'CANCELLED');

    // Wallet, top-ups, notifications, commissions parse.
    final ledger = await api.ledger();
    expect(ledger.items.first.amountMinor, greaterThan(0));
    await api.topUps();
    await api.notifications();
    expect(await api.unreadCount(), greaterThanOrEqualTo(0));
    final commissions = await api.commissions(status: 'UNSETTLED');
    expect(commissions.containsKey('totalUnsettledMinor'), isTrue);

    await session.logout();
    expect(session.status, AuthStatus.signedOut);
  }, skip: base == null ? 'set LIVE_API to run against a backend' : false, timeout: const Timeout(Duration(minutes: 3)));
}
