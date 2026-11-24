import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
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
  // Signing out stops the GPS of the trip.
  session.addListener(() {
    if (session.status == AuthStatus.signedOut) gps.stop();
  });
  session.restore();
  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [sessionProvider.overrideWithValue(session), apiProvider.overrideWithValue(api), gpsProvider.overrideWithValue(gps)],
      child: DriverApp(session: session),
    ),
  );
}

class DriverApp extends StatefulWidget {
  const DriverApp({super.key, required this.session});

  final AuthSession session;

  @override
  State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> {
  late final GoRouter _router = buildRouter(widget.session);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'زول قو — السائق',
      debugShowCheckedModeBanner: false,
      theme: zoolTheme(),
      locale: kZoolLocale,
      supportedLocales: const [kZoolLocale],
      localizationsDelegates: kZoolLocalizationsDelegates,
      routerConfig: _router,
    );
  }
}
