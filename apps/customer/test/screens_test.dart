// Renders the main screens with the real fonts and canned data; fails on any layout overflow.
// Review screenshots (not committed): flutter test test/screens_test.dart --update-goldens → test/_screens/
import 'dart:convert';

import 'package:customer/app/providers.dart';
import 'package:customer/data/customer_api.dart';
import 'package:customer/data/models.dart';
import 'package:customer/features/booking/flow.dart';
import 'package:customer/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

final _dep = DateTime.now().toUtc().add(const Duration(days: 1)).copyWith(hour: 5, minute: 0, second: 0);

Json _city(String id, String ar, String en) => {'id': id, 'code': id.toUpperCase(), 'nameAr': ar, 'nameEn': en};

final _trip = <String, dynamic>{
  'id': 't1',
  'tripNumber': 'KRT-PZU-0700',
  'status': 'SCHEDULED',
  'carrier': {'id': 'c1', 'name': 'سودان إكسبريس', 'legalName': 'شركة سودان إكسبريس للنقل البري', 'logoUrl': null, 'rating': {'average': 4.6, 'count': 120}},
  'serviceClass': 'VIP',
  'departureAt': _dep.toIso8601String(),
  'arrivalAt': _dep.add(const Duration(hours: 12)).toIso8601String(),
  'durationMinutes': 720,
  'origin': {'station': {'nameAr': 'الميناء البري'}, 'city': _city('krt', 'الخرطوم', 'Khartoum')},
  'destination': {'station': {'nameAr': 'الموقف السفري'}, 'city': _city('pzu', 'بورتسودان', 'Port Sudan')},
  'isDirect': false,
  'stopsCount': 2,
  'seatsAvailable': 24,
  'seatsTotal': 28,
  'amenities': [
    {'code': 'wifi', 'nameAr': 'واي فاي'},
    {'code': 'ac', 'nameAr': 'تكييف'},
    {'code': 'usb', 'nameAr': 'شحن USB'},
    {'code': 'luggage', 'nameAr': 'أمتعة', 'value': '30 كجم'},
  ],
  'priceMinor': 3500000,
  'vehicleModel': 'Toyota Coaster',
  'cashAvailable': true,
  'stops': [
    {'kind': 'ORIGIN', 'city': {'nameAr': 'الخرطوم'}, 'station': {'nameAr': 'الميناء البري'}, 'scheduledAt': _dep.toIso8601String()},
    {'kind': 'STOP', 'city': {'nameAr': 'شندي'}, 'station': {'nameAr': 'موقف شندي'}, 'scheduledAt': _dep.add(const Duration(hours: 3)).toIso8601String()},
    {'kind': 'DESTINATION', 'city': {'nameAr': 'بورتسودان'}, 'station': {'nameAr': 'الموقف السفري'}, 'scheduledAt': _dep.add(const Duration(hours: 12)).toIso8601String()},
  ],
};

final _booking = <String, dynamic>{
  'id': 'b1',
  'bookingRef': 'BK-20261124-VVFRDD',
  'status': 'CONFIRMED',
  'paymentMethod': 'ONLINE',
  'paymentStatus': 'PAID',
  'amounts': {'subtotalMinor': 7000000, 'discountMinor': 0, 'totalMinor': 7000000},
  'trip': _trip,
  'tickets': [
    {'ticketNumber': 'ZG-20261124-2FDEB6', 'status': 'CONFIRMED', 'boardingStatus': 'PENDING', 'seatLabel': '7', 'passenger': {'fullName': 'مروة السوداني', 'gender': 'FEMALE'}, 'fareMinor': 3500000, 'cashToCollectMinor': 0, 'qrPayload': 'ZG1.ZG-20261124-2FDEB6.sig'},
    {'ticketNumber': 'ZG-20261124-2FDEB7', 'status': 'CONFIRMED', 'boardingStatus': 'PENDING', 'seatLabel': '8', 'passenger': {'fullName': 'أحمد محمد', 'gender': 'MALE'}, 'fareMinor': 3500000, 'cashToCollectMinor': 0, 'qrPayload': 'ZG1.ZG-20261124-2FDEB7.sig'},
  ],
  'refunds': [],
  'actions': {'canCancel': true, 'canChangeSeat': true, 'canChangeTrip': true, 'canRate': false, 'canPay': false},
  'createdAt': DateTime.now().toUtc().toIso8601String(),
};

