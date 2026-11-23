// Renders the main screens with the real font and canned data, and fails on any layout overflow.
// Screenshots (for review, not committed): flutter test test/screens_test.dart --update-goldens
//   → test/_screens/*.png
import 'dart:convert';

import 'package:broker/app/providers.dart';
import 'package:broker/data/broker_api.dart';
import 'package:broker/data/models.dart';
import 'package:broker/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';

final _dep = DateTime.now().toUtc().add(const Duration(days: 1)).copyWith(hour: 5, minute: 0);

Json _point(String city, String station) => {
      'city': {'id': city, 'nameAr': city, 'code': city},
      'station': {'id': station, 'nameAr': station},
    };

final _trip = <String, dynamic>{
  'id': 'trip1',
  'company': {'id': 'c1', 'name': 'النيل للنقل'},
  'carrier': {'rating': {'average': 4.6, 'count': 120}},
  'serviceClass': 'VIP',
  'origin': _point('الخرطوم', 'الميناء البري'),
  'destination': _point('بورتسودان', 'الموقف الرئيسي'),
  'departureAt': _dep.toIso8601String(),
  'arrivalAt': _dep.add(const Duration(hours: 10, minutes: 30)).toIso8601String(),
  'durationMinutes': 630,
  'stops': [
    {'kind': 'ORIGIN', 'city': {'nameAr': 'الخرطوم'}, 'station': {'nameAr': 'الميناء البري'}, 'scheduledAt': _dep.toIso8601String()},
    {'kind': 'STOP', 'city': {'nameAr': 'عطبرة'}, 'scheduledAt': _dep.add(const Duration(hours: 4)).toIso8601String()},
    {'kind': 'DESTINATION', 'city': {'nameAr': 'بورتسودان'}, 'scheduledAt': _dep.add(const Duration(hours: 10, minutes: 30)).toIso8601String()},
  ],
  'amenities': [
    {'nameAr': 'تكييف'},
    {'nameAr': 'واي فاي'},
  ],
  'vehicleModel': 'Yutong ZK6122',
  'basePrice': 3500000,
  'commissionPercent': 10,
  'seatsFree': 31,
  'seatsTotal': 40,
  'layout': {'rows': 10, 'columns': 4, 'aisleAfterColumn': 2, 'driverSide': 'LEFT'},
  'seats': [
    for (var r = 1; r <= 10; r++)
      for (var c = 1; c <= 4; c++)
        {
          'id': 's${(r - 1) * 4 + c}',
          'label': '${(r - 1) * 4 + c}',
          'row': r,
          'column': c,
          'status': ((r - 1) * 4 + c) % 5 == 0 ? 'SOLD' : 'FREE',
          'isWomenOnly': (r - 1) * 4 + c == 11 || (r - 1) * 4 + c == 12,
        },
  ],
};

final _booking = <String, dynamic>{
  'id': 'b1',
  'status': 'CONFIRMED',
  'bookingRef': 'ZG-7K2P9',
  'trip': {'id': 'trip1', 'origin': 'الخرطوم', 'destination': 'بورتسودان', 'departureAt': _dep.toIso8601String(), 'company': {'name': 'النيل للنقل'}},
  'totalAmountMinor': 7000000,
  'commissionAmountMinor': 700000,
  'commissionStatus': 'UNSETTLED',
  'employee': {'displayName': 'أحمد محمد'},
  'createdAt': DateTime.now().toUtc().toIso8601String(),
  'leg': 'OUTBOUND',
  'passengers': [
    {'fullName': 'محمد عثمان', 'phone': '+249912345678', 'gender': 'MALE'},
    {'fullName': 'فاطمة علي', 'phone': '+249923456789', 'gender': 'FEMALE'},
  ],
  'tickets': [
    {'ticketNumber': 'TK-100231', 'status': 'CONFIRMED', 'seatLabel': '7', 'passengerName': 'محمد عثمان', 'boardingStatus': 'PENDING', 'qrPayload': 'ZG1.TK-100231.signature'},
    {'ticketNumber': 'TK-100232', 'status': 'CONFIRMED', 'seatLabel': '8', 'passengerName': 'فاطمة علي', 'boardingStatus': 'PENDING', 'qrPayload': 'ZG1.TK-100232.signature'},
  ],
};

