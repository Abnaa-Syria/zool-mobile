import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_push/zool_push.dart';
import 'package:zool_ui/zool_ui.dart';

import 'app/providers.dart';
import 'app/router.dart';

const kOnboardingSeenKey = 'zoolgo.customer.onboardingSeen';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  var seen = false;
  try {
    seen = (await SharedPreferences.getInstance()).getBool(kOnboardingSeenKey) ?? false;
  } catch (_) {}
  final session = AuthSession(authPath: '/customer/auth', store: SecureTokenStore('zoolgo.customer.refresh'));
  final flags = AppFlags(seen);
  final push = ZoolPush(app: ZoolApp.customer, client: ApiClient(session), devicesPath: '/customer/devices');
  await push.init();
  push.bind(session);
  session.restore();
  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [sessionProvider.overrideWithValue(session), appFlagsProvider.overrideWithValue(flags)],
      child: CustomerApp(session: session, flags: flags, push: push),
    ),
  );
}

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key, required this.session, required this.flags, required this.push});

  final AuthSession session;
  final AppFlags flags;
  final ZoolPush push;

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> with PushRouting {
  late final GoRouter _router = buildRouter(widget.session, widget.flags);

  @override
  void initState() {
    super.initState();
    listenPush(
      widget.push,
      // Booking notices open the booking (ticket, tracking, rating); the rest the feed tab.
      open: (n) => n.data['bookingId'] != null ? _router.push('/booking/${n.data['bookingId']}') : _router.go('/notifications'),
      onMessage: () => ProviderScope.containerOf(context, listen: false).invalidate(unreadCountProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ZoolGo',
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
