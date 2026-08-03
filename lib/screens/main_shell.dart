
import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../data/demo_mode.dart';
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

  // FIVE tabs (owner field round: 'move the calendar to My Care so that there
  // are five icons below'). The calendar is now reached from the My Care app
  // bar via '/care-calendar'. Indices are referenced from home_screen's
  // switchToTab calls — 1 (My Care), 2 (Services), 3 (Billing) — do not
  // reorder them.
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
      body: Column(
        children: [
          // Sample-data banner. The app falls back to bundled demo records
          // whenever the backend is unreachable so screens are never blank —
          // which is safe only if the patient is TOLD. Without this, a family
          // member reads the sample patient's chart believing it is their own.
          const _DemoDataBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
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

/// Persistent, honest notice that the app is showing bundled sample records
/// rather than this patient's real data.
///
/// Deliberately NOT dismissible and deliberately not styled as a toast: the
/// condition it reports (no backend) persists, and a patient must never be
/// one dismissed snackbar away from mistaking sample vitals for their own.
class _DemoDataBanner extends StatelessWidget {
  const _DemoDataBanner();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DemoMode.isServingDemoData,
      builder: (context, serving, _) {
        if (!serving) return const SizedBox.shrink();
        return Material(
          color: context.hc.warningLight,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: context.hc.black),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Showing sample data — we can’t reach Housepital right '
                      'now, so this is not your live record.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.hc.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
