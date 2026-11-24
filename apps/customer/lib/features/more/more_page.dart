import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// Profile / «المزيد» (Figma 3074:2394): profile card with edit, stats (trips, destinations — C21
/// drops «تقييمك»), payment methods, trip alerts, privacy, logout, delete account (C19).
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, CustomerMe me) async {
    final name = TextEditingController(text: me.displayName ?? '');
    final email = TextEditingController(text: me.email ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('تعديل الملف الشخصي', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 12),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'البريد الإلكتروني (اختياري)')),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'حفظ',
              onPressed: () async {
                try {
                  await ref.read(apiProvider).updateMe(
                        displayName: name.text.trim().length >= 2 ? name.text.trim() : null,
                        email: email.text.trim().isEmpty ? null : email.text.trim(),
                      );
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } catch (e) {
                  if (ctx.mounted) showErrorSnack(ctx, e);
                }
              },
            ),
          ]),
        ),
      ),
    );
    if (saved == true) ref.invalidate(meProvider);
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(context, title: 'تسجيل الخروج؟', confirmLabel: 'خروج', destructive: true);
    if (!ok) return;
    await ref.read(sessionProvider).logout();
    ref.invalidate(meProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final first = await showConfirmDialog(
      context,
      title: 'حذف الحساب؟',
      message: 'سيُحذف حسابك وبياناتك الشخصية نهائيًا. تبقى سجلات الحجوزات للمحاسبة فقط.',
      confirmLabel: 'متابعة',
      destructive: true,
    );
    if (!first || !context.mounted) return;
    final second = await showConfirmDialog(context, title: 'تأكيد نهائي', message: 'لا يمكن التراجع عن هذا الإجراء.', confirmLabel: 'حذف الحساب', destructive: true);
    if (!second || !context.mounted) return;
    try {
      await ref.read(apiProvider).deleteAccount();
      await ref.read(sessionProvider).logout();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      if (e.code == 'ACCOUNT_HAS_ACTIVE_BOOKINGS') {
        await showInfoDialog(context, title: 'لديك رحلات قادمة', message: 'ألغِ رحلاتك القادمة أولًا ثم احذف الحساب.');
      } else {
        showErrorSnack(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    return ZoolPage(
      body: AsyncBody(
        value: me,
        onRetry: () => ref.invalidate(meProvider),
        data: (m) => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          ZoolCard(
            child: Row(children: [
              InitialsAvatar(m.name, radius: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
                  Text(formatPhone(m.phone), style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary)),
                  if (m.email != null) Text(m.email!, style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary)),
                ]),
              ),
              IconButton(tooltip: 'تعديل', onPressed: () => _edit(context, ref, m), icon: const Icon(IconsaxPlusLinear.edit_2, color: ZoolColors.brand)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatTile(icon: IconsaxPlusLinear.bus, value: '${m.tripsCount}', label: 'رحلة')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(icon: IconsaxPlusLinear.map, value: '${m.destinationsCount}', label: 'وجهة')),
          ]),
          const SizedBox(height: 12),
          _Menu(children: [
            _MenuRow(icon: IconsaxPlusLinear.wallet_3, label: 'طرق الدفع', onTap: () => context.push('/payment-methods')),
            _MenuRow(
              icon: IconsaxPlusLinear.notification,
              label: 'تنبيهات الرحلات',
              trailing: Switch(
                value: m.tripAlerts,
                activeTrackColor: ZoolColors.brand,
                onChanged: (on) async {
                  try {
                    await ref.read(apiProvider).setTripAlerts(on);
                    ref.invalidate(meProvider);
                  } catch (e) {
                    if (context.mounted) showErrorSnack(context, e);
                  }
                },
              ),
            ),
            _MenuRow(icon: IconsaxPlusLinear.shield_tick, label: 'سياسة الأمان والخصوصية', onTap: () => context.push('/content/privacy')),
            _MenuRow(icon: IconsaxPlusLinear.document_text, label: 'الشروط والأحكام', onTap: () => context.push('/content/terms')),
          ]),
          const SizedBox(height: 12),
          _Menu(children: [
            _MenuRow(icon: IconsaxPlusLinear.logout, label: 'تسجيل الخروج', onTap: () => _logout(context, ref)),
            _MenuRow(icon: IconsaxPlusLinear.profile_delete, label: 'حذف الحساب', danger: true, onTap: () => _delete(context, ref)),
          ]),
        ]),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => ZoolCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [
          Icon(icon, color: ZoolColors.brand),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
        ]),
      );
}

class _Menu extends StatelessWidget {
  const _Menu({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ZoolCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[children[i], if (i < children.length - 1) const Divider(indent: 64)],
        ]),
      );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.onTap, this.trailing, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: danger ? ZoolColors.primarySoft : ZoolColors.secondarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: danger ? ZoolColors.error : ZoolColors.brand),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: danger ? ZoolColors.error : ZoolColors.textStrong, fontWeight: danger ? FontWeight.w700 : FontWeight.w400))),
            trailing ?? const Icon(IconsaxPlusLinear.arrow_left_2, size: 18, color: ZoolColors.textMuted),
          ]),
        ),
      );
}
