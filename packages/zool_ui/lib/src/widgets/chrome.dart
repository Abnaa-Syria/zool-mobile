import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../theme.dart';

/// Page frame from the design: mint background, the faded city image at the top, an optional
/// top bar (round back button · centered title · optional action), the body, and a white
/// rounded bottom bar (navigation or the page's main action).
class ZoolPage extends StatelessWidget {
  const ZoolPage({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.showBack = true,
    this.action,
    this.header,
    this.bottomBar,
    this.onBack,
  });

  /// Centered bold title of the top bar; omit both [title] and [header] for no bar.
  final String? title;
  final String? subtitle;
  final bool showBack;

  /// Round button at the end of the top bar (e.g. share).
  final Widget? action;

  /// Replaces the top bar (home-style greeting header).
  final Widget? header;
  final Widget body;
  final Widget? bottomBar;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final top = header ??
        (title == null
            ? null
            : ZoolTopBar(title: title!, subtitle: subtitle, showBack: showBack, action: action, onBack: onBack));
    return Scaffold(
      backgroundColor: ZoolColors.background,
      bottomNavigationBar: bottomBar,
      body: Stack(
        children: [
          const Positioned(top: 0, left: 0, right: 0, height: 167, child: HeaderBackdrop()),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (top != null) Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: top),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The city image at 40 % opacity fading into the mint background.
class HeaderBackdrop extends StatelessWidget {
  const HeaderBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.4,
            child: Image.asset('assets/images/header_city.jpg', package: 'zool_ui', fit: BoxFit.cover),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.26, 1],
                colors: [Color(0x00E8F5EE), ZoolColors.background],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round 40 px glassy button (back, bell, share).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap, this.tooltip, this.dot = false, this.color});

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  /// Small red dot (unread notifications).
  final bool dot;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.6),
      shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 24, color: color ?? ZoolColors.textStrong),
              if (dot)
                const PositionedDirectional(
                  top: 7,
                  end: 9,
                  child: SizedBox(width: 8, height: 8, child: DecoratedBox(decoration: BoxDecoration(color: ZoolColors.error, shape: BoxShape.circle))),
                ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Back · title · action, as on the detail screens of the design.
class ZoolTopBar extends StatelessWidget {
  const ZoolTopBar({super.key, required this.title, this.subtitle, this.showBack = true, this.action, this.onBack});

  final String title;
  final String? subtitle;
  final bool showBack;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final back = showBack && (canPop || onBack != null)
        ? RoundIconButton(
            icon: IconsaxPlusLinear.arrow_right,
            tooltip: 'رجوع',
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          )
        : const SizedBox(width: 40);
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          back,
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: t.titleMedium?.copyWith(fontSize: 16, color: ZoolColors.textStrong), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) Text(subtitle!, style: t.bodySmall?.copyWith(height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action ?? const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// Avatar · greeting · subtitle on the start, bell on the end (home / new booking / bookings).
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, required this.name, required this.subtitle, this.unread = false, this.onBell, this.avatar});

  final String name;
  final String subtitle;
  final bool unread;
  final VoidCallback? onBell;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        avatar ?? InitialsAvatar(name, radius: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.isEmpty ? 'مرحباً' : 'مرحباً، ${name.split(' ').first}', style: t.titleMedium?.copyWith(fontSize: 16, height: 1.4)),
              Text(subtitle, style: t.bodySmall?.copyWith(color: ZoolColors.textSecondary, height: 1.4), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        RoundIconButton(icon: IconsaxPlusLinear.notification, tooltip: 'الإشعارات', dot: unread, onTap: onBell),
      ],
    );
  }
}

/// Avatar with initials (photos come later with S3).
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
      backgroundColor: ZoolColors.brand,
      child: Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.6)),
    );
  }
}

/// White bar with rounded top and a soft shadow, holding the page's main action.
class ZoolBottomBar extends StatelessWidget {
  const ZoolBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZoolRadii.bar)),
        boxShadow: ZoolShadows.bar,
      ),
      child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 12), child: child)),
    );
  }
}

/// One tab of [ZoolNavBar].
class ZoolNavItem {
  const ZoolNavItem({required this.label, required this.icon, required this.activeIcon});

  final String label;
  final Widget icon;
  final Widget activeIcon;
}

/// The design's bottom navigation: icon 24 + label 12, active in dark green.
class ZoolNavBar extends StatelessWidget {
  const ZoolNavBar({super.key, required this.items, required this.index, required this.onTap});

  final List<ZoolNavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZoolRadii.bar)),
        boxShadow: ZoolShadows.bar,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: items[i].label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onTap(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 24, height: 24, child: i == index ? items[i].activeIcon : items[i].icon),
                            const SizedBox(height: 4),
                            Text(
                              items[i].label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
                                color: i == index ? ZoolColors.brand : ZoolColors.navInactive,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nav / button icon from the bundled SVGs (the bus icon is not part of Iconsax).
class ZoolSvgIcon extends StatelessWidget {
  const ZoolSvgIcon(this.name, {super.key, this.size = 24, this.color});

  /// File name in `assets/icons/` without the extension (`nav_bus`, `bus_bold`).
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/$name.svg',
        package: 'zool_ui',
        width: size,
        height: size,
        colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      );
}
