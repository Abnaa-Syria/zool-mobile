import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zool_core/zool_core.dart';
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
  session.restore();
  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [sessionProvider.overrideWithValue(session), appFlagsProvider.overrideWithValue(flags)],
      child: CustomerApp(session: session, flags: flags),
    ),
  );
}

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key, required this.session, required this.flags});

  final AuthSession session;
  final AppFlags flags;

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  late final GoRouter _router = buildRouter(widget.session, widget.flags);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ZoolGo',
      debugShowCheckedModeBanner: false,
      theme: zoolTheme(),
      locale: kZoolLocale,
      supportedLocales: const [kZoolLocale],
      localizationsDelegates: kZoolLocalizationsDelegates,
      routerConfig: _router,
    );
  }
}
