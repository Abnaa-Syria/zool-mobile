import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../data/customer_api.dart';
import '../data/models.dart';

/// The customer session (`/customer/auth`). Overridden in main().
final sessionProvider = Provider<AuthSession>((ref) => throw UnimplementedError('overridden in main()'));

/// App-start flags the router reads (onboarding seen, name step pending).
class AppFlags extends ChangeNotifier {
  AppFlags(this._onboardingSeen);

  bool _onboardingSeen;
  bool _needsName = false;

  bool get onboardingSeen => _onboardingSeen;
  bool get needsName => _needsName;

  set onboardingSeen(bool v) {
    _onboardingSeen = v;
    notifyListeners();
  }

  set needsName(bool v) {
    _needsName = v;
    notifyListeners();
  }
}

final appFlagsProvider = Provider<AppFlags>((ref) => throw UnimplementedError('overridden in main()'));

final apiProvider = Provider<CustomerApi>((ref) => CustomerApi(ApiClient(ref.watch(sessionProvider))));

final meProvider = FutureProvider<CustomerMe>((ref) => ref.watch(apiProvider).me());

final appConfigProvider = FutureProvider<Json>((ref) => ref.watch(apiProvider).appConfig());

/// Map tiles from the app config; OpenStreetMap when the config cannot be loaded.
final mapTilesProvider = FutureProvider<MapTiles>((ref) async {
  try {
    return MapTiles.fromAppConfig(await ref.watch(appConfigProvider.future));
  } catch (_) {
    return MapTiles.osm;
  }
});

final citiesProvider = FutureProvider<List<SearchCity>>((ref) async => (await ref.watch(apiProvider).cities()).map(SearchCity.fromJson).toList());

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(apiProvider).unreadCount());

final bookingProvider = FutureProvider.autoDispose.family<Booking, String>((ref, id) => ref.watch(apiProvider).booking(id));

final tripProvider = FutureProvider.autoDispose.family<Trip, String>((ref, id) => ref.watch(apiProvider).trip(id));

final seatsProvider = FutureProvider.autoDispose.family<SeatMapData, String>((ref, id) => ref.watch(apiProvider).seats(id));

/// Bumped after a booking, payment, cancel or change; lists watch it to reload.
final bookingsVersionProvider = StateProvider<int>((ref) => 0);

void bookingsChanged(WidgetRef ref) {
  ref.read(bookingsVersionProvider.notifier).state++;
  ref.invalidate(meProvider);
}
