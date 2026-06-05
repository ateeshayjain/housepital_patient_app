import 'package:flutter/material.dart';

import '../utils/app_localizations.dart';
import 'home/home_screen.dart';
import 'my_care/my_care_screen.dart';
import 'services/service_catalog_screen.dart';
import 'billing/billing_screen.dart';
import 'settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Global key to allow switching tabs from anywhere.
  static final GlobalKey<MainShellState> shellKey =
      GlobalKey<MainShellState>();

  static void switchToTab(int index) {
    shellKey.currentState?.switchTab(index);
  }

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = [
    const HomeScreen(),
    const MyCareScreen(),
    ServiceCatalogScreen(key: ServiceCatalogScreen.catalogKey),
    const BillingScreen(),
    const SettingsScreen(),
  ];

  void switchTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: l.t('tab_home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_outline),
            activeIcon: const Icon(Icons.favorite),
            label: l.t('tab_my_care'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.medical_services_outlined),
            activeIcon: const Icon(Icons.medical_services),
            label: l.t('tab_services'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.payment_outlined),
            activeIcon: const Icon(Icons.payment),
            label: l.t('tab_billing'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: l.t('tab_more'),
          ),
        ],
      ),
    );
  }
}
