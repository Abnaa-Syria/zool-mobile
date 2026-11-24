import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// Notifications (Figma 3074:3942): grouped by day (اليوم / أمس / date), unread dot, deep links.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  int _version = 0;
  final Set<String> _read = {};

  Future<void> _open(AppNotification n) async {
    if (!n.isRead && !_read.contains(n.id)) {
      setState(() => _read.add(n.id));
      ref.read(apiProvider).markRead(n.id).then((_) => ref.invalidate(unreadCountProvider), onError: (_) {});
    }
    final bookingId = n.data.strOrNull('bookingId');
    if (bookingId != null) {
      await context.push('/booking/$bookingId');
    } else {
      await showInfoDialog(context, title: n.title, message: n.body);
    }
  }

  static String _day(DateTime? d) {
    if (d == null) return '';
    final day = sudanDay(d);
    if (day == sudanDay()) return 'اليوم';
    if (day == sudanDay(DateTime.now().subtract(const Duration(days: 1)))) return 'أمس';
    return formatLongDate(d);
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return ZoolPage(
      header: Row(children: [
        const Expanded(child: Text('الإشعارات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ZoolColors.textStrong))),
        TextButton(
          onPressed: () async {
            try {
              await api.markAllRead();
              setState(() => _version++);
              ref.invalidate(unreadCountProvider);
            } catch (e) {
              if (context.mounted) showErrorSnack(context, e);
            }
          },
          child: const Text('قراءة الكل'),
        ),
      ]),
      body: PagedList<AppNotification>(
        reloadKey: _version,
        separator: 8,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        groupBy: (n) => _day(n.createdAt),
        fetch: (page) async {
          final res = await api.notifications(page: page);
          return (items: res.items, totalPages: res.totalPages);
        },
        empty: const EmptyView(title: 'لا توجد إشعارات', message: 'ستصلك هنا التذاكر وتنبيهات المغادرة والعروض.', icon: IconsaxPlusLinear.notification),
        itemBuilder: (context, n) {
          final unread = !n.isRead && !_read.contains(n.id);
          return ZoolCard(
              onTap: () => _open(n),
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(width: 8, height: 8, decoration: BoxDecoration(color: unread ? ZoolColors.primary : Colors.transparent, shape: BoxShape.circle)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(n.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.textStrong))),
                      Text(formatTime(n.createdAt), style: const TextStyle(fontSize: 11, color: ZoolColors.textMuted)),
                    ]),
                    const SizedBox(height: 2),
                    Text(n.body, style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary)),
                  ]),
                ),
              ]),
            );
        },
      ),
    );
  }
}
