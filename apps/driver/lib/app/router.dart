import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';

import '../features/auth/login_page.dart';
import '../features/auth/splash_page.dart';
import '../features/boarding/boarding_page.dart';
import '../features/boarding/cash_page.dart';
import '../features/home/home_page.dart';
import '../features/more/notifications_page.dart';
import '../features/more/profile_page.dart';
import '../features/scan/scan_page.dart';
import '../features/trips/trip_detail_page.dart';
import '../features/trips/trips_page.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

const _public = {'/splash', '/login'};

GoRouter buildRouter(AuthSession session) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      switch (session.status) {
        case AuthStatus.unknown:
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.signedOut:
          return loc == '/login' ? null : '/login';
        case AuthStatus.signedIn:
          return _public.contains(loc) ? '/' : null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => DriverShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomePage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/trips', builder: (_, _) => const TripsPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/scan', builder: (_, _) => const ScanTab())]),
          StatefulShellBranch(routes: [GoRoute(path: '/more', builder: (_, _) => const ProfilePage())]),
        ],
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/trip/:id', builder: (_, s) => TripDetailPage(tripId: s.pathParameters['id']!)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/trip/:id/passengers', builder: (_, s) => BoardingPage(tripId: s.pathParameters['id']!)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/trip/:id/scan', builder: (_, s) => ScanPage(tripId: s.pathParameters['id']!)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/trip/:id/cash', builder: (_, s) => CashPage(tripId: s.pathParameters['id']!)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/notifications', builder: (_, _) => const NotificationsPage()),
    ],
  );
}
