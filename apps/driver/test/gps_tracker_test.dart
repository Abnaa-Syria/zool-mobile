import 'package:driver/data/driver_api.dart';
import 'package:driver/features/gps/gps_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zool_core/zool_core.dart';

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  GpsPoint fix(int i) => GpsPoint(lat: 15.5 + i / 1000, lng: 32.5, speedKmh: 80, recordedAt: DateTime.now());

  test('buffers fixes while offline, keeps them across a restart, then flushes in order', () async {
    var online = false;
    final sent = <GpsPoint>[];
    var n = 0;
    Future<void> send(String trip, List<GpsPoint> points) async {
      if (!online) throw ApiException.network();
      sent.addAll(points);
    }

    final a = GpsTracker(send: send, locate: () async => fix(n++), interval: const Duration(hours: 1));
    await a.start('t1');
    await _settle();
    expect(a.pending, 1);
    await a.stop();

    // A new tracker (app restart) restores the saved fix and sends both once online.
    online = true;
    final b = GpsTracker(send: send, locate: () async => fix(n++), interval: const Duration(hours: 1));
    await b.start('t1');
    await _settle();
    expect(b.pending, 0);
    expect(sent.map((p) => p.lat), [15.5, 15.501]);
    expect(b.lastSentAt, isNotNull);
    await b.stop();
  });

  test('stops and clears when the trip is no longer live (409)', () async {
    final t = GpsTracker(
      send: (_, _) async => throw ApiException(code: 'TRIP_STATE_INVALID', message: 'GPS is accepted only while boarding or in progress', statusCode: 409),
      locate: () async => fix(0),
      interval: const Duration(hours: 1),
    );
    await t.start('t1');
    await _settle();
    expect(t.active, isFalse);
    expect(t.pending, 0);
    expect((await SharedPreferences.getInstance()).getString('zoolgo.driver.gps.t1'), isNull);
  });

  test('disabled tracker never starts', () async {
    final t = GpsTracker(send: (_, _) async {}, locate: () async => fix(0), enabled: false);
    await t.start('t1');
    expect(t.active, isFalse);
  });
}
