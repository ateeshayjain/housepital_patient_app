import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../utils/app_localizations.dart';
import '../widgets/assistant_fab.dart';
import '../widgets/glass.dart';
import 'home/home_screen.dart';
import 'my_care/my_care_screen.dart';
import 'services/service_catalog_screen.dart';
import 'billing/billing_screen.dart';
import 'settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Global key to allow switching tabs from anywhere.
  static final GlobalKey<MainShellState> shellKey = GlobalKey<MainShellState>();

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
      // The sample-data banner is NOT here. It lives above the Navigator in
      // main.dart's MaterialApp.builder, because inside the shell it covered
      // only the five tabs — missing every pushed clinical screen, including
      // /medication-schedule and /vitals — and it double-counted the top
      // safe-area inset, giving every screen a phantom notch.
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: const AssistantFab(),
      // Owner decision (field round 8): back to a FLOATING LIQUID-GLASS PILL,
      // matching the reference app the owner uses daily. This reverses field
      // round 5 ("the detached pill covered content and read as hovering
      // clutter") — the objection is addressed by `extendBody: true` plus the
      // Scaffold slot trick below, so content glides under the pill instead of
      // being hidden by it.
      //
      // The Padding lives INSIDE the bottomNavigationBar slot on purpose: the
      // Scaffold then reports the slot's FULL height (pill + margins) as the
      // body's bottom MediaQuery inset, so every screen that pads its
      // scrollable with `MediaQuery.padding.bottom + N` clears the pill for
      // free. Floating it in a Stack instead would hide content under it.
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          // Float above the home indicator; min 8 on devices without one.
          math.max(MediaQuery.of(context).padding.bottom, 8.0),
        ),
        // The pill needs a VISIBLE material. GlassSurface paints a white fill
        // with a white edge in light mode (glass.dart) — over the app's near-
        // white pages that renders as nothing at all, which is exactly what
        // the owner saw ("white on white is a bit off"). So the pill carries
        // its own warm tint, an orange hairline, and a soft lift; the glass
        // blur underneath still does its job over scrolling content.
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: context.hc.orange.withValues(alpha: 0.30),
              width: 1,
            ),
            boxShadow: [
              // Warm, low-alpha shadow rather than neutral black: it reads as
              // lift on white and stays invisible on true black.
              BoxShadow(
                color: context.hc.orange.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(32),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                // Measured on the full-strength tint (worst case): selected
                // label #9A5C00 = 4.90:1, unselected grey = 4.86:1, and in dark
                // brand orange on #3D2A12 = 5.85:1. All clear AA.
                color: context.hc.orangeLight.withValues(alpha: 0.55),
              ),
              child: MediaQuery.removePadding(
                // The outer Padding already clears the safe area — without this
                // the bar would add the home-indicator inset a second time.
                context: context,
                removeBottom: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: (index) => setState(() => _currentIndex = index),
                    // Transparent + flat: the GlassSurface provides the material.
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    type: BottomNavigationBarType.fixed,
                    // Selected label uses orangeStrong (5.38:1 on light), not
                    // orangeText (3.99:1) — a 12px label needs the AA floor. The
                    // white-on-orange owner rule governs orange FILLS; this pill
                    // is glass, so it does not apply here.
                    selectedItemColor: context.hc.orangeStrong,
                    unselectedItemColor: context.hc.grey,
                    selectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
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
        ),
      ),
    );
  }
}
