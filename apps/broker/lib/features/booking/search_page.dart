import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';
import '../home/home_page.dart';
import 'flow.dart';

/// «حجز جديد» tab (Figma 3083:1881): from / to, date, passengers, one way / round trip.
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
    final picked = await showZoolDatePicker(context, firstDate: first, lastDate: _today().add(const Duration(days: 120)), initialDate: initial);
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

  Future<void> _pickCount() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('عدد المسافرين', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (var n = 1; n <= 9; n++)
              ListTile(
                title: Text(_travellers(n)),
                trailing: n == _count ? const Icon(IconsaxPlusBold.tick_circle, color: ZoolColors.brand) : null,
                onTap: () => Navigator.of(ctx).pop(n),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _count = picked);
  }

  static String _travellers(int n) => travellersLabel(n);

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
    final me = ref.watch(meProvider).value;
    return ZoolPage(
      header: BrokerGreeting(me: me),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          ZoolCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _CityBox(label: 'من', city: _from?.name, onTap: () => _pickCity(from: true))),
                          const SizedBox(width: 10),
                          Expanded(child: _CityBox(label: 'إلى', city: _to?.name, onTap: () => _pickCity(from: false))),
                        ],
                      ),
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(side: BorderSide(color: ZoolColors.divider)),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() {
                            final f = _from;
                            _from = _to;
                            _to = f;
                          }),
                          child: const SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(IconsaxPlusLinear.arrow_swap_horizontal, size: 18, color: ZoolColors.brand, semanticLabel: 'تبديل المدينتين'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _Box(
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isReturn: false),
                          child: Row(
                            children: [
                              const Icon(IconsaxPlusLinear.calendar_1, size: 20, color: ZoolColors.textStrong),
                              const SizedBox(width: 8),
                              Flexible(child: Text(formatCalendarDate(_date), style: _value, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, height: 24, color: ZoolColors.divider, margin: const EdgeInsets.symmetric(horizontal: 10)),
                      InkWell(
                        onTap: _pickCount,
                        child: Row(
                          children: [
                            Text(_travellers(_count), style: _value),
                            const SizedBox(width: 4),
                            const Icon(IconsaxPlusLinear.arrow_down_1, size: 18, color: ZoolColors.textStrong),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_roundTrip) ...[
                  const SizedBox(height: 10),
                  _Box(
                    child: InkWell(
                      onTap: () => _pickDate(isReturn: true),
                      child: Row(
                        children: [
                          const Icon(IconsaxPlusLinear.calendar_1, size: 20, color: ZoolColors.textStrong),
                          const SizedBox(width: 8),
                          Text(
                            _returnDate == null ? 'تاريخ العودة' : 'العودة: ${formatCalendarDate(_returnDate!)}',
                            style: _returnDate == null ? _value.copyWith(color: ZoolColors.textMuted) : _value,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _TripType(label: 'ذهاب فقط', icon: IconsaxPlusLinear.arrow_left, selected: !_roundTrip, onTap: () => setState(() => _roundTrip = false))),
                    const SizedBox(width: 10),
                    Expanded(child: _TripType(label: 'ذهاب وعودة', icon: IconsaxPlusLinear.repeat, selected: _roundTrip, onTap: () => setState(() => _roundTrip = true))),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: ZoolColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                PrimaryButton(label: 'البحث عن رحلات للعميل', onPressed: (me?.canBook ?? false) ? _submit : null),
                if (me != null && !me.canBook) ...[
                  const SizedBox(height: 8),
                  const Text('ليست لديك صلاحية الحجز. تواصل مع مدير المكتب.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _value = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ZoolColors.textStrong);
}

class _Box extends StatelessWidget {
  const _Box({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(border: Border.all(color: ZoolColors.divider), borderRadius: BorderRadius.circular(ZoolRadii.field)),
        child: child,
      );
}

class _CityBox extends StatelessWidget {
  const _CityBox({required this.label, required this.city, required this.onTap});

  final String label;
  final String? city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(side: const BorderSide(color: ZoolColors.divider), borderRadius: BorderRadius.circular(ZoolRadii.field)),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZoolRadii.field),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(IconsaxPlusBold.location, size: 18, color: ZoolColors.brand),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, color: ZoolColors.textMuted, height: 1.2)),
                    Text(
                      city ?? 'اختر المدينة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: city == null ? ZoolColors.textMuted : ZoolColors.textStrong, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripType extends StatelessWidget {
  const _TripType({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? ZoolColors.secondarySoft : const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? ZoolColors.women : Colors.transparent),
        borderRadius: BorderRadius.circular(ZoolRadii.field),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZoolRadii.field),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? ZoolColors.brand : ZoolColors.textStrong),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? ZoolColors.brand : ZoolColors.textStrong)),
            ],
          ),
        ),
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
              decoration: const InputDecoration(prefixIcon: Icon(IconsaxPlusLinear.search_normal_1), hintText: 'ابحث عن مدينة'),
              onChanged: (v) => setState(() => _q = v.trim()),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(IconsaxPlusBold.location, color: ZoolColors.brand),
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
