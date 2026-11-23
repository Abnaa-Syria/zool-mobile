import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import '../home/home_page.dart';
import 'booking_tile.dart';

/// Bookings tab (Figma 3083:1927): نشطة / مكتملة / ملغاة + search by reference, ticket, name or phone.
class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key});

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> {
  static const _tabs = [('ACTIVE', 'نشطة'), ('COMPLETED', 'مكتملة'), ('CANCELLED', 'ملغاة')];
  String _q = '';
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(bookingsVersionProvider);
    final api = ref.watch(apiProvider);
    final me = ref.watch(meProvider).value;
    return DefaultTabController(
      length: _tabs.length,
      child: ZoolPage(
        header: BrokerGreeting(me: me),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ZoolRadii.card)),
                child: Row(
                  children: [
                    Expanded(child: TabBar(tabs: [for (final t in _tabs) Tab(text: t.$2)])),
                    IconButton(
                      tooltip: 'بحث',
                      onPressed: () => setState(() {
                        _searching = !_searching;
                        if (!_searching) _q = '';
                      }),
                      icon: Icon(_searching ? IconsaxPlusLinear.close_circle : IconsaxPlusLinear.search_normal_1, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    fillColor: Colors.white,
                    prefixIcon: Icon(IconsaxPlusLinear.search_normal_1, size: 20),
                    hintText: 'رقم الحجز أو التذكرة أو اسم/جوال الراكب',
                    isDense: true,
                  ),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), () {
                      final q = v.trim();
                      if (mounted) setState(() => _q = q.length >= 2 ? q : '');
                    });
                  },
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final (tab, label) in _tabs)
                    PagedList<Booking>(
                      reloadKey: (tab, _q, version),
                      separator: 12,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      fetch: (page) async {
                        final res = await api.bookings(tab: tab, q: _q, page: page);
                        return (items: res.items, totalPages: res.totalPages);
                      },
                      itemBuilder: (_, b) => BookingTile(booking: b),
                      empty: EmptyView(
                        title: _q.isEmpty ? 'لا توجد حجوزات $label' : 'لا نتائج للبحث',
                        icon: IconsaxPlusLinear.ticket,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
