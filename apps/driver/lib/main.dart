import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_push/zool_push.dart';
import 'package:zool_ui/zool_ui.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'data/driver_api.dart';
import 'features/gps/gps_tracker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final session = AuthSession(authPath: '/driver/auth', store: SecureTokenStore('zoolgo.driver.refresh'));
  final api = DriverApi(ApiClient(session));
  final gps = GpsTracker(send: (tripId, points) => api.positions(tripId, points));
  final push = ZoolPush(app: ZoolApp.driver, client: ApiClient(session), devicesPath: '/driver/devices');
  await push.init();
  push.bind(session);
  // Signing out stops the GPS of the trip.
  session.addListener(() {
    if (session.status == AuthStatus.signedOut) gps.stop();
  });
  session.restore();
  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [sessionProvider.overrideWithValue(session), apiProvider.overrideWithValue(api), gpsProvider.overrideWithValue(gps)],
      child: DriverApp(session: session, push: push),
    ),
  );
}

class DriverApp extends StatefulWidget {
  const DriverApp({super.key, required this.session, required this.push});

  final AuthSession session;
  final ZoolPush push;

  @override
  State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> with PushRouting {
  late final GoRouter _router = buildRouter(widget.session);

  @override
  void initState() {
    super.initState();
    listenPush(
      widget.push,
      // Trip notices open the trip (a trip handed to another driver is no longer viewable).
      open: (n) {
        final tripId = n.data['tripId'];
        _router.push(tripId != null && n.type != 'TRIP_UNASSIGNED' ? '/trip/$tripId' : '/notifications');
        _refresh();
      },
      onMessage: _refresh,
    );
  }

  void _refresh() {
    final c = ProviderScope.containerOf(context, listen: false);
    c.invalidate(unreadCountProvider);
    c.read(tripsVersionProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ZoolGo Driver',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: pushMessenger,
      theme: zoolTheme(),
      locale: kZoolLocale,
      supportedLocales: const [kZoolLocale],
      localizationsDelegates: kZoolLocalizationsDelegates,
      routerConfig: _router,
    );
  }
}
