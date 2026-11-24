import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';

import '../features/auth/login_page.dart';
import '../features/auth/name_page.dart';
import '../features/auth/onboarding_page.dart';
import '../features/auth/splash_page.dart';
import '../features/booking/passengers_page.dart';
import '../features/booking/payment_page.dart';
import '../features/booking/results_page.dart';
import '../features/booking/review_page.dart';
import '../features/booking/seats_page.dart';
import '../features/booking/trip_detail_page.dart';
import '../features/home/home_page.dart';
import '../features/more/content_page.dart';
import '../features/more/more_page.dart';
import '../features/more/payment_methods_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/trips/booking_page.dart';
import '../features/trips/change_trip_page.dart';
import '../features/trips/live_page.dart';
import '../features/trips/ticket_page.dart';
import '../features/trips/trips_page.dart';
import 'providers.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

const _public = {'/splash', '/onboarding', '/login'};

GoRouter buildRouter(AuthSession session, AppFlags flags) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: Listenable.merge([session, flags]),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      switch (session.status) {
        case AuthStatus.unknown:
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.signedOut:
          final entry = flags.onboardingSeen ? '/login' : '/onboarding';
          return loc == '/login' || loc == '/onboarding' ? null : entry;
        case AuthStatus.signedIn:
          if (flags.needsName) return loc == '/welcome' ? null : '/welcome';
          return _public.contains(loc) || loc == '/welcome' ? '/' : null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/welcome', builder: (_, _) => const NamePage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => CustomerShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomePage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/trips', builder: (_, _) => const TripsPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/notifications', builder: (_, _) => const NotificationsPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/more', builder: (_, _) => const MorePage())]),
        ],
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/results/:leg', builder: (_, s) => ResultsPage(isReturn: s.pathParameters['leg'] == 'return')),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/trip/:leg/:id',
        builder: (_, s) => TripDetailPage(tripId: s.pathParameters['id']!, isReturn: s.pathParameters['leg'] == 'return'),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/seats/:leg/:id',
        builder: (_, s) => SeatsPage(tripId: s.pathParameters['id']!, isReturn: s.pathParameters['leg'] == 'return'),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/passengers', builder: (_, _) => const PassengersPage()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/review', builder: (_, _) => const ReviewPage()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/payment/:intentId',
        builder: (_, s) => PaymentPage(intentId: s.pathParameters['intentId']!, bookingId: s.uri.queryParameters['booking']),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/done/:bookingId', builder: (_, s) => BookingDonePage(bookingId: s.pathParameters['bookingId']!)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/booking/:id', builder: (_, s) => BookingPage(bookingId: s.pathParameters['id']!)),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/booking/:id/ticket/:ticket',
        builder: (_, s) => TicketPage(bookingId: s.pathParameters['id']!, ticketNumber: s.pathParameters['ticket']!),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/booking/:id/live', builder: (_, s) => LivePage(bookingId: s.pathParameters['id']!)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/booking/:id/change-trip', builder: (_, s) => ChangeTripPage(bookingId: s.pathParameters['id']!)),
      GoRoute(parentNavigatorKey: _rootKey, path: '/payment-methods', builder: (_, _) => const PaymentMethodsPage()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/content/:slug', builder: (_, s) => ContentPage(slug: s.pathParameters['slug']!)),
    ],
  );
}
