// Renders the driver screens with the real fonts and canned data; fails on any layout overflow.
// Review screenshots (not committed): flutter test test/screens_test.dart --update-goldens → test/_screens/
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:driver/app/providers.dart';
import 'package:driver/data/driver_api.dart';
import 'package:driver/data/models.dart';
import 'package:driver/features/gps/gps_tracker.dart';
import 'package:driver/features/scan/scan_page.dart';
import 'package:driver/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_push/zool_push.dart';

final _dep = DateTime.now().toUtc().add(const Duration(hours: 2));

Json _city(String id, String ar, String en) => {'id': id, 'code': id.toUpperCase(), 'nameAr': ar, 'nameEn': en};

Json _trip({String id = 't1', String status = 'BOARDING', int boarded = 12}) => {
      'id': id,
      'tripNumber': 'KRT-MRW-0830',
      'status': status,
      'carrier': {'id': 'c1', 'name': 'شركة النيل للنقل', 'legalName': 'شركة النيل للنقل البري', 'logoUrl': null},
      'serviceClass': 'VIP',
      'departureAt': _dep.toIso8601String(),
      'arrivalAt': _dep.add(const Duration(hours: 5, minutes: 30)).toIso8601String(),
      'durationMinutes': 330,
      'origin': {'station': {'nameAr': 'الميناء البري'}, 'city': _city('krt', 'الخرطوم', 'Khartoum')},
      'destination': {'station': {'nameAr': 'موقف مروي'}, 'city': _city('mrw', 'مروي', 'Merowe')},
      'stopsCount': 2,
      'seatsAvailable': 7,
      'seatsTotal': 25,
      'vehicleModel': 'Toyota Coaster',
      'vehicle': {'id': 'v1', 'plateNumber': 'خ ر ط - 1234', 'model': 'Toyota Coaster'},
      'stops': [
        {'sequence': 0, 'kind': 'ORIGIN', 'city': {'nameAr': 'الخرطوم'}, 'station': {'nameAr': 'الميناء البري'}, 'scheduledAt': _dep.toIso8601String()},
        {'id': 's1', 'sequence': 1, 'kind': 'STOP', 'city': {'nameAr': 'شندي'}, 'station': {'nameAr': 'موقف شندي'}, 'scheduledAt': _dep.add(const Duration(hours: 3)).toIso8601String(), 'arrivedAt': null, 'departedAt': null},
        {'id': 's2', 'sequence': 2, 'kind': 'STOP', 'city': {'nameAr': 'البجراوية'}, 'station': {'nameAr': 'البجراوية'}, 'scheduledAt': _dep.add(const Duration(hours: 4)).toIso8601String(), 'arrivedAt': null, 'departedAt': null},
        {'sequence': 3, 'kind': 'DESTINATION', 'city': {'nameAr': 'مروي'}, 'station': {'nameAr': 'موقف مروي'}, 'scheduledAt': _dep.add(const Duration(hours: 5, minutes: 30)).toIso8601String()},
      ],
      'counts': {'booked': 18, 'boarded': boarded, 'noShow': 0},
      'cash': {'expectedMinor': 7000000, 'collectedMinor': 3500000},
      'allowedTransitions': switch (status) { 'SCHEDULED' => ['BOARDING', 'IN_PROGRESS'], 'BOARDING' => ['IN_PROGRESS'], 'IN_PROGRESS' => ['COMPLETED'], _ => <String>[] },
      'startedAt': null,
      'completedAt': null,
      'live': null,
    };

Json _pax(String seat, String name, String status, {int cash = 0}) => {
      'ticketNumber': 'ZG-20261124-$seat',
      'seatLabel': seat,
      'isWomenOnlySeat': false,
      'passenger': {'fullName': name, 'phone': '+249912000999', 'gender': 'MALE'},
      'ticketStatus': 'CONFIRMED',
      'boardingStatus': status,
      'boardingMethod': status == 'BOARDED' ? 'QR' : null,
      'boardedAt': status == 'BOARDED' ? DateTime.now().toUtc().toIso8601String() : null,
      'bookingRef': 'BK-20261124-8PXK46',
      'channel': 'DIRECT',
      'soldBy': null,
      'paymentMethod': cash > 0 ? 'CASH_ON_BOARD' : 'ONLINE',
      'fareMinor': 3500000,
      'cashToCollectMinor': cash,
      'cashCollectedMinor': 0,
    };

