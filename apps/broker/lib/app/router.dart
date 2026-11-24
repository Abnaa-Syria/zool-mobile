import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../features/auth/login_page.dart';
import '../features/booking/passengers_page.dart';
import '../features/booking/results_page.dart';
import '../features/booking/review_page.dart';
import '../features/booking/search_page.dart';
import '../features/booking/seats_page.dart';
import '../features/booking/success_page.dart';
import '../features/booking/trip_detail_page.dart';
import '../features/bookings/booking_detail_page.dart';
import '../features/bookings/bookings_page.dart';
import '../features/bookings/change_trip_page.dart';
import '../features/bookings/ticket_page.dart';
import '../features/home/home_page.dart';
import '../features/more/commissions_page.dart';
import '../features/more/more_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/wallet/top_up_pages.dart';
import '../features/wallet/wallet_page.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Routes. Tabs live in a [StatefulShellRoute]; detail and flow screens cover the tab bar.
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
          return loc == '/login' || loc == '/splash' ? '/' : null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: ZoolWordmark()))),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => BrokerShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomePage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/book', builder: (_, _) => const SearchPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/bookings', builder: (_, _) => const BookingsPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/more', builder: (_, _) => const MorePage())]),
        ],
      ),
      // New booking flow after the search tab (state in bookingFlowProvider).
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/book/trip/:leg/:tripId',
        builder: (_, s) => TripDetailPage(tripId: s.pathParameters['tripId']!, isReturn: s.pathParameters['leg'] == 'return'),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/book/results/:leg',
        builder: (_, s) => ResultsPage(isReturn: s.pathParameters['leg'] == 'return'),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/book/seats/:leg/:tripId',
        builder: (_, s) => SeatsPage(tripId: s.pathParameters['tripId']!, isReturn: s.pathParameters['leg'] == 'return'),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/book/passengers', builder: (_, _) => const PassengersPage()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/book/review', builder: (_, _) => const ReviewPage()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/book/done/:bookingId',
        builder: (_, s) => SuccessPage(bookingId: s.pathParameters['bookingId']!, returnBookingId: s.uri.queryParameters['return']),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/booking/:id',
        builder: (_, s) => BookingDetailPage(bookingId: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/booking/:id/ticket/:ticket',
        builder: (_, s) => TicketPage(bookingId: s.pathParameters['id']!, ticketNumber: s.pathParameters['ticket']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/booking/:id/change-trip',
        builder: (_, s) => ChangeTripPage(bookingId: s.pathParameters['id']!),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/wallet', builder: (_, _) => const WalletPage()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/top-up/new', builder: (_, _) => const NewTopUpPage()),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/top-up/:id',
        builder: (_, s) => TopUpDetailPage(topUpId: s.pathParameters['id']!),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/notifications', builder: (_, _) => const NotificationsPage()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/commissions', builder: (_, _) => const CommissionsPage()),
    ],
  );
}
