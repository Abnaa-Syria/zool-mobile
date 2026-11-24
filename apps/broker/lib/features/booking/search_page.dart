import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import '../home/home_page.dart';
import 'flow.dart';

/// «حجز جديد» tab (Figma 3083:1881): the shared search card for the customer of the office.
class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  static SearchCity _toSearch(City c) => SearchCity.fromJson(c.json);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    final flow = ref.read(bookingFlowProvider);
    return ZoolPage(
      header: BrokerGreeting(me: me),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          TripSearchCard(
            buttonLabel: 'البحث عن رحلات للعميل',
            enabled: me?.canBook ?? false,
            disabledHint: me == null ? null : 'ليست لديك صلاحية الحجز. تواصل مع مدير المكتب.',
            initialFrom: flow.fromCity == null ? null : _toSearch(flow.fromCity!),
            initialTo: flow.toCity == null ? null : _toSearch(flow.toCity!),
            initialDate: flow.date,
            initialPassengers: flow.passengerCount,
            initialRoundTrip: flow.roundTrip,
            initialReturnDate: flow.returnDate,
            loadCities: () async => (await ref.read(citiesProvider.future)).map(_toSearch).toList(),
            onSearch: (v) async {
              final cities = await ref.read(citiesProvider.future);
              City byId(String id) => cities.firstWhere((c) => c.id == id);
              ref.read(bookingFlowProvider.notifier).setSearch(
                    fromCity: byId(v.from.id),
                    toCity: byId(v.to.id),
                    date: v.date,
                    passengerCount: v.passengers,
                    roundTrip: v.roundTrip,
                    returnDate: v.returnDate,
                  );
              if (context.mounted) context.push('/book/results/outbound');
            },
          ),
        ],
      ),
    );
  }
}
