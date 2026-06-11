import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../utils/app_localizations.dart';
import '../widgets/assistant_fab.dart';
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
      // Liquid Glass: the body extends behind the translucent nav bar so
      // content visibly glides beneath the glass while scrolling.
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: const AssistantFab(),
      // Calm pass: DETACHED floating pill — the nav hovers as a fully rounded
      // capsule instead of hugging the screen edge. It stays in the
      // bottomNavigationBar slot so Scaffold keeps reporting the slot's full
      // height (pill + margins) as the body's bottom MediaQuery inset — every
      // screen that pads its scrollable with `MediaQuery.padding.bottom + N`
      // clears the pill automatically.
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          // Float above the home indicator; min 8 on devices without one.
          math.max(MediaQuery.of(context).padding.bottom, 8.0),
        ),
        // Owner decision (field report): the pill is SOLID BRAND ORANGE for
        // visibility — white selected items, translucent-white unselected
        // (white-on-orange rule; glass version read as washed out on device).
        child: Material(
          color: context.hc.orange,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: MediaQuery.removePadding(
            // The outer Padding already clears the safe area — without this
            // the bar would add the home-indicator inset a second time.
            context: context,
            removeBottom: true,
            child: Padding(
              // 56 (bar) + 2×4 = ~64 content height, items optically centered.
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        // Transparent + flat: the orange Material provides the surface.
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: context.hc.onOrange,
        unselectedItemColor: context.hc.onOrange.withValues(alpha: 0.7),
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
            ),
          ),
        ),
      ),
    );
  }
}
