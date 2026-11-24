import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_ui/zool_ui.dart';

/// Bottom navigation from the design (3043:3984): الرئيسية · الرحلات · المسح · المزيد.
class DriverShell extends StatelessWidget {
  const DriverShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    ZoolNavItem(
      label: 'الرئيسية',
      icon: Icon(IconsaxPlusLinear.home_2, color: ZoolColors.navInactive),
      activeIcon: Icon(IconsaxPlusBold.home_2, color: ZoolColors.brand),
    ),
    ZoolNavItem(
      label: 'الرحلات',
      icon: ZoolSvgIcon('nav_bus', color: ZoolColors.navInactive),
      activeIcon: ZoolSvgIcon('bus_bold', color: ZoolColors.brand),
    ),
    ZoolNavItem(
      label: 'المسح',
      icon: Icon(IconsaxPlusLinear.scan_barcode, color: ZoolColors.navInactive),
      activeIcon: Icon(IconsaxPlusBold.scan_barcode, color: ZoolColors.brand),
    ),
    ZoolNavItem(
      label: 'المزيد',
      icon: Icon(IconsaxPlusLinear.more, color: ZoolColors.navInactive),
      activeIcon: Icon(IconsaxPlusBold.more, color: ZoolColors.brand),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZoolColors.background,
      body: shell,
      bottomNavigationBar: ZoolNavBar(
        items: _items,
        index: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
