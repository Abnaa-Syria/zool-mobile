import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';

/// Profile (3083:2921, B8: office + role, not "company + rating"), commissions, logout.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: AsyncBody(
        value: me,
        onRetry: () => ref.invalidate(meProvider),
        data: (m) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ZoolCard(
              child: Row(
                children: [
                  InitialsAvatar(m.displayName, radius: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.displayName, style: t.titleMedium),
                        Text(roleLabel(m.role), style: t.bodySmall),
                        if (m.phone != null) Text(formatPhone(m.phone), style: t.bodySmall, textDirection: TextDirection.ltr),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ZoolCard(
              child: Column(
                children: [
                  InfoRow('المكتب', m.officeName),
                  InfoRow('رمز المكتب', m.officeCode),
                  InfoRow('الصلاحيات', [
                    if (m.canBook) 'الحجز',
                    if (m.canTopUp) 'شحن المحفظة',
                    if (m.canViewReports) 'التقارير والعمولات',
                  ].join('، ')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ZoolCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (m.canViewReports)
                    ListTile(
                      leading: const Icon(Icons.percent_rounded, color: ZoolColors.secondary),
                      title: const Text('العمولات'),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => context.push('/commissions'),
                    ),
                  ListTile(
                    leading: const Icon(Icons.notifications_none_rounded, color: ZoolColors.secondary),
                    title: const Text('الإشعارات'),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => context.push('/notifications'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: ZoolColors.error),
                    title: const Text('تسجيل الخروج', style: TextStyle(color: ZoolColors.error)),
                    onTap: () async {
                      final ok = await showConfirmDialog(context, title: 'تسجيل الخروج؟', confirmLabel: 'خروج', destructive: true);
                      if (!ok) return;
                      await ref.read(sessionProvider).logout();
                      ref.invalidate(meProvider);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('إدارة الموظفين والتقارير التفصيلية متاحة في لوحة الوكلاء على الويب.', style: t.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
