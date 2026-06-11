
import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../utils/app_localizations.dart';
import '../widgets/assistant_fab.dart';
import 'calendar/care_calendar_screen.dart';
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

  // Calendar inserted at index 3 (owner field request: 'add a tab for
  // calendar view'). Indices 1 (My Care) and 2 (Services) are referenced
  // from home_screen's switchToTab calls — do not reorder those.
  final _screens = [
    const HomeScreen(),
    const MyCareScreen(),
    ServiceCatalogScreen(key: ServiceCatalogScreen.catalogKey),
    const CareCalendarScreen(),
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
      // Owner decision (field round 5): FIXED full-width bar like the Dai Maa
      // app — anchored to the bottom edge, no floating margins (the detached
      // pill covered content and read as hovering clutter). Stays SOLID BRAND
      // ORANGE with white items (white-on-orange rule). The bar pads itself
      // for the home indicator via the Scaffold slot's own safe-area handling.
      bottomNavigationBar: Material(
        color: context.hc.orange,
        child: SafeArea(
          top: false,
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
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
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
    );
  }
}
