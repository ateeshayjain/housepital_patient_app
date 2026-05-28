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
}

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