class FakeApi extends CustomerApi {
  FakeApi(super.client);

  @override
  Future<CustomerMe> me() async => CustomerMe({
        'id': 'c1',
        'displayName': 'مروة السوداني',
        'phone': '+249912345678',
        'email': 'marwa@example.com',
        'preferences': {'tripAlerts': true},
        'cash': {'noShowCount': 0, 'noShowLimit': 2, 'eligible': true},
        'stats': {'tripsCount': 12, 'destinationsCount': 4},
      });

  @override
  Future<int> unreadCount() async => 2;

  @override
  Future<List<Json>> recentSearches() async => [
        {'fromCity': _city('krt', 'الخرطوم', 'Khartoum'), 'toCity': _city('pzu', 'بورتسودان', 'Port Sudan'), 'travelDate': sudanDay(_dep), 'passengers': 1},
        {'fromCity': _city('atb', 'عطبرة', 'Atbara'), 'toCity': _city('ksl', 'كسلا', 'Kassala'), 'travelDate': sudanDay(_dep), 'passengers': 2},
      ];

  @override
  Future<List<Destination>> popular() async => [
        Destination({'city': _city('pzu', 'بورتسودان', 'Port Sudan'), 'imageUrl': null, 'fromPriceMinor': 3500000}),
        Destination({'city': _city('ksl', 'كسلا', 'Kassala'), 'imageUrl': null, 'fromPriceMinor': 2200000}),
      ];

  @override
  Future<List<Trip>> searchTrips(Map<String, Object?> query) async =>
      [Trip(_trip), Trip({..._trip, 'id': 't2', 'serviceClass': 'STANDARD', 'priceMinor': 2800000, 'seatsAvailable': 3})];

  @override
  Future<Trip> trip(String id) async => Trip(_trip);

  @override
  Future<SeatMapData> seats(String tripId) async => SeatMapData({
        'layout': {'rows': 7, 'columns': 4, 'aisleAfterColumn': 2, 'driverSide': 'LEFT'},
        'seats': [
          for (var i = 1; i <= 28; i++)
            {'id': 's$i', 'label': '$i', 'row': (i - 1) ~/ 4 + 1, 'column': (i - 1) % 4 + 1, 'isWomenOnly': i == 11 || i == 12, 'state': i % 6 == 0 ? 'SOLD' : 'AVAILABLE', 'heldByMe': false},
        ],
      });

  @override
  Future<Quote> quote(Json body) async => Quote({
        'legs': [
          {'leg': null, 'trip': _trip, 'seats': [{'label': '7'}, {'label': '8'}], 'unitPriceMinor': 3500000, 'subtotalMinor': 7000000, 'discountMinor': 0, 'totalMinor': 7000000},
        ],
        'subtotalMinor': 7000000,
        'discountMinor': 500000,
        'totalMinor': 6500000,
        'cashAllowed': false,
        'cashBlockedReason': 'TOO_CLOSE_TO_DEPARTURE',
      });

  @override
  Future<Paged<Booking>> bookings({required String tab, int page = 1}) async => Paged([Booking(_booking)], 1);

  @override
  Future<Booking> booking(String id) async => Booking(_booking);
}

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
  final cairo = FontLoader('packages/zool_ui/Cairo');
  for (final w in [400, 600, 700, 800]) {
    cairo.addFont(rootBundle.load('packages/zool_ui/assets/fonts/Cairo-$w.ttf'));
  }
  await cairo.load();
  for (final f in ['IconsaxPlusLinear', 'IconsaxPlusBold']) {
    await (FontLoader('packages/iconsax_plus/$f')..addFont(rootBundle.load('packages/iconsax_plus/fonts/$f.ttf'))).load();
  }
  await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

