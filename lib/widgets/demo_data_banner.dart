import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../config/app_colors.dart';
import '../data/demo_mode.dart';
import '../utils/app_localizations.dart';
import 'glass.dart';

/// Floating sample-data notice, shown over EVERY route.
///
/// Installed from `MaterialApp.builder`, above the Navigator.
///
/// TWO EARLIER SHAPES, BOTH WRONG — don't go back to either:
///  1. Inside `MainShell`: covered only the five root tabs, so it was
///     structurally absent from every pushed clinical screen, including
///     `/medication-schedule` and `/vitals` — the screens where mistaking
///     sample data for a real record actually does harm.
///  2. A full-width strip in a Column above the app: it consumed the status
///     bar, pushed every glass app bar down, and screens still added their own
///     `padding.top + kToolbarHeight` on top — roughly a quarter of the first
///     screen lost to dead space (owner: "why is there so much space wasted
///     here").
///
/// So it is an OVERLAY, not a layout participant. It floats in a Stack over
/// the app, displaces nothing, and no screen needs any inset maths. Adding or
/// removing it cannot change any other screen's layout — which is the property
/// that made both previous versions regress.
class DemoDataBannerHost extends StatelessWidget {
  const DemoDataBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DemoMode.isServingDemoData,
      builder: (context, serving, _) {
        if (!serving) return child;
        return Stack(
          children: [
            child,
            // Bottom of the app-bar band, centred: clear of the status bar and
            // of the app bar's own controls, without pushing anything.
            // IgnorePointer, and it is not cosmetic. The pill spans the full
            // width minus 12pt of inset, sitting exactly where glass app bars
            // put their trailing actions — search, cart, and on My Care the
            // calendar. Measured: the overlay's painted box intersects those
            // buttons, and RenderParagraph.hitTestSelf returns true, so the
            // text itself swallowed the tap. Since this banner is up in every
            // shipped build (the API host does not resolve), those actions
            // were dead for every user, with no visual cue why.
            //
            // The pill is a NOTICE. It has nothing to tap, so it must not be
            // in the hit-test path at all.
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 4,
              left: 12,
              right: 12,
              child: const IgnorePointer(
                child: Center(child: _DemoDataPill()),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The notice itself: a compact glass pill. Persistent and non-dismissible —
/// the condition it reports (no backend) persists, and a patient must never be
/// one dismissed snackbar away from mistaking sample vitals for their own.
class _DemoDataPill extends StatefulWidget {
  const _DemoDataPill();

  @override
  State<_DemoDataPill> createState() => _DemoDataPillState();
}

class _DemoDataPillState extends State<_DemoDataPill> {
  @override
  void initState() {
    super.initState();
    // A silent warning is no warning to a VoiceOver user, who by then has
    // already heard the fake vitals read out. `liveRegion` only re-announces
    // on change, so announce once on appearance too.
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
    return Semantics(
      liveRegion: true,
      // The short pill label is a summary; the full sentence is what a screen
      // reader should say.
      label: l?.t('demo_banner_message'),
      child: ExcludeSemantics(
        child: GlassSurface(
          borderRadius: BorderRadius.circular(999),
          // Higher fill than chrome glass: this is a warning over arbitrary
          // content, so legibility beats translucency.
          opacity: 0.92,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: context.hc.warningLight.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: context.hc.warning.withValues(alpha: 0.35), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 15, color: context.hc.black),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l?.t('demo_banner_short') ??
                        'Sample data — not your live record',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      // #212121 on #FFF3E0 = 14.68:1 light; #F2F2F2 on
                      // #3A2D14 = 11.98:1 dark. Both measured.
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
