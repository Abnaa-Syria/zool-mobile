import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import '../trips/trip_detail_page.dart';
import 'board_action.dart';

/// صعود الركاب (Figma 3043:3234): boarded/booked banner with «فتح المسح السريع» and the
/// manifest. A row opens the passenger sheet (call, manual boarding with cash, no-show).
class BoardingPage extends ConsumerStatefulWidget {
  const BoardingPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<BoardingPage> createState() => _BoardingPageState();
}

class _BoardingPageState extends ConsumerState<BoardingPage> {
  String _filter = 'ALL';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.tripId)).value;
    final manifest = ref.watch(manifestProvider(widget.tripId));
    return ZoolPage(
      title: 'صعود الركاب',
      subtitle: trip?.routeLabel,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(manifestProvider(widget.tripId).future),
        child: AsyncBody<Manifest>(
          value: manifest,
          onRetry: () => ref.invalidate(manifestProvider(widget.tripId)),
          data: (m) {
            final q = _query.trim();
            final rows = m.passengers.where((p) {
              if (_filter == 'PENDING' && !p.isPending) return false;
              if (_filter == 'BOARDED' && !p.isBoarded) return false;
              if (_filter == 'NO_SHOW' && !p.isNoShow) return false;
              if (q.isEmpty) return true;
              return p.fullName.contains(q) || p.seatLabel.toLowerCase() == q.toLowerCase() || p.ticketNumber.contains(q.toUpperCase());
            }).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _Summary(manifest: m, canScan: trip?.status == 'BOARDING', onScan: () => context.push('/trip/${widget.tripId}/scan')),
                if (trip != null && trip.status == 'SCHEDULED') ...[
                  const SizedBox(height: 10),
                  const _Hint('ابدأ الصعود من تفاصيل الرحلة لتتمكن من مسح التذاكر وتسجيل الركاب.'),
                ],
                const SizedBox(height: 16),
                const SectionTitle('قائمة ركاب الرحلة الحالية'),
                if (m.passengers.length > 6) ...[
                  TextField(
                    decoration: const InputDecoration(hintText: 'ابحث بالاسم أو المقعد أو رقم التذكرة', prefixIcon: Icon(IconsaxPlusLinear.search_normal_1, size: 20)),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 10),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final (key, label) in [
                      ('ALL', 'الكل (${m.booked})'),
                      ('PENDING', 'في الانتظار (${m.pending})'),
                      ('BOARDED', 'صعدوا (${m.boarded})'),
                      if (m.noShow > 0) ('NO_SHOW', 'لم يحضر (${m.noShow})'),
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(label: Text(label), selected: _filter == key, onSelected: (_) => setState(() => _filter = key)),
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
                if (m.passengers.isEmpty)
                  const EmptyView(title: 'لا يوجد ركاب بعد', message: 'تظهر هنا التذاكر المؤكدة لهذه الرحلة.', icon: IconsaxPlusLinear.people)
                else if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('لا توجد نتائج', textAlign: TextAlign.center, style: TextStyle(color: ZoolColors.textSecondary)),
                  ),
                for (final p in rows) ...[
                  PassengerRow(entry: p, onTap: () => showPassengerSheet(context, widget.tripId, p, tripStatus: trip?.status ?? m.status)),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.manifest, required this.canScan, required this.onScan});

  final Manifest manifest;
  final bool canScan;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(color: ZoolColors.brand, borderRadius: BorderRadius.circular(ZoolRadii.bigCard)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('إجمالي الركاب الحاضرين', style: TextStyle(fontSize: 13, color: Colors.white70)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${manifest.boarded} / ${manifest.booked} صعدوا الباص',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ]),
        ),
        if (canScan)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onScan,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Text('فتح المسح السريع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ZoolColors.brand)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFE8F1FC), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(IconsaxPlusLinear.info_circle, color: ZoolColors.info, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF0B5CB8)))),
      ]),
    );
  }
}

/// Manifest row: seat chip · name (+ cash due) · status dot.
class PassengerRow extends StatelessWidget {
  const PassengerRow({super.key, required this.entry, this.onTap});

