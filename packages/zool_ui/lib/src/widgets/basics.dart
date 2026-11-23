import 'package:flutter/material.dart';

import '../theme.dart';
import 'chrome.dart';

/// White rounded card (16 px, no border), as everywhere in the design.
class ZoolCard extends StatelessWidget {
  const ZoolCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.onTap,
    this.color,
    this.radius = ZoolRadii.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

enum BadgeTone { success, warning, error, info, neutral, brand }

/// Small status chip (e.g. «مؤكدة الصعود», «بانتظار الصعود», «VIP»).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      BadgeTone.success => (const Color(0xFF1E9E4A), const Color(0xFFEAF8EF)),
      BadgeTone.warning => (const Color(0xFFD97A00), const Color(0xFFFFF4E5)),
      BadgeTone.error => (const Color(0xFFD92D20), const Color(0xFFFFECEB)),
      BadgeTone.info => (const Color(0xFF0B5CB8), const Color(0xFFE8F1FC)),
      BadgeTone.brand => (ZoolColors.brand, ZoolColors.secondarySoft),
      BadgeTone.neutral => (ZoolColors.textSecondary, const Color(0xFFF3F4F6)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700, height: 1.3)),
    );
  }
}

/// Label on the start, value on the end.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueColor, this.bold = false, this.trailing, this.large = false});

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final bool large;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: large ? 14 : 13, color: large ? ZoolColors.textStrong : ZoolColors.textSecondary, fontWeight: large ? FontWeight.w700 : FontWeight.w400),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: trailing ??
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: large ? 18 : 13,
                    color: valueColor ?? ZoolColors.textStrong,
                    fontWeight: large ? FontWeight.w800 : (bold ? FontWeight.w700 : FontWeight.w600),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

/// Section heading (bold 15) with an optional action on the end.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ?action,
        ],
      ),
    );
  }
}

/// Full-width red action button with a busy state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon, this.color});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  /// Defaults to the brand red; the design uses dark green for some secondary actions.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = color == null ? null : FilledButton.styleFrom(backgroundColor: color);
    final child = busy
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Text(label);
    if (icon != null && !busy) {
      return FilledButton.icon(style: style, onPressed: onPressed, icon: Icon(icon, size: 20), label: child);
    }
    return FilledButton(style: style, onPressed: busy ? null : onPressed, child: child);
  }
}

/// The page's main action in the white bottom bar.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ZoolBottomBar(child: child);
}

/// Small white KPI card: grey label, bold value (home «أداء المبيعات اليوم»).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.valueColor = ZoolColors.text});

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return ZoolCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: ZoolColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: valueColor)),
          ),
        ],
      ),
    );
  }
}

/// Soft-green quick-access button (icon + label).
class QuickButton extends StatelessWidget {
  const QuickButton({super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(ZoolRadii.button), boxShadow: ZoolShadows.soft),
      child: Material(
        color: ZoolColors.secondarySoft,
        borderRadius: BorderRadius.circular(ZoolRadii.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(ZoolRadii.button),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 24, height: 24, child: icon),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ZoolColors.secondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Amount with a smaller currency: "350 ج.م" style, here "350 ج.س".
class MoneyText extends StatelessWidget {
  const MoneyText(this.formatted, {super.key, this.size = 18, this.color = ZoolColors.brand, this.currencyColor});

  /// The output of `formatSdg` ("35,000 ج.س").
  final String formatted;
  final double size;
  final Color color;
  final Color? currencyColor;

  @override
  Widget build(BuildContext context) {
    final i = formatted.lastIndexOf(' ');
    final amount = i < 0 ? formatted : formatted.substring(0, i);
    final currency = i < 0 ? '' : formatted.substring(i + 1);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: amount, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color)),
        if (currency.isNotEmpty)
          TextSpan(text: ' $currency', style: TextStyle(fontSize: size * 0.6, fontWeight: FontWeight.w400, color: currencyColor ?? color)),
      ]),
    );
  }
}