void main() {
  setUpAll(_loadFonts);

  Future<(GoRouter, ProviderContainer)> boot(WidgetTester tester, {bool signedIn = true}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = MemoryTokenStore()..value = signedIn ? 'r1' : null;
    final dio = createDio(baseUrl: 'http://test')..httpClientAdapter = _AuthAdapter();
    final session = AuthSession(authPath: '/customer/auth', store: store, dio: dio);
    await tester.runAsync(session.restore);
    final flags = AppFlags(true);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(session),
        appFlagsProvider.overrideWithValue(flags),
        apiProvider.overrideWith((ref) => FakeApi(ApiClient(session, dio: dio))),
      ],
      child: CustomerApp(session: session, flags: flags),
    ));
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(Navigator).first);
    return (GoRouter.of(element), ProviderScope.containerOf(element));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    if (autoUpdateGoldenFiles) await expectLater(find.byType(MaterialApp), matchesGoldenFile('_screens/$name.png'));
  }

  void search(ProviderContainer c) => c.read(bookingFlowProvider.notifier).setSearch(TripSearchValue(
        from: const SearchCity(id: 'krt', name: 'الخرطوم'),
        to: const SearchCity(id: 'pzu', name: 'بورتسودان'),
        date: DateTime.now().add(const Duration(days: 1)),
        passengers: 2,
      ));

  testWidgets('login', (tester) async {
    await boot(tester, signedIn: false);
    expect(find.text('أدخل رقم هاتفك'), findsOneWidget);
    await shot(tester, 'login');
  });

  testWidgets('home', (tester) async {
    await boot(tester);
    expect(find.text('ابحث عن رحلة'), findsOneWidget);
    await shot(tester, 'home');
  });

  testWidgets('results', (tester) async {
    final (router, c) = await boot(tester);
    search(c);
    router.push('/results/outbound');
    await shot(tester, 'results');
  });

  testWidgets('trip + seats', (tester) async {
    final (router, c) = await boot(tester);
    search(c);
    router.push('/trip/outbound/t1');
    await shot(tester, 'trip');
    router.push('/seats/outbound/t1');
    await shot(tester, 'seats');
  });

  testWidgets('review', (tester) async {
    final (router, c) = await boot(tester);
    search(c);
    final seats = (await FakeApi(ApiClient(c.read(sessionProvider))).seats('t1')).seats;
    c.read(bookingFlowProvider.notifier).setLeg(
          isReturn: false,
          selection: LegSelection(trip: Trip(_trip), seats: seats.sublist(6, 8), holdIds: const ['h1', 'h2'], expiresAt: DateTime.now().add(const Duration(minutes: 14))),
        );
    c.read(bookingFlowProvider.notifier).setPassenger(0, const PassengerDraft(fullName: 'مروة السوداني', gender: 'FEMALE'));
    c.read(bookingFlowProvider.notifier).setPassenger(1, const PassengerDraft(fullName: 'أحمد محمد', gender: 'MALE'));
    router.push('/passengers');
    await shot(tester, 'passengers');
    router.push('/review');
    await shot(tester, 'review');
  });

  testWidgets('my trips + booking + ticket', (tester) async {
    final (router, _) = await boot(tester);
    router.go('/trips');
    await shot(tester, 'trips');
    router.push('/booking/b1');
    await shot(tester, 'booking');
    router.push('/booking/b1/ticket/ZG-20261124-2FDEB6');
    await shot(tester, 'ticket');
  });

  testWidgets('more', (tester) async {
    final (router, _) = await boot(tester);
    router.go('/more');
    await shot(tester, 'more');
  });
}
