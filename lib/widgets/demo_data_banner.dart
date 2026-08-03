import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../config/app_colors.dart';
import '../data/demo_mode.dart';
import '../utils/app_localizations.dart';

/// Wraps the whole app so the sample-data notice appears on EVERY route.
///
/// Installed from `MaterialApp.builder`, above the Navigator. The first
/// version lived inside `MainShell`, which meant it covered only the five root
/// tabs and was structurally absent from every pushed clinical screen —
/// including `/medication-schedule` and `/vitals`, the exact screens where
/// mistaking sample data for a real record does harm.
///
/// It also has to own the top inset. The shell version sat above the body of a
/// Scaffold with no `appBar:`, so screens kept their full
/// `MediaQuery.padding.top` while already being pushed down by the banner —
/// a phantom notch on every screen, applied twice on screens that add their
/// own. Here the banner consumes the status-bar inset itself and hands the
/// child a MediaQuery with the top padding removed, so the app below is
/// laid out exactly as it would be with no banner.
class DemoDataBannerHost extends StatelessWidget {
  const DemoDataBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DemoMode.isServingDemoData,
      builder: (context, serving, _) {
        if (!serving) return child;
        return Column(
          children: [
            const _DemoDataBanner(),
            // The banner has eaten the status-bar inset; without this the
            // child would reserve it a second time.
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The notice itself: persistent, non-dismissible, and announced.
///
/// Not dismissible on purpose — the condition it reports (no backend) persists,
/// and a patient must never be one dismissed snackbar away from mistaking
/// sample vitals for their own.
class _DemoDataBanner extends StatefulWidget {
  const _DemoDataBanner();

  @override
  State<_DemoDataBanner> createState() => _DemoDataBannerState();
}

class _DemoDataBannerState extends State<_DemoDataBanner> {
  @override
  void initState() {
    super.initState();
    // A silent warning is no warning to a VoiceOver user, who by then has
    // already heard the fake vitals read out. `liveRegion` alone only
    // re-announces on change, so announce once on appearance too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      if (l == null) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        l.t('demo_banner_message'),
        Directionality.of(context),
        assertiveness: Assertiveness.assertive,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Measured both appearances: #212121 on #FFF3E0 = 14.68:1 (light),
    // #F2F2F2 on #3A2D14 = 11.98:1 (dark).
    return Material(
      color: context.hc.warningLight,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: context.hc.black),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l?.t('demo_banner_message') ??
                        'Showing sample data — this is not your live record.',
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
      ),
    );
  }
}
