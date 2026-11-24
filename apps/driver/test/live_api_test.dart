// Contract test against a running dev backend (devOtp exposed). Skipped unless LIVE_API is set:
//   LIVE_API=http://localhost:4000/api/v1 flutter test test/live_api_test.dart
// Uses the demo driver (+249900000201). Read-mostly: it sends GPS to the current trip and checks the
// boarding window / scan rules without changing any trip's status.
import 'dart:io';

import 'package:driver/data/driver_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zool_core/zool_core.dart';

void main() {
  final base = Platform.environment['LIVE_API'];

  test('driver app API contract: login → dashboard → trips → detail → manifest → cash → scan → GPS', () async {
    final session = AuthSession(authPath: '/driver/auth', store: MemoryTokenStore(), dio: createDio(baseUrl: base));
    final api = DriverApi(ApiClient(session, dio: createDio(baseUrl: base)));
    const phone = '+249900000201';

    Json? otp;
    while (otp == null) {
      try {
        otp = await session.requestOtp(phone);
      } on ApiException catch (e) {
        if (e.code != 'OTP_COOLDOWN' && e.code != 'RATE_LIMITED') rethrow;
        final wait = e.detailsMap['retryAfterSeconds'];
        await Future<void>.delayed(Duration(seconds: (wait is num ? wait.ceil() : 30) + 1));
      }
    }
    final login = await session.verifyOtp(phone: phone, code: otp.str('devOtp'), challengeId: otp.str('challengeId'));
    expect(login.obj('driver').str('driverCode'), isNotEmpty);

    final me = await api.me();
    expect(me.companyName, isNotEmpty);
    expect(me.license.str('status'), isNotEmpty);

    final dash = await api.dashboard();
    expect(dash.tripsToday, greaterThanOrEqualTo(0));

    for (final tab in ['UPCOMING', 'CURRENT', 'COMPLETED']) {
      await api.trips(tab: tab);
    }
    final upcoming = (await api.trips(tab: 'UPCOMING')).items;
    final current = dash.currentTrip;
    final any = current ?? (upcoming.isNotEmpty ? upcoming.first : null);
    expect(any, isNotNull, reason: 'run npm run db:demo on the backend');

    final detail = await api.trip(any!.id);
    expect(detail.stops.first.isOrigin, isTrue);
    expect(detail.stops.last.isDestination, isTrue);
    expect(detail.middleStops.every((s) => s.id != null), isTrue, reason: 'intermediate stops expose their id');
    expect(detail.seatsTotal, greaterThan(0));
    expect(detail.live, isNotNull);

    final manifest = await api.manifest(any.id);
    expect(manifest.booked, manifest.passengers.where((p) => p.ticketStatus == 'CONFIRMED').length);
    final cash = await api.cash(any.id);
    // Outstanding leaves out no-shows (nothing to collect from them).
    expect(cash.outstandingMinor, lessThanOrEqualTo(cash.expectedMinor - cash.collectedMinor));

    // An unknown code is INVALID, never an error.
    final scan = await api.scan(any.id, 'ZG1.not-a-ticket');
    expect(scan.result, 'INVALID');

    // A trip far in the future cannot start boarding yet.
    final far = upcoming.where((t) => t.departureAt!.difference(DateTime.now()).inHours > 7).firstOrNull;
    if (far != null) {
      await expectLater(
        api.setStatus(far.id, 'BOARDING'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'TRIP_STATE_INVALID').having((e) => e.detailsMap['windowMinutes'], 'window', isA<num>())),
      );
    }

    // GPS: accepted on a live trip, rejected otherwise.
    final point = GpsPoint(lat: 16.2, lng: 33.1, speedKmh: 85, heading: 20, recordedAt: DateTime.now());
    if (current != null) {
      expect((await api.positions(current.id, [point])).integer('accepted'), 1);
      final live = (await api.trip(current.id)).live!;
      expect(live.obj('position').numOrNull('lat'), closeTo(16.2, 0.001));
    } else if (far != null) {
      await expectLater(api.positions(far.id, [point]), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    }

    await api.notifications();
    await api.unreadCount();
    await session.logout();
  }, skip: base == null ? 'set LIVE_API to run against a backend' : false, timeout: const Timeout(Duration(minutes: 3)));
}
