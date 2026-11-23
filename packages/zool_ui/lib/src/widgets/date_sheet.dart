import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:zool_core/zool_core.dart';

import '../theme.dart';

/// Calendar bottom sheet in the brand style with Latin digits (Material's Arabic date picker
/// always uses Arabic-Indic digits). Returns the picked calendar date (local fields) or null.
Future<DateTime?> showZoolDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'اختر التاريخ',
}) {
  DateTime d(DateTime x) => DateTime(x.year, x.month, x.day);
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DateSheet(initial: d(initialDate), first: d(firstDate), last: d(lastDate), title: title),
  );
}

class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.initial, required this.first, required this.last, required this.title});

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final String title;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  /// Week starts on Saturday, as in Sudan.
  static const _weekdays = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

  bool get _canPrev => DateTime(_month.year, _month.month).isAfter(DateTime(widget.first.year, widget.first.month));
  bool get _canNext => DateTime(_month.year, _month.month).isBefore(DateTime(widget.last.year, widget.last.month));

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // DateTime.weekday: Mon=1 … Sun=7 → column with Saturday first.
    final lead = (DateTime(_month.year, _month.month).weekday + 1) % 7;
    final today = sudanNow();
    final todayDate = DateTime(today.year, today.month, today.day);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'الشهر السابق',
                  onPressed: _canPrev ? () => setState(() => _month = DateTime(_month.year, _month.month - 1)) : null,
                  icon: const Icon(IconsaxPlusLinear.arrow_right_2),
                ),
                Expanded(
                  child: Text(
                    '${kArabicMonths[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZoolColors.textStrong),
                  ),
                ),
                IconButton(
                  tooltip: 'الشهر التالي',
                  onPressed: _canNext ? () => setState(() => _month = DateTime(_month.year, _month.month + 1)) : null,
                  icon: const Icon(IconsaxPlusLinear.arrow_left_2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final w in _weekdays)
                  Expanded(child: Text(w, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted))),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysInMonth; day++)
                  Builder(builder: (context) {
                    final date = DateTime(_month.year, _month.month, day);
                    final enabled = !date.isBefore(widget.first) && !date.isAfter(widget.last);
                    final selected = date == widget.initial;
                    final isToday = date == todayDate;
                    return Padding(
                      padding: const EdgeInsets.all(3),
                      child: Material(
                        color: selected ? ZoolColors.brand : Colors.transparent,
                        shape: CircleBorder(side: isToday && !selected ? const BorderSide(color: ZoolColors.brand) : BorderSide.none),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: enabled ? () => Navigator.of(context).pop(date) : null,
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected || isToday ? FontWeight.w700 : FontWeight.w400,
                                color: selected ? Colors.white : (enabled ? ZoolColors.textStrong : ZoolColors.border),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
