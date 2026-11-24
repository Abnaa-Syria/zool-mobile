import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import '../booking/flow.dart';
import 'promo_carousel.dart';
import 'suggested_trip_card.dart';

final _recentProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(apiProvider).recentSearches());
final _popularProvider = FutureProvider.autoDispose<List<Destination>>((ref) => ref.watch(apiProvider).popular());
final _promotionsProvider = FutureProvider.autoDispose<List<Promotion>>((ref) => ref.watch(apiProvider).promotions());
final suggestedProvider = FutureProvider.autoDispose<List<Trip>>((ref) => ref.watch(apiProvider).suggestedTrips());

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
      header: CustomerGreeting(
        name: me?.displayName,
        onCity: (city) => _card.currentState?.fill(from: city),
      ),
      body: RefreshIndicator(
        color: ZoolColors.brand,
        onRefresh: () async {
          ref.invalidate(_recentProvider);
          ref.invalidate(_popularProvider);
          ref.invalidate(_promotionsProvider);
          ref.invalidate(suggestedProvider);
          ref.invalidate(unreadCountProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              me?.displayName == null ? 'أهلًا بك' : 'أهلًا، ${me!.displayName!.split(' ').first}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ZoolColors.textStrong),
            ),
            const Text('إلى أين ستسافر اليوم؟', style: TextStyle(fontSize: 14, color: ZoolColors.textSecondary)),
            const SizedBox(height: 16),
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
            const _Promotions(),
            const _Suggested(),
          ],
        ),
      ),
    );
  }
}

/// Header (Figma 3074:2228): avatar and the city chip (your usual departure city, from the last
/// search) on the start, the bell with the unread dot on the end.
class CustomerGreeting extends ConsumerWidget {
  const CustomerGreeting({super.key, required this.name, this.onCity});

  final String? name;
  final ValueChanged<SearchCity>? onCity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final recent = ref.watch(_recentProvider).value ?? const [];
    final city = recent.isEmpty ? null : SearchCity.fromJson(recent.first.obj('fromCity'));
    return Row(children: [
      InitialsAvatar(name ?? '', radius: 20),
      const SizedBox(width: 10),
      if (city != null)
        Material(
          color: Colors.white.withValues(alpha: 0.6),
          shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onCity?.call(city),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(IconsaxPlusBold.location, size: 18, color: ZoolColors.brand),
                const SizedBox(width: 6),
                Text(city.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ZoolColors.textStrong)),
              ]),
            ),
          ),
        ),
      const Spacer(),
      RoundIconButton(icon: IconsaxPlusLinear.notification, tooltip: 'الإشعارات', dot: unread > 0, onTap: () => context.go('/notifications')),
    ]);
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
                            _CityDot(from.name),
                            const Padding(
                              padding: EdgeInsetsDirectional.only(start: 2),
                              child: SizedBox(height: 10, child: VerticalDivider(width: 2, thickness: 1, color: ZoolColors.brand)),
                            ),
                            _CityDot(to.name),
                          ],
                        ),
                      ),
                      Text(_when(r.date('searchedAt'), date), style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
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

/// When the search was made, as in the design: «اليوم» / «أمس» / its day.
String _when(DateTime? searchedAt, DateTime? travelDate) {
  if (searchedAt == null) return travelDate == null ? '' : formatCalendarShort(travelDate);
  final day = sudanDay(searchedAt);
  if (day == sudanDay()) return 'اليوم';
  if (day == sudanDay(DateTime.now().subtract(const Duration(days: 1)))) return 'أمس';
  return formatDayMonth(searchedAt);
}

class _CityDot extends StatelessWidget {
  const _CityDot(this.name);

  final String name;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: ZoolColors.brand),
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

class _Promotions extends ConsumerWidget {
  const _Promotions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_promotionsProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 20), child: PromoCarousel(promotions: items));
  }
}

class _Suggested extends ConsumerWidget {
  const _Suggested();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(suggestedProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const SectionTitle('رحلات مقترحة لك'),
        SizedBox(
          height: 205,
          child: PageView.builder(
            controller: PageController(viewportFraction: 1),
            padEnds: false,
            itemCount: items.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 5, right: 5),
              child: SuggestedTripCard(key: ValueKey(items[i].id), trip: items[i]),
            ),
          ),
        ),
      ],
    );
  }
}