class FakeApi extends BrokerApi {
  FakeApi(super.client);

  @override
  Future<BrokerMe> me() async => BrokerMe({
        'id': 'e1',
        'displayName': 'أحمد محمد',
        'role': 'MANAGER',
        'permissions': ['broker.book', 'broker.wallet.topup', 'broker.reports.view', 'broker.staff.manage'],
        'office': {'id': 'o1', 'code': 'ZG-KRT-01', 'name': 'مكتب السوق العربي'},
        'identities': [
          {'type': 'PHONE', 'value': '+249900000101', 'isPrimary': true},
        ],
      });

  @override
  Future<Json> dashboard() async =>
      {'scope': 'OFFICE', 'bookingsCount': 12, 'ticketsSold': 27, 'grossSalesMinor': 94500000, 'commissionAccruedMinor': 9450000};

  @override
  Future<Json> wallet() async => {'balanceMinor': 125000000, 'lowBalance': false, 'lowBalanceThresholdMinor': 10000000};

  @override
  Future<int> unreadCount() async => 3;

  @override
  Future<Paged<Booking>> bookings({required String tab, String? q, int page = 1}) async =>
      Paged([Booking(_booking), Booking({..._booking, 'id': 'b2', 'bookingRef': 'ZG-3M8Q1', 'leg': null, 'status': 'CANCELLED'})], 1, 2);

  @override
  Future<Booking> booking(String id) async => Booking(_booking);

  @override
  Future<List<Booking>> bookingGroup(String groupId) async => const [];

  @override
  Future<BrokerTrip> trip(String id) async => BrokerTrip(_trip);

  @override
  Future<List<BrokerTrip>> searchTrips({required String fromCityId, required String toCityId, required String date}) async =>
      [BrokerTrip(_trip), BrokerTrip({..._trip, 'id': 'trip2', 'serviceClass': 'STANDARD', 'basePrice': 2800000, 'seatsFree': 0})];
}

/// Answers the session refresh so the app starts signed in.
class _AuthAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async => ResponseBody.fromString(
        jsonEncode({'success': true, 'data': {'accessToken': 'a', 'refreshToken': 'r2'}}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );

  @override
  void close({bool force = false}) {}
}

Future<void> _loadFonts() async {
  final loader = FontLoader('packages/zool_ui/IBMPlexSansArabic')
    ..addFont(rootBundle.load('packages/zool_ui/assets/fonts/IBMPlexSansArabic-Regular.ttf'))
    ..addFont(rootBundle.load('packages/zool_ui/assets/fonts/IBMPlexSansArabic-Bold.ttf'));
  await loader.load();
  final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  setUpAll(_loadFonts);

  Future<GoRouter> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = MemoryTokenStore()..value = 'r1';
    final dio = createDio(baseUrl: 'http://test')..httpClientAdapter = _AuthAdapter();
    final session = AuthSession(authPath: '/broker/auth', store: store, dio: dio);
    await tester.runAsync(session.restore);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(session),
        apiProvider.overrideWith((ref) => FakeApi(ApiClient(session, dio: dio))),
      ],
      child: BrokerApp(session: session),
    ));
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byType(Navigator).first));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('_screens/$name.png'));
  }

  testWidgets('home', (tester) async {
    await boot(tester);
    expect(find.text('حجز جديد'), findsOneWidget);
    await shot(tester, 'home');
  });

  testWidgets('seat selection', (tester) async {
    final router = await boot(tester);
    router.push('/book/seats/outbound/trip1');
    await shot(tester, 'seats');
  });

  testWidgets('booking detail with QR tickets', (tester) async {
    final router = await boot(tester);
    router.push('/booking/b1');
    await shot(tester, 'booking');
  });

  testWidgets('bookings list', (tester) async {
    final router = await boot(tester);
    router.go('/bookings');
    await shot(tester, 'bookings');
  });

  testWidgets('more / profile', (tester) async {
    final router = await boot(tester);
    router.go('/more');
    await shot(tester, 'more');
  });
}