final _manifest = [
  _pax('12A', 'محمد أحمد علي', 'BOARDED'),
  _pax('12B', 'فاطمة محمد سليمان', 'PENDING', cash: 3500000),
  _pax('14A', 'عمر عثمان الطاهر', 'BOARDED'),
  _pax('14B', 'زينب عوض عبد الله', 'PENDING'),
  _pax('15A', 'أحمد الطيب مصطفى', 'PENDING'),
];

class FakeApi extends DriverApi {
  FakeApi(super.client);

  @override
  Future<DriverMe> me() async => DriverMe({
        'id': 'd1',
        'driverCode': 'ZGD-7649',
        'displayName': 'أحمد محمد سليمان',
        'phone': '+249912345678',
        'company': {'id': 'c1', 'name': 'شركة النيل للنقل', 'legalName': 'شركة نقل مرخصة', 'logoUrl': null},
        'license': {'number': 'DL-7649', 'expiry': '2027-12-31', 'status': 'VALID'},
      });

  @override
  Future<int> unreadCount() async => 1;

  @override
  Future<DriverDashboard> dashboard() async => DriverDashboard({
        'kpis': {'tripsToday': 5, 'bookedSeatsToday': 42, 'boardedToday': 12},
        'currentTrip': _trip(status: 'IN_PROGRESS', boarded: 18),
        'nextTrip': null,
        'todayTrips': [_trip(status: 'IN_PROGRESS', boarded: 18), _trip(id: 't2', status: 'SCHEDULED', boarded: 0), _trip(id: 't3', status: 'SCHEDULED', boarded: 0)],
      });

  @override
  Future<Paged<DriverTrip>> trips({required String tab, int page = 1}) async =>
      Paged(tab == 'CURRENT' ? [DriverTrip(_trip(status: 'IN_PROGRESS'))] : const [], 1);

  @override
  Future<DriverTrip> trip(String id) async => DriverTrip(_trip(status: id == 't2' ? 'IN_PROGRESS' : 'BOARDING'));

  @override
  Future<Manifest> manifest(String tripId) async => Manifest({
        'status': 'BOARDING',
        'counts': {'booked': 5, 'boarded': 2, 'pending': 3, 'noShow': 0},
        'passengers': _manifest,
      });

  @override
  Future<CashSummary> cash(String tripId) async => CashSummary({
        'expectedMinor': 7000000,
        'collectedMinor': 3500000,
        'outstandingMinor': 3500000,
        'tickets': [
          {'ticketNumber': 'ZG-20261124-12B', 'seatLabel': '12B', 'passenger': 'فاطمة محمد سليمان', 'fareMinor': 3500000, 'collectedMinor': 0, 'boardingStatus': 'PENDING'},
          {'ticketNumber': 'ZG-20261124-16A', 'seatLabel': '16A', 'passenger': 'خالد يوسف', 'fareMinor': 3500000, 'collectedMinor': 3500000, 'boardingStatus': 'BOARDED'},
        ],
      });

  @override
  Future<Paged<AppNotification>> notifications({int page = 1}) async => Paged([
        AppNotification({'id': 'n1', 'type': 'TRIP_ASSIGNED', 'title': 'رحلة جديدة', 'body': 'أُسندت إليك رحلة الخرطوم ← مروي غدًا 08:30 ص', 'isRead': false, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'data': {'tripId': 't1'}}),
      ], 1);
}

