import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import 'trip_card.dart';

/// قائمة الرحلات (Figma 3043:3652): القادمة · الحالية · المكتملة, opening on «الحالية».
class TripsPage extends ConsumerWidget {
  const TripsPage({super.key});

  static const _tabs = [('UPCOMING', 'القادمة'), ('CURRENT', 'الحالية'), ('COMPLETED', 'المكتملة')];

  static const _empty = {
    'UPCOMING': ('لا توجد رحلات قادمة', 'تظهر هنا الرحلات التي تسندها إليك شركة النقل.'),
    'CURRENT': ('لا توجد رحلة جارية', 'ابدأ الصعود من تفاصيل رحلتك القادمة لتظهر هنا.'),
    'COMPLETED': ('لا توجد رحلات مكتملة', 'سجل رحلاتك المنتهية يظهر هنا.'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(tripsVersionProvider);
    final api = ref.watch(apiProvider);
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: 1,
      child: ZoolPage(
        header: const Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text('قائمة الرحلات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ZoolColors.textStrong)),
        ),
        body: Column(children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ZoolRadii.card)),
            child: TabBar(tabs: [for (final t in _tabs) Tab(text: t.$2)]),
          ),
          Expanded(
            child: TabBarView(children: [
              for (final (tab, _) in _tabs)
                PagedList<DriverTrip>(
                  reloadKey: (tab, version),
                  separator: 12,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  fetch: (page) async {
                    final res = await api.trips(tab: tab, page: page);
                    return (items: res.items, totalPages: res.totalPages);
                  },
                  itemBuilder: (context, t) => TripCard(trip: t, highlight: t.isLive, onTap: () => context.push('/trip/${t.id}')),
                  empty: EmptyView(title: _empty[tab]!.$1, message: _empty[tab]!.$2, icon: IconsaxPlusLinear.bus),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
