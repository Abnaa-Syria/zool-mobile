import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_push/zool_push.dart';
import 'package:zool_ui/zool_ui.dart';

import 'app/providers.dart';
import 'app/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final session = AuthSession(authPath: '/broker/auth', store: SecureTokenStore('zoolgo.broker.refresh'));
  final push = ZoolPush(app: ZoolApp.broker, client: ApiClient(session), devicesPath: '/broker/devices');
  await push.init();
  push.bind(session);
  session.restore();
  runApp(
    ProviderScope(
      // Errors are shown with a retry button; no silent automatic retries.
      retry: (_, _) => null,
      overrides: [sessionProvider.overrideWithValue(session)],
      child: BrokerApp(session: session, push: push),
    ),
  );
}

class BrokerApp extends StatefulWidget {
  const BrokerApp({super.key, required this.session, required this.push});

  final AuthSession session;
  final ZoolPush push;

  @override
  State<BrokerApp> createState() => _BrokerAppState();
}

class _BrokerAppState extends State<BrokerApp> with PushRouting {
  late final GoRouter _router = buildRouter(widget.session);

  @override
  void initState() {
    super.initState();
    listenPush(
      widget.push,
      open: (n) => _router.push(n.data['bookingId'] != null ? '/booking/${n.data['bookingId']}' : '/notifications'),
      onMessage: () => ProviderScope.containerOf(context, listen: false).invalidate(unreadCountProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ZoolGo Broker',
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
