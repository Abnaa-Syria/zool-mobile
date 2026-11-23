import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import 'app/providers.dart';
import 'app/router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final session = AuthSession(authPath: '/broker/auth', store: SecureTokenStore('zoolgo.broker.refresh'));
  session.restore();
  runApp(
    ProviderScope(
      // Errors are shown with a retry button; no silent automatic retries.
      retry: (_, _) => null,
      overrides: [sessionProvider.overrideWithValue(session)],
      child: BrokerApp(session: session),
    ),
  );
}

class BrokerApp extends StatefulWidget {
  const BrokerApp({super.key, required this.session});

  final AuthSession session;

  @override
  State<BrokerApp> createState() => _BrokerAppState();
}

class _BrokerAppState extends State<BrokerApp> {
  late final GoRouter _router = buildRouter(widget.session);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'زول قو — الوكيل',
      debugShowCheckedModeBanner: false,
      theme: zoolTheme(),
      locale: kZoolLocale,
      supportedLocales: const [kZoolLocale],
      localizationsDelegates: kZoolLocalizationsDelegates,
      routerConfig: _router,
    );
  }
}
