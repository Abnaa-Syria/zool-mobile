import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';
import '../../data/models.dart';

/// المزيد / Profile (Figma 3043:4049): driver card, carrier, driving licence, menu, logout.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _support(BuildContext context, WidgetRef ref) async {
    Json support = const {};
    try {
      support = (await ref.read(apiProvider).appConfig()).obj('support');
    } catch (_) {}
    final phone = support.strOrNull('phone');
    final whatsapp = support.strOrNull('whatsapp');
    if (whatsapp != null) {
      await launchUrl(Uri.parse('https://wa.me/${whatsapp.replaceAll(RegExp(r'\D'), '')}'), mode: LaunchMode.externalApplication);
    } else if (phone != null) {
      await launchUrl(Uri.parse('tel:$phone'));
    } else if (context.mounted) {
      showMessageSnack(context, 'رقم الدعم غير متاح حاليًا.', success: false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    return ZoolPage(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(meProvider.future),
        child: AsyncBody<DriverMe>(
          value: me,
          onRetry: () => ref.invalidate(meProvider),
          data: (d) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _DriverCard(me: d),
              const SizedBox(height: 14),
              _CompanyCard(me: d),
              const SizedBox(height: 14),
              _LicenseCard(me: d),
              const SizedBox(height: 14),
              _Menu(children: [
                _MenuItem(icon: IconsaxPlusLinear.notification, label: 'الإشعارات', onTap: () => context.push('/notifications')),
                _MenuItem(icon: IconsaxPlusLinear.message_question, label: 'المساعدة والدعم', onTap: () => _support(context, ref)),
              ]),
              const SizedBox(height: 14),
              _Menu(children: [
                _MenuItem(
                  icon: IconsaxPlusLinear.logout,
                  label: 'تسجيل الخروج',
                  iconBg: const Color(0xFFF0F1F3),
                  iconColor: ZoolColors.textSecondary,
                  onTap: () async {
                    final ok = await showConfirmDialog(context, title: 'تسجيل الخروج؟', confirmLabel: 'تسجيل الخروج');
                    if (ok) {
                      await ref.read(gpsProvider).stop();
                      await ref.read(sessionProvider).logout();
                    }
                  },
                ),
                _MenuItem(
                  icon: IconsaxPlusLinear.profile_delete,
                  label: 'حذف الحساب',
                  danger: true,
                  onTap: () => showInfoDialog(
                    context,
                    title: 'حذف الحساب',
                    message: 'حساب السائق تديره شركة النقل (${d.companyName}). تواصل معها لإيقاف الحساب أو حذفه.',
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.me});

  final DriverMe me;

  @override
  Widget build(BuildContext context) {
    return ZoolCard(
      radius: ZoolRadii.bigCard,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ZoolColors.brand, width: 1.5)),
          child: InitialsAvatar(me.displayName, radius: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(me.displayName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ZoolColors.textStrong)),
            Text('رقم السائق: \u2066#${me.driverCode}\u2069', style: const TextStyle(fontSize: 12, color: ZoolColors.brand, fontWeight: FontWeight.w600)),
            Text(formatPhone(me.phone), style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary)),
          ]),
        ),
        IconButton(
          tooltip: 'تعديل',
          onPressed: () => showInfoDialog(context, title: 'تعديل البيانات', message: 'تُحدَّث بيانات السائق من شركة النقل. تواصل معها لتعديل الاسم أو الرقم.'),
          icon: const Icon(IconsaxPlusLinear.edit_2, color: ZoolColors.brand),
        ),
      ]),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.me});

  final DriverMe me;

  @override
  Widget build(BuildContext context) {
    return ZoolCard(
      radius: ZoolRadii.bigCard,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        CarrierLogo(name: me.companyName, logoUrl: me.companyLogo, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(me.companyName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Text(me.companyLegalName.isEmpty ? 'شركة نقل مرخصة' : me.companyLegalName, style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
          ]),
        ),
      ]),
    );
  }
}

class _LicenseCard extends StatelessWidget {
  const _LicenseCard({required this.me});

  final DriverMe me;

  @override
  Widget build(BuildContext context) {
    final expiry = me.licenseExpiry;
    final (label, color) = switch (me.licenseStatus) {
      'EXPIRED' => ('منتهية', ZoolColors.error),
      'EXPIRING' || 'EXPIRING_SOON' => ('تنتهي قريبًا', ZoolColors.warning),
      _ => ('سارية', ZoolColors.success),
    };
    return ZoolCard(
      radius: ZoolRadii.bigCard,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        const _IconChip(IconsaxPlusLinear.personalcard),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('رخصة القيادة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(
              expiry == null ? (me.licenseNumber ?? '—') : 'تنتهي: ${expiry.day} ${kArabicMonths[expiry.month - 1]} ${expiry.year}',
              style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted),
            ),
          ]),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip(this.icon, {this.bg = ZoolColors.secondarySoft, this.color = ZoolColors.brand});

  final IconData icon;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ZoolCard(
      radius: ZoolRadii.bigCard,
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: ZoolColors.divider),
          c,
        ],
      ]),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.danger = false, this.iconBg, this.iconColor});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final Color? iconBg;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _IconChip(
            icon,
            bg: iconBg ?? (danger ? ZoolColors.primarySoft : ZoolColors.secondarySoft),
            color: iconColor ?? (danger ? ZoolColors.error : ZoolColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: danger ? ZoolColors.error : ZoolColors.textStrong)),
          ),
          const Icon(IconsaxPlusLinear.arrow_left_2, size: 18, color: ZoolColors.textMuted),
        ]),
      ),
    );
  }
}
