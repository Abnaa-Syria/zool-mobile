import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import 'flow.dart';

/// New booking search (3083:1881): cities, date, passengers, one way / round trip.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  City? _from;
  City? _to;
  late DateTime _date;
  DateTime? _returnDate;
  int _count = 1;
  bool _roundTrip = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = ref.read(bookingFlowProvider);
    final today = _today();
    _from = s.fromCity;
    _to = s.toCity;
    _date = s.date != null && !s.date!.isBefore(today) ? s.date! : today;
    _count = s.passengerCount;
    _roundTrip = s.roundTrip;
    _returnDate = s.returnDate;
  }

  static DateTime _today() {
    final n = sudanNow();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _pickCity({required bool from}) async {
    final cities = await ref.read(citiesProvider.future).catchError((Object e) {
      if (mounted) showErrorSnack(context, e);
      return <City>[];
    });
    if (!mounted || cities.isEmpty) return;
    final picked = await showModalBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CitySheet(cities: cities, title: from ? 'مدينة الانطلاق' : 'مدينة الوصول'),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
      _error = null;
    });
  }

  Future<void> _pickDate({required bool isReturn}) async {
    final first = isReturn ? _date : _today();
    final initial = isReturn ? (_returnDate != null && !_returnDate!.isBefore(first) ? _returnDate! : first) : _date;
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: _today().add(const Duration(days: 120)),
      initialDate: initial,
    );
    if (picked == null) return;
    setState(() {
      if (isReturn) {
        _returnDate = picked;
      } else {
        _date = picked;
        if (_returnDate != null && _returnDate!.isBefore(picked)) _returnDate = picked;
      }
    });
  }

  void _submit() {
    String? error;
    if (_from == null || _to == null) {
      error = 'اختر مدينتي الانطلاق والوصول.';
    } else if (_from!.id == _to!.id) {
      error = 'اختر مدينتين مختلفتين.';
    } else if (_roundTrip && _returnDate == null) {
      error = 'حدّد تاريخ العودة.';
    }
    if (error != null) return setState(() => _error = error);
    ref.read(bookingFlowProvider.notifier).setSearch(
          fromCity: _from!,
          toCity: _to!,
          date: _date,
          passengerCount: _count,
          roundTrip: _roundTrip,
          returnDate: _returnDate,
        );
    context.push('/book/results/outbound');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(bookingFlowProvider.notifier).abandon();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('حجز جديد')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('ذهاب فقط')),
                ButtonSegment(value: true, label: Text('ذهاب وعودة')),
              ],
              selected: {_roundTrip},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: ZoolColors.secondarySoft,
                selectedForegroundColor: ZoolColors.secondary,
              ),
              onSelectionChanged: (v) => setState(() => _roundTrip = v.first),
            ),
            const SizedBox(height: 16),
            ZoolCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Stack(
                alignment: AlignmentDirectional.centerEnd,
                children: [
                  Column(
                    children: [
                      _FieldTile(icon: Icons.trip_origin_rounded, label: 'من', value: _from?.name, onTap: () => _pickCity(from: true)),
                      const Divider(indent: 48),
                      _FieldTile(icon: Icons.location_on_rounded, label: 'إلى', value: _to?.name, onTap: () => _pickCity(from: false)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: IconButton.filledTonal(
                      tooltip: 'تبديل المدينتين',
                      onPressed: () => setState(() {
                        final f = _from;
                        _from = _to;
                        _to = f;
                      }),
                      icon: const Icon(Icons.swap_vert_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ZoolCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
                  _FieldTile(icon: Icons.calendar_today_rounded, label: 'تاريخ الذهاب', value: formatCalendarDate(_date), onTap: () => _pickDate(isReturn: false)),
                  if (_roundTrip) ...[
                    const Divider(indent: 48),
                    _FieldTile(
                      icon: Icons.event_repeat_rounded,
                      label: 'تاريخ العودة',
                      value: _returnDate == null ? null : formatCalendarDate(_returnDate!),
                      onTap: () => _pickDate(isReturn: true),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ZoolCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_rounded, color: ZoolColors.secondary),
                  const SizedBox(width: 12),
                  Expanded(child: Text('عدد الركاب', style: t.bodyMedium)),
                  IconButton(
                    onPressed: _count > 1 ? () => setState(() => _count--) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text('$_count', style: t.titleMedium),
                  IconButton(
                    onPressed: _count < 9 ? () => setState(() => _count++) : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: ZoolColors.error)),
            ],
          ],
        ),
        bottomNavigationBar: BottomActionBar(child: PrimaryButton(label: 'ابحث عن رحلة', icon: Icons.search_rounded, onPressed: _submit)),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: ZoolColors.secondary),
      title: Text(label, style: t.bodySmall),
      subtitle: Text(
        value ?? 'اختر',
        style: t.titleSmall?.copyWith(color: value == null ? ZoolColors.textMuted : ZoolColors.text),
      ),
    );
  }
}

class _CitySheet extends StatefulWidget {
  const _CitySheet({required this.cities, required this.title});

  final List<City> cities;
  final String title;

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.cities.where((c) => _q.isEmpty || c.name.contains(_q) || c.json.str('nameEn').toLowerCase().contains(_q.toLowerCase())).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث عن مدينة'),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.location_city_rounded, color: ZoolColors.secondary),
                title: Text(list[i].name),
                onTap: () => Navigator.of(context).pop(list[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
