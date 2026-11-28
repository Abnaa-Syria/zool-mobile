import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:zool_core/zool_core.dart';

import '../data/driver_api.dart';
import '../data/models.dart';
import '../features/gps/gps_tracker.dart';

/// The driver session (`/driver/auth`). Overridden in main().
final sessionProvider = Provider<AuthSession>((ref) => throw UnimplementedError('overridden in main()'));

final apiProvider = Provider<DriverApi>((ref) => DriverApi(ApiClient(ref.watch(sessionProvider))));

/// GPS sender for the live trip. Overridden in main() (tests use a disabled one).
final gpsProvider = Provider<GpsTracker>((ref) => throw UnimplementedError('overridden in main()'));

final meProvider = FutureProvider<DriverMe>((ref) => ref.watch(apiProvider).me());

final dashboardProvider = FutureProvider.autoDispose<DriverDashboard>((ref) {
  ref.watch(tripsVersionProvider);
  return ref.watch(apiProvider).dashboard();
});

final tripProvider = FutureProvider.autoDispose.family<DriverTrip, String>((ref, id) {
  ref.watch(tripsVersionProvider);
  return ref.watch(apiProvider).trip(id);
});

final manifestProvider = FutureProvider.autoDispose.family<Manifest, String>((ref, id) {
  ref.watch(tripsVersionProvider);
  return ref.watch(apiProvider).manifest(id);
});

final cashProvider = FutureProvider.autoDispose.family<CashSummary, String>((ref, id) {
  ref.watch(tripsVersionProvider);
  return ref.watch(apiProvider).cash(id);
});

/// Map tiles from the app config; OpenStreetMap when the config cannot be loaded.
final mapTilesProvider = FutureProvider<MapTiles>((ref) async {
  try {
    return MapTiles.fromAppConfig(await ref.watch(apiProvider).appConfig());
  } catch (_) {
    return MapTiles.osm;
  }
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(apiProvider).unreadCount());

/// Bumped after a status change, boarding, no-show or stop event; screens watch it to reload.
final tripsVersionProvider = StateProvider<int>((ref) => 0);

void tripsChanged(WidgetRef ref) => ref.read(tripsVersionProvider.notifier).state++;