  final ManifestEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = entry;
    final (label, color) = boardingLabel(p);
    return ZoolCard(
      radius: ZoolRadii.bigCard,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      child: Row(children: [
        Container(
          constraints: const BoxConstraints(minWidth: 40),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.womenOnlySeat ? ZoolColors.women.withValues(alpha: 0.2) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(p.seatLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ZoolColors.brand)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
            if (p.cashToCollectMinor > 0)
              Text('نقدًا: ${formatSdg(p.cashToCollectMinor)}', style: const TextStyle(fontSize: 11, color: ZoolColors.warning, fontWeight: FontWeight.w700))
            else if (p.isCash && p.cashCollectedMinor > 0)
              Text('دُفع نقدًا ${formatSdg(p.cashCollectedMinor)}', style: const TextStyle(fontSize: 11, color: ZoolColors.textMuted)),
          ]),
        ),
        DotStatus(label, color),
      ]),
    );
  }
}

/// Passenger sheet: details, call, manual boarding (with cash) and no-show.
Future<void> showPassengerSheet(BuildContext context, String tripId, ManifestEntry p, {required String tripStatus}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    builder: (_) => _PassengerSheet(tripId: tripId, entry: p, tripStatus: tripStatus),
  );
}

class _PassengerSheet extends ConsumerStatefulWidget {
  const _PassengerSheet({required this.tripId, required this.entry, required this.tripStatus});

  final String tripId;
  final ManifestEntry entry;
  final String tripStatus;

  @override
  ConsumerState<_PassengerSheet> createState() => _PassengerSheetState();
}

class _PassengerSheetState extends ConsumerState<_PassengerSheet> {
  bool _busy = false;

  Future<void> _noShow() async {
    final p = widget.entry;
    final ok = await showConfirmDialog(context, title: 'تسجيل عدم الحضور؟', message: '${p.fullName} · مقعد ${p.seatLabel}', confirmLabel: 'لم يحضر', destructive: true);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).noShow(widget.tripId, p.ticketNumber);
      tripsChanged(ref);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showMessageSnack(context, driverErrorText(e), success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _board() async {
    setState(() => _busy = true);
    final ok = await boardPassenger(context, ref, widget.tripId, widget.entry, method: 'MANUAL');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.entry;
    final (label, color) = boardingLabel(p);
    final boarding = widget.tripStatus == 'BOARDING';
    final canNoShow = p.isPending && (boarding || widget.tripStatus == 'IN_PROGRESS');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(p.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            DotStatus(label, color),
          ]),
          const SizedBox(height: 10),
          InfoRow('المقعد', p.womenOnlySeat ? '${p.seatLabel} (مقعد نسائي)' : p.seatLabel, bold: true),
          InfoRow('رقم التذكرة', p.ticketNumber),
          InfoRow('رقم الحجز', p.bookingRef),
          if (p.soldBy != null) InfoRow('الحجز عبر', p.soldBy!),
          InfoRow('الدفع', p.isCash ? 'نقدًا للسائق' : 'مدفوع إلكترونيًا'),
          if (p.cashToCollectMinor > 0) InfoRow('المطلوب تحصيله', formatSdg(p.cashToCollectMinor), valueColor: ZoolColors.warning, bold: true),
          if (p.cashCollectedMinor > 0) InfoRow('تم تحصيل', formatSdg(p.cashCollectedMinor), valueColor: ZoolColors.success, bold: true),
          if (p.boardedAt != null) InfoRow('وقت الصعود', '${formatTime(p.boardedAt)} · ${p.boardingMethod == 'MANUAL' ? 'يدويًا' : 'بالمسح'}'),
          const SizedBox(height: 14),
          if (p.phone != null)
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:${p.phone}')),
              icon: const Icon(IconsaxPlusLinear.call, size: 18),
              label: Text('اتصال ${formatPhone(p.phone)}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          if (p.isPending && boarding) ...[
            const SizedBox(height: 10),
            PrimaryButton(
              label: p.cashToCollectMinor > 0 ? 'استلام ${formatSdg(p.cashToCollectMinor)} وتسجيل الصعود' : 'تسجيل الصعود يدويًا',
              color: ZoolColors.brand,
              busy: _busy,
              onPressed: _busy ? null : _board,
            ),
          ],
          if (canNoShow) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : _noShow,
              style: TextButton.styleFrom(foregroundColor: ZoolColors.error),
              child: const Text('لم يحضر'),
            ),
          ],
        ]),
      ),
    );
  }
}
