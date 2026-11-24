import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import '../booking/flow.dart';

final _recentProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(apiProvider).recentSearches());
final _popularProvider = FutureProvider.autoDispose<List<Destination>>((ref) => ref.watch(apiProvider).popular());

/// Home (Figma 3074:2225): greeting + bell, search card, recent searches, popular destinations.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _card = GlobalKey<TripSearchCardState>();

  void _search(TripSearchValue v) {
    ref.read(bookingFlowProvider.notifier).setSearch(v);
    context.push('/results/outbound');
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    final flow = ref.read(bookingFlowProvider);
    return ZoolPage(
      header: CustomerGreeting(name: me?.displayName),
      body: RefreshIndicator(
        color: ZoolColors.brand,
        onRefresh: () async {
          ref.invalidate(_recentProvider);
          ref.invalidate(_popularProvider);
          ref.invalidate(unreadCountProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            const Text('إلى أين ستسافر اليوم؟', style: TextStyle(fontSize: 13, color: ZoolColors.textSecondary)),
            const SizedBox(height: 12),
            TripSearchCard(
              key: _card,
              initialFrom: flow.search?.from,
              initialTo: flow.search?.to,
              initialDate: flow.search?.date,
              initialPassengers: flow.search?.passengers ?? 1,
              initialRoundTrip: flow.search?.roundTrip ?? false,
              initialReturnDate: flow.search?.returnDate,
              loadCities: () => ref.read(citiesProvider.future),
              onSearch: _search,
            ),
            const SizedBox(height: 24),
            _Recent(onPick: (from, to, date, pax) => _card.currentState?.fill(from: from, to: to, date: date, passengers: pax)),
            _Popular(onPick: (to) => _card.currentState?.fill(to: to)),
          ],
        ),
      ),
    );
  }
}

/// Avatar · «أهلاً، …» · bell with the unread dot.
class CustomerGreeting extends ConsumerWidget {
  const CustomerGreeting({super.key, required this.name});

  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return GreetingHeader(
      name: name ?? '',
      subtitle: 'زول قو — رحلاتك بين مدن السودان',
      unread: unread > 0,
      onBell: () => context.go('/notifications'),
    );
  }
}

class _Recent extends ConsumerWidget {
  const _Recent({required this.onPick});

  final void Function(SearchCity from, SearchCity to, DateTime? date, int passengers) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_recentProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('عمليات البحث الأخيرة'),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final r = items[i];
              final from = SearchCity.fromJson(r.obj('fromCity'));
              final to = SearchCity.fromJson(r.obj('toCity'));
              final date = parseDayKey(r.strOrNull('travelDate'));
              return SizedBox(
                width: 170,
                child: ZoolCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => onPick(from, to, date, r.integer('passengers', 1)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _CityDot(from.name, filled: true),
                            const SizedBox(height: 6),
                            _CityDot(to.name, filled: false),
                          ],
                        ),
                      ),
                      if (date != null) Text(formatCalendarShort(date), style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// "25 نوفمبر" for a calendar date.
String formatCalendarShort(DateTime d) => '${d.day} ${kArabicMonths[d.month - 1]}';

class _CityDot extends StatelessWidget {
  const _CityDot(this.name, {required this.filled});

  final String name;
  final bool filled;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? ZoolColors.brand : Colors.white,
              border: Border.all(color: ZoolColors.brand),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: ZoolColors.textStrong))),
        ],
      );
}

class _Popular extends ConsumerWidget {
  const _Popular({required this.onPick});

  final ValueChanged<SearchCity> onPick;

  static const _tints = [Color(0xFF7A2232), Color(0xFF115233), Color(0xFF8A5A14), Color(0xFF1F4E79)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_popularProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('وجهات شائعة'),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final d = items[i];
              final tint = _tints[i % _tints.length];
              return GestureDetector(
                onTap: () => onPick(SearchCity.fromJson(d.city)),
                child: Container(
                  width: 170,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(ZoolRadii.card), color: tint),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (d.imageUrl != null)
                        Image.network(d.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
                      else
                        Opacity(opacity: 0.35, child: Image.asset('assets/images/header_city.jpg', package: 'zool_ui', fit: BoxFit.cover)),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, tint.withValues(alpha: 0.85)]),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(d.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                            if (d.fromPriceMinor > 0) ...[
                              const Text('بداية من', style: TextStyle(fontSize: 11, color: Colors.white70)),
                              Text(formatSdg(d.fromPriceMinor), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF7BE0A5))),
                            ] else
                              const Text('رحلات قريبًا', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          ],
                        ),
                      ),
                      const PositionedDirectional(
                        end: 10,
                        bottom: 12,
                        child: CircleAvatar(radius: 14, backgroundColor: Colors.white24, child: Icon(IconsaxPlusLinear.arrow_left_2, size: 16, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
