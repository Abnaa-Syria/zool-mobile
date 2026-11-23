import 'package:flutter/material.dart';

import '../theme.dart';

/// White rounded card with a light border (cards ~16 radius in the design).
class ZoolCard extends StatelessWidget {
  const ZoolCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZoolRadii.card),
        side: const BorderSide(color: ZoolColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

enum BadgeTone { success, warning, error, info, neutral, brand }

/// Small status pill.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      BadgeTone.success => (const Color(0xFF1E7B3A), const Color(0xFFE5F6EA)),
      BadgeTone.warning => (const Color(0xFF9A5B00), const Color(0xFFFFF2DE)),
      BadgeTone.error => (const Color(0xFFC4271E), const Color(0xFFFFE8E6)),
      BadgeTone.info => (const Color(0xFF0B5CB8), const Color(0xFFE6F0FC)),
      BadgeTone.brand => (ZoolColors.secondary, ZoolColors.secondarySoft),
      BadgeTone.neutral => (ZoolColors.textSecondary, ZoolColors.surfaceMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// Label on the start, value on the end.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueColor, this.bold = false, this.trailing});

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: t.bodyMedium?.copyWith(color: ZoolColors.textSecondary))),
          const SizedBox(width: 12),
          Flexible(
            child: trailing ??
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: t.bodyMedium?.copyWith(color: valueColor ?? ZoolColors.text, fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
                ),
          ),
        ],
      ),
    );
  }
}

/// Section heading inside scrolling pages.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ?action,
        ],
      ),
    );
  }
}

/// Full-width primary button with a busy state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Text(label);
    if (icon != null && !busy) {
      return FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: child);
    }
    return FilledButton(onPressed: busy ? null : onPressed, child: child);
  }
}

/// Bottom area for a page's main action (safe-area aware, white with a top border).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: ZoolColors.divider))),
      child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: child)),
    );
  }
}

/// KPI tile for dashboards.
class KpiTile extends StatelessWidget {
  const KpiTile({super.key, required this.label, required this.value, required this.icon, this.color = ZoolColors.secondary});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ZoolCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(value, style: t.titleMedium?.copyWith(color: color, fontSize: 17, height: 1.3)),
                ),
                Text(label, style: t.bodySmall?.copyWith(height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The light-green gradient header used on home screens.
class GradientHeader extends StatelessWidget {
  const GradientHeader({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ZoolColors.secondarySoft, Colors.white],
        ),
      ),
      child: SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: child)),
    );
  }
}

/// Avatar with initials.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.radius = 24});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '؟' : parts.take(2).map((p) => p.characters.first).join(' ');
    return CircleAvatar(
      radius: radius,
      backgroundColor: ZoolColors.secondary,
      child: Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.6)),
    );
  }
}