void main() {
  setUpAll(_loadFonts);

  Future<(GoRouter, ProviderContainer)> boot(WidgetTester tester, {bool signedIn = true}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = MemoryTokenStore()..value = signedIn ? 'r1' : null;
    final dio = createDio(baseUrl: 'http://test')..httpClientAdapter = _AuthAdapter();
    final session = AuthSession(authPath: '/driver/auth', store: store, dio: dio);
    await tester.runAsync(session.restore);
    final api = FakeApi(ApiClient(session, dio: dio));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(session),
        apiProvider.overrideWithValue(api),
        gpsProvider.overrideWithValue(GpsTracker(send: (_, _) async {}, enabled: false)),
      ],
      child: DriverApp(session: session, push: ZoolPush(app: ZoolApp.driver, client: ApiClient(session), devicesPath: '/driver/devices')),
    ));
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(Navigator).first);
    return (GoRouter.of(element), ProviderScope.containerOf(element));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    if (autoUpdateGoldenFiles) await expectLater(find.byType(MaterialApp), matchesGoldenFile('_screens/$name.png'));
  }

  testWidgets('login', (tester) async {
    await boot(tester, signedIn: false);
    expect(find.text('تطبيق السائق'), findsOneWidget);
    await shot(tester, 'login');
  });

  testWidgets('home', (tester) async {
    await boot(tester);
    expect(find.text('الرحلة الحالية'), findsOneWidget);
    expect(find.text('في الطريق'), findsWidgets);
    expect(find.text('5 رحلات'), findsOneWidget);
    await shot(tester, 'home');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shot(tester, 'home_lower');
  });

  testWidgets('trips list', (tester) async {
    final (router, _) = await boot(tester);
    router.go('/trips');
    await shot(tester, 'trips');
    expect(find.text('18 / 25 مقعد'), findsOneWidget);
  });

  testWidgets('trip detail (boarding) + in progress', (tester) async {
    final (router, _) = await boot(tester);
    router.push('/trip/t1');
    await shot(tester, 'trip_boarding');
    expect(find.text('انطلاق الرحلة'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shot(tester, 'trip_boarding_lower');
    router.push('/trip/t2');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await shot(tester, 'trip_in_progress');
    expect(find.text('وصلت المحطة'), findsOneWidget);
  });

  testWidgets('passengers + passenger sheet', (tester) async {
    final (router, _) = await boot(tester);
    router.push('/trip/t1/passengers');
    await shot(tester, 'passengers');
    expect(find.text('2 / 5 صعدوا الباص'), findsOneWidget);
    await tester.tap(find.text('فاطمة محمد سليمان'));
    await shot(tester, 'passenger_sheet');
    expect(find.textContaining('وتسجيل الصعود'), findsOneWidget);
  });

  testWidgets('scan results', (tester) async {
    final (router, _) = await boot(tester);
    router.go('/scan');
    await shot(tester, 'scan_tab');
    final ctx = tester.element(find.byType(Navigator).first);
    for (final (name, result, ticket) in [
      ('scan_valid', 'VALID', _pax('08B', 'عبد الرحمن يوسف علي', 'PENDING')),
      ('scan_cash', 'VALID', _pax('08B', 'عبد الرحمن يوسف علي', 'PENDING', cash: 3500000)),
      ('scan_already', 'ALREADY_BOARDED', _pax('08B', 'عبد الرحمن يوسف علي', 'BOARDED')),
      ('scan_invalid', 'INVALID', null),
    ]) {
      showModalBottomSheet(
        context: ctx,
        builder: (_) => ScanResultSheet(
          tripId: 't1',
          result: ScanResult({
            'result': result,
            'ticket': ticket,
            'trip': {'id': 't1', 'tripNumber': 'KRT-MRW', 'departureAt': _dep.toIso8601String(), 'origin': 'الخرطوم', 'destination': 'مروي'},
          }),
        ),
      );
      await shot(tester, name);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('cash + profile + notifications', (tester) async {
    final (router, _) = await boot(tester);
    router.push('/trip/t1/cash');
    await shot(tester, 'cash');
    router.pop();
    router.go('/more');
    await shot(tester, 'profile');
    expect(find.text('سارية'), findsOneWidget);
    router.push('/notifications');
    await shot(tester, 'notifications');
  });
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
