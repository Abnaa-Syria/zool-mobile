import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';

/// «المزيد» (Figma 3083:2921, with B8: the office card shows the office and role, not a rating).
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(context, title: 'تسجيل الخروج؟', message: 'ستحتاج رمز تحقق جديدًا للدخول مرة أخرى.', confirmLabel: 'خروج', destructive: true);
    if (!ok) return;
    await ref.read(sessionProvider).logout();
    ref.invalidate(meProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    return ZoolPage(
      body: AsyncBody(
        value: me,
        onRetry: () => ref.invalidate(meProvider),
        data: (m) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            ZoolCard(
              child: Row(
                children: [
                  InitialsAvatar(m.displayName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
                        Text('${roleLabel(m.role)} · «${m.officeName}»', style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary)),
                        if (m.phone != null)
                          Text(formatPhone(m.phone), textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ZoolCard(
              child: Row(
                children: [
                  CarrierLogo(name: m.officeName),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.officeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
                        Text('مكتب وكيل · ${m.officeCode}', style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Menu(items: [
              _MenuItem(IconsaxPlusLinear.wallet_3, 'المحفظة وطلبات الشحن', () => context.push('/wallet')),
              if (m.canViewReports) _MenuItem(IconsaxPlusLinear.percentage_circle, 'العمولات', () => context.push('/commissions')),
              _MenuItem(IconsaxPlusLinear.notification, 'الإشعارات', () => context.push('/notifications')),
              _MenuItem(IconsaxPlusLinear.shield_tick, 'الصلاحيات', () => _showPermissions(context, m.canBook, m.canTopUp, m.canViewReports)),
              _MenuItem(IconsaxPlusLinear.message_question, 'المساعدة والدعم', () => showInfoDialog(
                    context,
                    title: 'المساعدة والدعم',
                    message: 'لأي مشكلة في الحجوزات أو المحفظة تواصل مع مدير المكتب أو فريق دعم زول قو. إدارة الموظفين والتقارير التفصيلية متاحة في لوحة الوكلاء على الويب.',
                  )),
            ]),
            const SizedBox(height: 12),
            _Menu(items: [
              _MenuItem(IconsaxPlusLinear.logout, 'تسجيل الخروج', () => _logout(context, ref), danger: true),
            ]),
          ],
        ),
      ),
    );
  }

  void _showPermissions(BuildContext context, bool book, bool topUp, bool reports) {
    showInfoDialog(
      context,
      title: 'صلاحياتك',
      message: [
        '${book ? '✓' : '✗'} إنشاء الحجوزات وتعديلها وإلغاؤها',
        '${topUp ? '✓' : '✗'} شحن محفظة المكتب',
        '${reports ? '✓' : '✗'} التقارير والعمولات',
      ].join('\n'),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.onTap, {this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
}

class _Menu extends StatelessWidget {
  const _Menu({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return ZoolCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            InkWell(
              onTap: items[i].onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: items[i].danger ? const Color(0xFFF3F4F6) : ZoolColors.secondarySoft, shape: BoxShape.circle),
                      child: Icon(items[i].icon, size: 20, color: items[i].danger ? ZoolColors.textSecondary : ZoolColors.brand),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(items[i].label, style: const TextStyle(fontSize: 14, color: ZoolColors.textStrong))),
                    const Icon(IconsaxPlusLinear.arrow_left_2, size: 18, color: ZoolColors.textMuted),
                  ],
                ),
              ),
            ),
            if (i < items.length - 1) const Divider(indent: 64),
          ],
        ],
      ),
    );
  }
}
