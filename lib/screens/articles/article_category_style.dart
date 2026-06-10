import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../config/theme.dart';

/// Visual identity (accent color + icon) for a care-guide category.
///
/// Single source of truth used by both the article list and detail screens so
/// a "Pulmo" guide always carries the same hue and glyph. Accents come only
/// from the status-token families (`context.hc.*`) and the brand `service*`
/// constants — never raw hex — so every tint reads correctly in dark mode.
class ArticleCategoryStyle {
  final Color accent;
  final IconData icon;

  const ArticleCategoryStyle._(this.accent, this.icon);

  /// Resolve the style for [category]. Unknown categories fall back to the
  /// brand orange + a book glyph so new backend categories degrade gracefully.
  static ArticleCategoryStyle of(BuildContext context, String category) {
    switch (category.trim().toLowerCase()) {
      case 'pulmo':
        return ArticleCategoryStyle._(context.hc.info, Icons.air);
      case 'cardio':
        return ArticleCategoryStyle._(context.hc.error, Icons.favorite);
      case 'neuro':
        return ArticleCategoryStyle._(context.hc.warning, Icons.psychology);
      case 'ortho':
        return const ArticleCategoryStyle._(
            HousepitalColors.servicePhysio, Icons.accessibility_new);
      case 'elderly care':
        return const ArticleCategoryStyle._(
            HousepitalColors.serviceCaretaker, Icons.elderly);
      case 'mother and baby care':
        return const ArticleCategoryStyle._(
            HousepitalColors.serviceJapaNanny, Icons.child_care);
      case 'post-hospitalisation care':
        return ArticleCategoryStyle._(context.hc.success, Icons.healing);
      case 'nutrition':
        return ArticleCategoryStyle._(context.hc.success, Icons.restaurant);
      case 'daily care':
        return ArticleCategoryStyle._(
            context.hc.orange, Icons.volunteer_activism);
      default:
        return ArticleCategoryStyle._(context.hc.orange, Icons.menu_book);
    }
  }
}
