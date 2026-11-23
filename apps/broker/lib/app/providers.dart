import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:zool_core/zool_core.dart';

import '../data/broker_api.dart';
import '../data/models.dart';

/// The broker session (`/broker/auth`). Overridden in main() so it can be restored before runApp.
final sessionProvider = Provider<AuthSession>((ref) => throw UnimplementedError('sessionProvider is overridden in main()'));

final apiProvider = Provider<BrokerApi>((ref) => BrokerApi(ApiClient(ref.watch(sessionProvider))));

/// Signed-in employee: office, role, permissions.
final meProvider = FutureProvider<BrokerMe>((ref) => ref.watch(apiProvider).me());

final dashboardProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(apiProvider).dashboard());

final walletProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(apiProvider).wallet());

final citiesProvider = FutureProvider<List<City>>((ref) => ref.watch(apiProvider).cities());

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(apiProvider).unreadCount());

final bookingProvider = FutureProvider.autoDispose.family<Booking, String>((ref, id) => ref.watch(apiProvider).booking(id));

final tripProvider = FutureProvider.autoDispose.family<BrokerTrip, String>((ref, id) => ref.watch(apiProvider).trip(id));

final topUpProvider = FutureProvider.autoDispose.family<TopUp, String>((ref, id) => ref.watch(apiProvider).topUp(id));

/// Bumped after a booking, cancel, change or top-up; lists watch it to reload.
final bookingsVersionProvider = StateProvider<int>((ref) => 0);

/// After a booking, cancel, change or top-up: refresh everything that shows money or bookings.
void refreshMoney(WidgetRef ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(walletProvider);
  ref.read(bookingsVersionProvider.notifier).state++;
}
