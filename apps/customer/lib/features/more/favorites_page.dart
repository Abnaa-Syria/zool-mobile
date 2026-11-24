import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import '../home/suggested_trip_card.dart';

final favoritesProvider = FutureProvider.autoDispose<List<Trip>>((ref) => ref.watch(apiProvider).favorites());

/// «المفضلة»: trips saved with the heart on the home suggestions.
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    return ZoolPage(
      title: 'المفضلة',
      body: AsyncBody(
        value: favorites,
        onRetry: () => ref.invalidate(favoritesProvider),
        data: (list) => list.isEmpty
            ? EmptyView(
                title: 'لا توجد رحلات في المفضلة',
                message: 'اضغط على القلب في «رحلات مقترحة لك» لحفظ الرحلة هنا.',
                icon: IconsaxPlusLinear.heart,
                action: OutlinedButton(onPressed: () => context.go('/'), style: OutlinedButton.styleFrom(minimumSize: const Size(180, 44)), child: const Text('الرئيسية')),
              )
            : RefreshIndicator(
                color: ZoolColors.brand,
                onRefresh: () => ref.refresh(favoritesProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 28),
                  itemBuilder: (_, i) => SuggestedTripCard(
                    key: ValueKey(list[i].id),
                    trip: list[i],
                    onFavoriteChanged: (on) {
                      if (!on) ref.invalidate(favoritesProvider);
                    },
                  ),
                ),
              ),
      ),
    );
  }
}
