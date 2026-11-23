import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// B9 — notification feed with unread markers; a tap marks it read and opens its booking / top-up.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  int _version = 0;
  final Set<String> _read = {};

  Future<void> _open(AppNotification n) async {
    final api = ref.read(apiProvider);
    if (!n.isRead && !_read.contains(n.id)) {
      setState(() => _read.add(n.id));
      api.markRead(n.id).catchError((_) {});
    }
    final bookingId = n.data.strOrNull('bookingId');
    final topUpId = n.data.strOrNull('topUpIntentId') ?? n.data.strOrNull('intentId');
    if (bookingId != null) {
      await context.push('/booking/$bookingId');
    } else if (topUpId != null) {
      await context.push('/top-up/$topUpId');
    } else {
      await showInfoDialog(context, title: n.title, message: n.body);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final t = Theme.of(context).textTheme;
    return ZoolPage(
      title: 'الإشعارات',
      action: TextButton(
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
      body: PagedList<AppNotification>(
        reloadKey: _version,
        separator: 8,
        fetch: (page) async {
          final res = await api.notifications(page: page);
          return (items: res.items, totalPages: res.totalPages);
        },
        empty: const EmptyView(title: 'لا توجد إشعارات', icon: IconsaxPlusLinear.notification),
        itemBuilder: (context, n) {
          final unread = !n.isRead && !_read.contains(n.id);
          return ZoolCard(
            onTap: () => _open(n),
            color: unread ? ZoolColors.secondarySoft : Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(IconsaxPlusBold.notification, color: unread ? ZoolColors.secondary : ZoolColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title, style: t.titleSmall),
                      const SizedBox(height: 2),
                      Text(n.body, style: t.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatRelative(n.createdAt), style: t.bodySmall),
              ],
            ),
          );
        },
      ),
    );
  }
}
