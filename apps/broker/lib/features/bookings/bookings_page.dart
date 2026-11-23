import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import 'booking_tile.dart';

/// Bookings (3083:1927): active / completed / cancelled, search by reference, ticket, name or phone.
class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key});

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> {
  static const _tabs = [('ACTIVE', 'النشطة'), ('COMPLETED', 'المكتملة'), ('CANCELLED', 'الملغاة')];
  String _q = '';
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
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الحجوزات'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(112),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
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
                TabBar(tabs: [for (final t in _tabs) Tab(text: t.$2)]),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            for (final (tab, label) in _tabs)
              PagedList<Booking>(
                reloadKey: (tab, _q, version),
                fetch: (page) async {
                  final res = await api.bookings(tab: tab, q: _q, page: page);
                  return (items: res.items, totalPages: res.totalPages);
                },
                itemBuilder: (_, b) => BookingTile(booking: b),
                empty: EmptyView(
                  title: _q.isEmpty ? 'لا توجد حجوزات $label' : 'لا نتائج للبحث',
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
