import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom navigation: home, bookings, wallet, more.
class BrokerShell extends StatelessWidget {
  const BrokerShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number_rounded), label: 'الحجوزات'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'المحفظة'),
          NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'المزيد'),
        ],
      ),
    );
  }
}
