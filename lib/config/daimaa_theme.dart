import 'package:flutter/material.dart';

/// Dai Maa sub-brand palette & constants.
///
/// Dai Maa is the mother-and-baby care sub-brand of Housepital Pvt Ltd.
/// Visual identity is intentionally distinct from the main orange Housepital
/// world so users feel they have entered a softer, family-care space.
///
/// Brand standards (locked):
///   • Plum     #5C3C5C
///   • Lavender #B48EAD
///   • Pink     #E3AFBE
///   • Cream    #F5F0EB  (page background)
///   • Tagline  : "Maa Jaisi Care"
///   • Lockup   : "DAI MAA | A Housepital Company"
///   • Phone    : +91-90502 00183
class DaiMaaColors {
  static const Color plum = Color(0xFF5C3C5C);
  static const Color lavender = Color(0xFFB48EAD);
  static const Color pink = Color(0xFFE3AFBE);
  static const Color cream = Color(0xFFF5F0EB);

  static const String phone = '9050200183'; // tel: format (no spaces)
  static const String phoneDisplay = '+91-90502 00183';
  static const String tagline = 'Maa Jaisi Care';
  static const String lockup = 'DAI MAA | A Housepital Company';

  /// External URL for the standalone Dai Maa app — used by the cross-promo
  /// banner on Home to link OUT to the separate Dai Maa product.
  static const String exploreUrl = 'https://daimaa.com';
}

/// Dark-mode counterparts for the Dai Maa palette.
///
/// Cream #F5F0EB is far too bright on a dark scaffold; we use a plum-tinted
/// dark surface instead so the sub-brand still feels distinct from the
/// orange Housepital world without losing the warm, feminine tone.
///
/// Contrast checks (vs [surface] #2A1F2A unless noted):
///   • textPrimary (#F2EAF0) → ~14.5:1 — AAA
///   • lavenderLight (#D4B5D0) → 8.6:1 — AAA, used for accents & icons
///   • pinkLight (#F0C8D5) → ~11:1, used for the age-range chip text
///   • plumLight (#A77BA8) → 4.7:1, AA for primary callouts
class DaiMaaColorsDark {
  // Plum-tinted dark surface — keeps a hint of the sub-brand hue.
  static const Color surface = Color(0xFF2A1F2A);
  // One step elevated for cards within Dai Maa screens.
  static const Color surfaceElevated = Color(0xFF362636);

  // Brand-tinted text & accent variants, lightened for AA on dark.
  static const Color textPrimary = Color(0xFFF2EAF0);
  static const Color plumLight = Color(0xFFA77BA8);
  static const Color lavenderLight = Color(0xFFD4B5D0);
  static const Color pinkLight = Color(0xFFF0C8D5);
}

/// Returns the appropriate Dai Maa scaffold colour for the current theme.
Color daiMaaScaffold(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? DaiMaaColorsDark.surface
        : DaiMaaColors.cream;

/// Returns the card surface colour for use inside Dai Maa screens.
Color daiMaaCardSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? DaiMaaColorsDark.surfaceElevated
        : Colors.white;

/// Text colour for headings/labels that sit on a Dai Maa surface (cream in
/// light, plum-tinted dark in dark). In dark mode plum is too low-contrast,
/// so we use a lightened variant.
Color daiMaaPrimaryText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? DaiMaaColorsDark.textPrimary
        : DaiMaaColors.plum;

/// Accent text/icon colour for the secondary brand callouts (used where
/// pure plum is too low-contrast on dark).
Color daiMaaAccent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? DaiMaaColorsDark.lavenderLight
        : DaiMaaColors.plum;

/// Gradient brand header used at the top of any Dai Maa screen or form.
///
/// Shows the lockup, large title, optional subtitle, and the tagline.
class DaiMaaBrandHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry margin;

  const DaiMaaBrandHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DaiMaaColors.plum, DaiMaaColors.lavender],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: DaiMaaColors.plum.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            DaiMaaColors.lockup,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            DaiMaaColors.tagline,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small "DAI MAA" badge — used as a corner accent on service cards in the
/// main catalog to signal that a service is part of the sub-brand.
class DaiMaaBadge extends StatelessWidget {
  const DaiMaaBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: DaiMaaColors.plum,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'DAI MAA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
