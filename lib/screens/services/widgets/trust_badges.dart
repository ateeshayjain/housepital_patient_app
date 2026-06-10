// audit batch 4 (Agent K): extracted from service_catalog_screen.dart
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';

/// A single trust badge shown inside a [TrustBadgeBar].
class TrustBadge {
  final IconData icon;
  final String text;
  const TrustBadge({required this.icon, required this.text});
}

/// Quiet reassurance line showing trust badges (verified, NABL accredited,
/// etc.) across the top of each catalog tab.
///
/// Deliberately UNDERSTATED: the previous full green-filled band read as a
/// status alert and competed with content (HIG: deference). Green stays only
/// on the small check icons; copy is secondary grey — no fill, no border.
class TrustBadgeBar extends StatelessWidget {
  final List<TrustBadge> badges;
  const TrustBadgeBar({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: badges.expand((badge) {
          final index = badges.indexOf(badge);
          return [
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('·',
                    style: TextStyle(
                        fontSize: 12, color: context.hc.greyLight)),
              ),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badge.icon, size: 14, color: context.hc.success),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      badge.text,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.hc.greyLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ];
        }).toList(),
      ),
    );
  }
}
